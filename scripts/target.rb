module Build
  class Target
    ImagefactoryMetadata = Struct.new(:imagefactory_type, :ova_format, :file_extension, :compression_type, :image_size)

    TYPES = {
      'vsphere'   => ImagefactoryMetadata.new('vsphere', 'vsphere', 'ova', nil, '66'),
      'ovirt'     => ImagefactoryMetadata.new('rhevm', nil, 'qc2', 'qemu-qcow2', '66'),
      'openstack' => ImagefactoryMetadata.new('openstack-kvm', nil, 'qc2', nil, '66'),
      'hyperv'    => ImagefactoryMetadata.new('hyperv', nil, 'vhd', 'zip', '66'),
      'azure'     => ImagefactoryMetadata.new(nil, nil, 'vhd', 'zip', '61'),
      'vagrant'   => ImagefactoryMetadata.new('vsphere', 'vagrant-virtualbox', 'box', nil, '66'),
      'libvirt'   => ImagefactoryMetadata.new('openstack-kvm', nil, 'qc2', nil, '66'),
      'gce'       => ImagefactoryMetadata.new('gce', nil, 'tar.gz', nil, '66'),
      'ec2'       => ImagefactoryMetadata.new('ec2', nil, 'vhd', 'zip', '66'),
    }

    attr_reader :name

    def self.supported_types
      TYPES.keys
    end

    def self.default_types
      supported_types
    end

    def initialize(name)
      @name = name = name.to_s
      raise ArgumentError, "Unsupported name: #{name}" unless TYPES.key?(name)
    end

    def imagefactory_type
      TYPES.fetch(name).imagefactory_type
    end

    def ova_format
      TYPES.fetch(name).ova_format
    end

    def file_extension
      TYPES.fetch(name).file_extension
    end

    def compression_type
      TYPES.fetch(name).compression_type
    end

    def image_size
      TYPES.fetch(name).image_size
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
