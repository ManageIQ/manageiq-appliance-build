module Build
  class Target
    ImagefactoryMetadata = Struct.new(:imagefactory_type, :ova_format, :file_extension, :compression_type)

    TYPES = {
      'vsphere'   => ImagefactoryMetadata.new('vsphere', 'vsphere', 'ova', nil),
      'ovirt'     => ImagefactoryMetadata.new('rhevm', 'rhevm', 'ova', nil),
      'openstack' => ImagefactoryMetadata.new('openstack-kvm', nil, 'qc2', nil),
      'hyperv'    => ImagefactoryMetadata.new('hyperv', nil, 'vhd', 'zip'),
      'azure'     => ImagefactoryMetadata.new('hyperv', nil, 'vhd', 'zip'),
      'vagrant'   => ImagefactoryMetadata.new('vsphere', 'vagrant-virtualbox', 'box', nil),
      'libvirt'   => ImagefactoryMetadata.new('openstack-kvm', nil, 'qc2', nil),
      'gce'       => ImagefactoryMetadata.new('gce', nil, 'tar.gz', nil),
      'ec2'       => ImagefactoryMetadata.new('ec2', nil, 'vhd', 'zip'),
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

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
