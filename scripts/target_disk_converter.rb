require 'awesome_spawn'
require 'fileutils'

module Build
  class TargetDiskConverter
    attr_reader :disk

    def initialize(disk)
      @disk = disk
    end

    def fix_azure_disk
      disk_type = AwesomeSpawn.run!("qemu-img info --output json #{disk}").output.match(/format\": "(.*)"/)[1]
      convert_to_raw if disk_type == "vpc"

      align_disk

      # We can't use imagefactory target_image due to "fixed" and "force_size" options needed for conversion
      convert_to_fixed_vpc

      puts "Completed resizing and converting Azure image"
    end

    private

    def convert_to_raw
      puts "Converting #{disk} to raw"
      exit $?.exitstatus unless system("qemu-img convert -f vpc -O raw #{disk} #{disk}.tmp")
      FileUtils.mv("#{disk}.tmp", disk)
    end

    def convert_to_fixed_vpc
      puts "Converting to fixed vpc"
      exit $?.exitstatus unless system("qemu-img convert -f raw -O vpc -o subformat=fixed,force_size #{disk} #{disk}.tmp")
      FileUtils.mv("#{disk}.tmp", disk)
    end

    def align_disk
      mega = 1024 * 1024
      virtual_size = AwesomeSpawn.run!("qemu-img info --output json #{disk}").output.match(/virtual-size\": ([\d]+)/)[1].to_i
      new_size = ((virtual_size / mega) + 1) * mega
      puts "Resizing #{disk} from #{virtual_size} to #{new_size}"
      exit $?.exitstatus unless system("qemu-img resize -f raw #{disk} #{new_size}")
    end
  end
end
