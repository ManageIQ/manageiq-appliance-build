require 'logger'
require 'pathname'
require 'trollop'
require 'json'

require_relative 'config'


def find_imgfac_image(image)
  f = File.new(image)
  Dir.chdir(STORAGE_DIR) do
    Dir.glob('*.body') do |filename|
      return filename.split('.').first if File.new(filename).stat.ino == f.stat.ino
    end
  end
end


def upload_imgfac_image(uuid, target, reference, version)
  if target == 'vagrant'
    creds_file = CREDS_DIR.join('atlas.json')
    params = "atlas @ignored #{creds_file} --id #{uuid}"
    params += " --parameter atlas_box_name #{reference} --parameter atlas_box_version #{version}"
  elsif target == 'gce'
    creds_file = CREDS_DIR.join('gce.json')
    params = "gce @manageiq #{creds_file} --id #{uuid}"
    params += " --parameter gce_object_name manageiq-#{reference}-#{version}.tar.gz"
    params += " --parameter gce_image_name manageiq-#{reference}-#{version} --parameter gce_image_family centos-7"
  end

  if !File.exist?(creds_file)
    $log.info "credentials file #{creds_file} does not exist, skipping #{target} publish"
    return
  end

  Dir.chdir(IMGFAC_DIR) do
    # Show progress on STDOUT
    command = "./imagefactory provider_image #{params}"
    $log.info "running command: #{command}"
    if !system(command)
      $log.error "imagefactory exited with status #{$?.exitstatus}"
      exit 1
    end
  end
end


$log = Logger.new(STDOUT)

dir_desc  = "Directory builds were copied to"
type_desc = "Build type (stable or latest)"

options = Trollop.options(ARGV) do
  banner "Usage: vmpublish.rb [options]"
  opt :copy_dir,  dir_desc,   :type => :string,   :short => 'd', :default => "master"
  opt :type,      type_desc,  :type => :string,   :short => 't', :default => "stable"
end

copy_dir = FILESHARE_DIR.join(options[:copy_dir], options[:type])

Dir.foreach(copy_dir) do |filename|
  next if ['.', '..'].include? filename

  parts = filename.split('.').first.split('-')
  next unless parts.length >= 6        # only release builds, which are build from a tag (name-version)
  next unless parts[0] == 'manageiq'
  target = parts[1]
  next unless ['vagrant', 'gce'].include? target
  reference = parts[2]
  version = parts[3..parts.length-3].join('-')

  image = copy_dir.join(filename)
  uuid = find_imgfac_image(image)

  $log.info "processing image: #{image}"
  $log.info "target = #{target}, reference = #{reference}, version = #{version}"
  $log.info "imagefactory image = #{uuid}"

  upload_imgfac_image(uuid, target, reference, version)
end
