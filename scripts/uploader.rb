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
      clients.each(&:login)

      appliances = Dir.glob("#{directory}/manageiq*")
      appliances.each do |appliance|
        # Skip badly named appliances, missing date: manageiq-openstack-master-.qc2
        unless appliance.match?(/.+-[0-9]{12}/)
          puts "Skipping #{appliance}"
          next
        end

        destination_name = uploaded_filename(appliance)
        source_name      = File.expand_path(appliance)
        upload_options   = {:source_hash => Digest::MD5.file(source_name).hexdigest}

        if nightly?
          image_date = destination_name.split("-")[-1][0, 8]
          delete_at  = (DateTime.parse(image_date) + NIGHTLY_BUILD_RETENTION_TIME)
          upload_options[:delete_at] = delete_at
        end

        clients.each { |c| c.upload(source_name, destination_name, upload_options) }

        next unless master?(appliance)

        if nightly?
          devel = devel_filename(destination_name)

          clients.each { |c| c.copy(destination_name, devel) }
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
        upload_headers["X-Delete-At"] = options[:delete_at].to_i.to_s if options[:delete_at]

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

    class DigitalOcean
      attr_reader :access_key, :secret_key, :endpoint, :bucket

      def initialize(config)
        @bucket     = "releases-manageiq-org"
        @access_key = config[:access_key]
        @secret_key = config[:secret_key]
        @endpoint   = config[:endpoint]
      end

      def login
      end

      def upload(source, destination, options)
        appliance = File.basename(source)
        puts "Uploading #{appliance} to DigitalOcean as #{destination}..."

        put_options = {
          :acl    => "public-read",
          :bucket => bucket,
          :key    => destination,
        }.tap { |h| h[:metadata]["delete_at"] = options[:delete_at] if options[:delete_at] }

        response = File.open(source, 'rb') do |content|
          client.put_object(put_options.merge(:body => content))
        end

        status = response.etag.tr("\\\"", "") == options[:source_hash] ? "complete" : "checksum-mismatch"
        puts "Uploading #{appliance} to DigitalOcean as #{destination}...#{status}"
      end

      def copy(source, destination)
        appliance = File.basename(source)
        puts "Copying   #{appliance} to #{destination} on DigitalOcean..."

        copy_options = {
          :acl         => "public-read",
          :bucket      => bucket,
          :copy_source => File.join(bucket, source),
          :key         => destination,
        }

        client.copy_object(copy_options)

        puts "Copying   #{appliance} to #{destination} on DigitalOcean...complete"
      end

      private

      def client
        @client ||= begin
          require 'aws-sdk-s3'
          Aws::S3::Client.new(:access_key_id => access_key, :secret_access_key => secret_key, :endpoint => endpoint, :region => 'us-east-1')
        end
      end
    end

    def rackspace_client
      @rackspace_client ||= Rackspace.new(config[:rackspace])
    end

    def digital_ocean_client
      @digital_ocean_client ||= DigitalOcean.new(config[:digital_ocean])
    end

    def clients
      @clients ||= [digital_ocean_client, rackspace_client]
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
      name = appliance_name.split("-")
      extension = ".#{appliance_name.split(".", 2).last}"
      (name[0..1] << "devel").join("-") + extension
    end

    def nightly_filename(appliance_name)
      name = appliance_name.split("-")
      name[-1] = "#{name[-1][0..7]}#{name[-1][12..-1]}"
      name.join("-")
    end

    def release_filename(appliance_name)
      name = appliance_name.split("-")
      ext = name[-1].sub(/\h*/, '')
      name[0..-2].join("-") << ext
    end
  end
end
