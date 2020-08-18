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
      new(directory, type).run
    end

    def initialize(directory, type)
      @directory = directory
      @type      = type
    end

    def run
      clients.each(&:login)

      appliances = Dir.glob("#{directory}/manageiq*")
      appliances.each do |appliance|
        # Skip badly named appliances, missing git sha: manageiq-openstack-master-201407142000-.qc2
        unless appliance.match?(/.+-[0-9]{12}-[0-9a-fA-F]+/)
          puts "Skipping #{appliance}"
          next
        end

        destination_name = uploaded_filename(appliance)
        source_name      = File.expand_path(appliance)
        upload_options   = {:source_hash => Digest::MD5.file(source_name).hexdigest}

        unless release?
          image_date = destination_name.split("-")[-2]
          delete_at  = (DateTime.parse(image_date) + NIGHTLY_BUILD_RETENTION_TIME)
          upload_options[:delete_at] = delete_at
        end

        clients.each { |c| c.upload(source_name, destination_name, upload_options) }
      end
    end

    private

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
        }.tap { |h| h[:metadata] = {"delete_at" => options[:delete_at].to_i.to_s} if options[:delete_at] }

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

    def digital_ocean_client
      @digital_ocean_client ||= DigitalOcean.new(config[:digital_ocean])
    end

    def clients
      @clients ||= [digital_ocean_client]
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
