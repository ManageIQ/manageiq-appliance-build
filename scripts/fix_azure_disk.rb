#!/usr/bin/env ruby

require 'awesome_spawn'
require 'fileutils'
require 'logger'

log = Logger.new(STDOUT)

def execute(cmd)
  exit $?.exitstatus unless system(cmd)
end

disk      = ARGV[0]
tmp_disk  = disk + ".tmp"

image_type = AwesomeSpawn.run!("qemu-img info --output json #{disk}").output.match(/format\": "(.*)"/)[1]
if image_type == "vpc"
  log.info("Converting #{disk} to raw")
  execute("qemu-img convert -f vpc -O raw #{disk} #{tmp_disk}")
  FileUtils.mv(tmp_disk, disk)
end

virtual_size = AwesomeSpawn.run!("qemu-img info --output json #{disk}").output.match(/virtual-size\": ([\d]+)/)[1].to_i
mega = 1024 * 1024
new_size = ((virtual_size / mega) + 1) * mega
log.info("Resizing #{disk} from #{virtual_size} to #{new_size}")
execute("qemu-img resize -f raw #{disk} #{new_size}")

# We can't use imagefactory target_image due to "fixed" and "force_size" options needed for conversion
log.info("Converting to fixed vpc")
execute("qemu-img convert -f raw -O vpc -o subformat=fixed,force_size #{disk} #{tmp_disk}")

FileUtils.mv(tmp_disk, disk)
log.info("Completed resizing and converting Azure image")
