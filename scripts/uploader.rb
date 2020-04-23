require 'active_support/all'
require 'json'
require 'rest-client'
require 'yaml'

module Build
  class Uploader
    attr_reader :directory, :type

    NIGHTLY_BUILD_RETENTION_TIME = 8.weeks
    CONFIG_FILE = Pathname.new(__dir__).join("../config/upload.yml")

    def self.upload(directory, type)
      if File.exist?(CONFIG_FILE)
        new(directory, type).run
      else
        puts "#{CONFIG_FILE} doesn't exist, not uploading images"
      end
    end

    def initialize(directory, type)
      @directory = directory
      @type      = type
    end

    def run
      rackspace_client.login

      Dir.glob("#{directory}/*").each do |appliance|
        # Skip files without date
        unless appliance.match?(/.+-[0-9]{12}/)
          puts "Skipping #{appliance}"
          next
        end

        destination_name = uploaded_filename(appliance)
        source_name      = File.expand_path(appliance)
        upload_options   = {:source_hash => Digest::MD5.file(source_name).hexdigest}

        if nightly?
          image_date = destination_name.match(/.*([0-9]{8}).*/)[1]
          delete_at  = (DateTime.parse(image_date) + NIGHTLY_BUILD_RETENTION_TIME)
          upload_options[:expires] = delete_at
        end

        rackspace_client.upload(source_name, destination_name, upload_options)

        next unless master?(appliance)

        if nightly?
          devel = devel_filename(destination_name)

          rackspace_client.copy(destination_name, devel)
        end
      end
    end

    private

    class Rackspace
      attr_reader :username, :api_key, :region, :container

      def initialize(config)
        @container = "release"
        @username  = config[:username]
        @api_key   = config[:api_key]
        @region    = config[:region]
      end

      def login
        @login ||= begin
          login_response = RestClient.post(
            "https://identity.api.rackspacecloud.com/v2.0/tokens",
            {
              "auth" => {
                "RAX-KSKEY:apiKeyCredentials" => {
                  "username" => username,
                  "apiKey"   => api_key
                }
              }
            }.to_json,
            :content_type => :json
          )

          JSON.parse(login_response.body)
        end
      end

      def upload(source, destination, options)
        appliance = File.basename(source)
        puts "Uploading #{appliance} to Rackspace as #{destination}..."

        upload_headers = headers.merge("ETag" => options[:source_hash])
        upload_headers["X-Delete-At"] = options[:expires].to_i.to_s if options[:expires]

        destination_url = url(destination)

        RestClient.put(
          destination_url,
          File.read(source),
          upload_headers
        )

        puts "Uploading #{appliance} to Rackspace as #{destination}...complete: #{destination_url}"
      end

      def copy(source, destination)
        appliance = File.basename(source)
        puts "Copying   #{appliance} to #{destination} on Rackspace..."

        RestClient::Request.execute(
          :method  => :copy,
          :url     => url(source),
          :headers => token_headers.merge("Destination" => "/#{container}/#{destination}")
        )

        puts "Copying   #{appliance} to #{destination} on Rackspace...complete"
      end

      private

      def url(file = nil)
        parts = [public_url, container]
        parts << URI.encode(file) if file
        parts.join("/")
      end

      def public_url
        @public_url ||= login["access"]["serviceCatalog"].detect { |i| i["name"] == "cloudFiles" }["endpoints"].detect { |i| i["region"] == region.to_s.upcase }["publicURL"]
      end

      def headers
        @headers ||= token_headers.merge("X-Detect-Content-Type" => "True").freeze
      end

      def token_headers
        @token_headers ||= {"X-Auth-Token" => login["access"]["token"]["id"]}.freeze
      end
    end

    def rackspace_client
      @rackspace_client ||= Rackspace.new(config[:rackspace])
    end

    def master?(filename)
      filename.include?("-master-")
    end

    def nightly?
      type == "nightly"
    end

    def release?
      type == "release"
    end

    def config
      @config ||= YAML.load_file(CONFIG_FILE)
    end

    # prerelease: manageiq-ovirt-anand-1-rc1.ova
    # stable:     manageiq-ovirt-anand-1.ova

    # Nightly builds:
    # (YYYYMMDD): Build date or date of most recent commit
    # sha1:       git sha1 of the most recent commit for that appliance build
    # a nightly:        manageiq-${platform}-master-${YYYYMMDD}-${sha1}.${ext}
    #                   manageiq-ovirt-master-20140613-8d9d1b8.ova
    def uploaded_filename(appliance_name)
      filename = release? ? release_filename(appliance_name) : nightly_filename(appliance_name)
      File.basename(filename)
    end

    def devel_filename(appliance_name)
      name = appliance_name.match(/(.*-).*-[0-9]{8}(?:-\h*)?(.*)/)
      "#{name[1]}devel#{name[2]}"
    end

    def nightly_filename(appliance_name)
      name = appliance_name.match(/(.*)([0-9]{12})(.*)/)
      "#{name[1]}#{name[2][0, 8]}#{name[3]}"
    end

    def release_filename(appliance_name)
      name = appliance_name.match(/(.*)-[0-9]{12}(?:-\h*)?(.*)/)
      "#{name[1]}#{name[2]}"
    end
  end
end
