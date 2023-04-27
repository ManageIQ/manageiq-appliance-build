require 'active_support/all'
require 'json'
require 'rest-client'
require 'yaml'

module Build
  class Uploader
    attr_reader :directory, :type, :delete_after_upload

    NIGHTLY_BUILD_RETENTION_TIME = 8.weeks
    CONFIG_FILE = Pathname.new(__dir__).join("../config/upload.yml")

    def self.upload(directory, type, delete_after_upload)
      if File.exist?(CONFIG_FILE)
        new(directory, type, delete_after_upload).run
      else
        puts "#{CONFIG_FILE} doesn't exist, not uploading images"
      end
    end

    def initialize(directory, type, delete_after_upload)
      @directory           = directory
      @type                = type
      @delete_after_upload = delete_after_upload
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

        clients.each { |c| c.upload(source_name, destination_name, upload_options, delete_after_upload) }

        next unless master?(appliance)

        if nightly?
          devel = devel_filename(destination_name)

          clients.each { |c| c.copy(destination_name, devel) }
        end
      end
    end

    private

    class IBMCloud
      attr_reader :access_key, :secret_key, :endpoint, :bucket, :display_name, :region

      def initialize(config)
        @bucket       = "releases-manageiq-org"
        @display_name = "IBM Cloud"
        @access_key   = env["IBM_CLOUD_ACCESS_KEY"] || config[:access_key]
        @secret_key   = env["IBM_CLOUD_SECRET_KEY"] || config[:secret_key]
        @endpoint     = env["IBM_CLOUD_ENDPOINT"] || config[:endpoint]
        @region       = "us-east"
      end

      def login
      end

      def upload(source, destination, options, delete_after_upload)
        appliance = File.basename(source)
        puts "Uploading #{appliance} to #{display_name} as #{destination}..."

        put_options = {
          :acl    => "public-read",
          :bucket => bucket,
          :key    => destination,
        }.tap { |h| h[:metadata] = {"delete_at" => options[:delete_at].to_i.to_s} if options[:delete_at] }

        response = File.open(source, 'rb') do |content|
          client.put_object(put_options.merge(:body => content))
        end

        status = response.etag.tr("\\\"", "") == options[:source_hash] ? "complete" : "checksum-mismatch"
        puts "Uploading #{appliance} to #{display_name} as #{destination}...#{status}"

        FileUtils.rm_f(source) if delete_after_upload && status == "complete"
      end

      def copy(source, destination)
        appliance = File.basename(source)
        puts "Copying   #{appliance} to #{destination} on #{display_name}..."

        copy_options = {
          :acl         => "public-read",
          :bucket      => bucket,
          :copy_source => File.join(bucket, source),
          :key         => destination,
        }

        client.copy_object(copy_options)

        puts "Copying   #{appliance} to #{destination} on #{display_name}...complete"
      end

      private

      def client
        @client ||= begin
          require 'aws-sdk-s3'
          Aws::S3::Client.new(:access_key_id => access_key, :secret_access_key => secret_key, :endpoint => endpoint, :region => region)
        end
      end
    end

    def ibm_cloud_client
      @ibm_cloud_client ||= IBMCloud.new(config[:ibm_cloud])
    end

    def clients
      @clients ||= [ibm_cloud_client]
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
