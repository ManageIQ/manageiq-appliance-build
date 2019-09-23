require 'active_support/all'
require 'json'
require 'rest-client'
require 'yaml'

module Build
  class Uploader
    attr_reader :container, :directory, :type

    NIGHTLY_BUILD_RETENTION_TIME = 8.weeks

    def self.upload(directory, type)
      new(directory, type).run
    end

    def initialize(directory, type)
      @container = "release"
      @directory = directory
      @type      = type
    end

    def run
      login

      appliances = Dir.glob("#{directory}/manageiq*")
      appliances.each do |appliance|
        # Skip badly named appliances, missing git sha: manageiq-openstack-master-201407142000-.qc2
        unless appliance.match?(/.+-[0-9]{12}-[0-9a-fA-F]+/)
          puts "Skipping #{appliance}"
          next
        end

        destination_name = uploaded_filename(appliance)
        source_name = File.expand_path(appliance)

        puts "Uploading #{appliance} as #{destination_name}..."

        destination_url = url(destination_name)
        source_hash = Digest::MD5.file(source_name).hexdigest

        upload_headers = headers.merge("ETag" => source_hash)
        unless release?
          image_date = destination_name.split("-")[-2]
          delete_at  = (DateTime.parse(image_date) + NIGHTLY_BUILD_RETENTION_TIME)
          upload_headers["X-Delete-At"] = delete_at.to_i.to_s
        end

        RestClient.put(
          destination_url,
          File.read(source_name),
          upload_headers
        )

        puts "Uploading #{appliance} as #{destination_name}...complete: #{destination_url}"
      end
    end

    private

    def release?
      type == "release"
    end

    def config
      @config ||= YAML.load_file("#{__dir__}/../config/upload.yml")
    end

    def login
      @login ||= begin
        login_response = RestClient.post(
          "https://identity.api.rackspacecloud.com/v2.0/tokens",
          {
            "auth" => {
              "RAX-KSKEY:apiKeyCredentials" => {
                "username" => config[:rackspace_username],
                "apiKey"   => config[:rackspace_api_key]
              }
            }
          }.to_json,
          :content_type => :json
        )

        JSON.parse(login_response.body)
      end
    end

    def headers
      @headers ||= {
        "X-Auth-Token"          => login["access"]["token"]["id"],
        "X-Detect-Content-Type" => "True",
      }.freeze
    end

    def url(file = nil)
      parts = [public_url, container]
      parts << URI.encode(file) if file
      parts.join("/")
    end

    def public_url
      @public_url ||= login["access"]["serviceCatalog"].detect { |i| i["name"] == "cloudFiles" }["endpoints"].detect { |i| i["region"] == config[:rackspace_region].to_s.upcase }["publicURL"]
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

    def nightly_filename(appliance_name)
      name = appliance_name.split("-")
      name[-2] = name[-2][0, 8]
      name.join("-")
    end

    def release_filename(appliance_name)
      name = appliance_name.split("-")
      ext = name[-1].sub(/\h*/, '')
      name[0..-3].join("-") << ext
    end
  end
end
