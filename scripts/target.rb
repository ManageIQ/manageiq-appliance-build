module Build
  class Target
    TARGET_MAPPING = {
      'vsphere'   => 'vsphere',
      'ovirt'     => 'rhevm',
      'openstack' => 'openstack-kvm'
    }

    FILE_EXTENSION = {
      'vsphere'       => 'ova',
      'rhevm'         => 'ova',
      'openstack-kvm' => 'qc2'
    }

    attr_reader :name

    def self.supported_types
      TARGET_MAPPING.keys
    end

    def initialize(name)
      @name = name = name.to_s
      raise ArgumentError, "Unsupported name: #{name}" unless TARGET_MAPPING.key?(name)
    end

    def imagefactory_type
      TARGET_MAPPING.fetch(name)
    end

    def file_extension
      FILE_EXTENSION.fetch(imagefactory_type)
    end

    def <=>(other)
      name <=> other.name
    end
  end
end
