require 'fog'

module Build
  class Uploader
    attr_reader :directory

    def self.upload(directory)
      new(directory).run
    end

    def initialize(directory)
      @directory = directory
    end

    def service
      # Example config/upload.yml
      # ---
      # :provider: XYZ
      # :rackspace_username: MyUser
      # :rackspace_api_key: MyKey
      # :rackspace_region: :my_region
      @service ||= Fog::Storage.new(YAML.load_file("#{__dir__}/../config/upload.yml"))
    end

    def container
      @container ||= service.directories.get("release")
    end

    def run
      appliances = Dir.glob("#{directory}/manageiq*")
      appliances.each do |appliance|
        # Skip badly named appliances, missing git sha: manageiq-openstack-master-201407142000-.qc2
        next unless appliance.match(/.+-[0-9]{12}-[0-9a-fA-F]+/)
        key = uploaded_filename(appliance)
        puts "Uploading #{appliance} as #{key}..."
        upload_file = File.expand_path(appliance)
        file = container.files.create :key => key, :body => File.open(upload_file, "r")
        url = file.public_url if file
        puts "Uploading #{appliance} as #{key}...complete: #{url}"
      end
    end

    # prerelease: manageiq-ovirt-anand-1-rc1.ova
    # stable:     manageiq-ovirt-anand-1.ova

    # Nightly builds:
    # (YYYYMMDD): Build date or date of most recent commit
    # sha1:       git sha1 of the most recent commit for that appliance build
    # a nightly:        manageiq-${platform}-master-${YYYYMMDD}-${sha1}.${ext}
    #                   manageiq-ovirt-master-20140613-8d9d1b8.ova
    def uploaded_filename(appliance_name)
      filename =
        if appliance_name.include?("-master-")
          nightly_filename(appliance_name)
        else
          release_filename(appliance_name)
        end
      File.basename(filename)
    end

    def nightly_filename(appliance_name)
      name = appliance_name.split("-")
      name[-2] = name[-2][0, 8]
      name.join("-")
    end

    def release_filename(appliance_name)
      ext = File.extname(appliance_name)
      name = appliance_name.split("-")
      name[0..-3].join("-") << ext
    end
  end
end
