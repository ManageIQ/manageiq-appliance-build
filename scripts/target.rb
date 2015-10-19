module Build
  class Target
    ImagefactoryMetadata = Struct.new(:imagefactory_type, :file_extension)

    TYPES = {
      'vsphere'   => ImagefactoryMetadata.new('vsphere', 'ova'),
      'ovirt'     => ImagefactoryMetadata.new('rhevm', 'ova'),
      'openstack' => ImagefactoryMetadata.new('openstack-kvm', 'qc2')
      'vhd'       => ImagefactoryMetadata.new('vpc', 'vhd')
    }

    attr_reader :name

    def self.supported_types
      TYPES.keys
    end

    def initialize(name)
      @name = name = name.to_s
      raise ArgumentError, "Unsupported name: #{name}" unless TYPES.key?(name)
    end

    def imagefactory_type
      TYPES.fetch(name).imagefactory_type
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
