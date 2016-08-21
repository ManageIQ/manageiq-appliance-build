module Build
  class Target
    ImagefactoryMetadata = Struct.new(:imagefactory_type, :ova_format, :file_extension)

    TYPES = {
      'vsphere'   => ImagefactoryMetadata.new('vsphere', 'vsphere', 'ova'),
      'ovirt'     => ImagefactoryMetadata.new('rhevm', 'rhevm', 'ova'),
      'openstack' => ImagefactoryMetadata.new('openstack-kvm', nil, 'qc2'),
      'hyperv'    => ImagefactoryMetadata.new('hyperv', nil, 'vhd'),
      'azure'     => ImagefactoryMetadata.new('hyperv', nil, 'vhd'),
      'vagrant'   => ImagefactoryMetadata.new('vsphere', 'vagrant-virtualbox', 'box'),
      'libvirt'   => ImagefactoryMetadata.new('openstack-kvm', nil, 'qc2')
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

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
