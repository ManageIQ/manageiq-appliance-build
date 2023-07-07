require 'erb'
require 'fileutils'
require 'logger'
require 'pathname'
require 'yaml'

require_relative 'productization'
require_relative 'kickstart_generator'
require_relative 'cli'
require_relative 'uploader'
require_relative 'target'
require_relative 'target_disk_converter'

$log = Logger.new(STDOUT)

cli_options = Build::Cli.parse.options

puddle    = nil
directory = cli_options[:copy_dir]

case cli_options[:type]
when "nightly", "release"
  build_label = cli_options[:reference]
when nil
  build_label = "test"
else
  puddle = cli_options[:type]
  build_label = "#{cli_options[:type]}-#{cli_options[:reference]}"
end

BUILD_BASE          = ENV["GITHUB_ACTIONS"] ? Pathname.new("/build/gha/#{ENV['GITHUB_RUN_ID']}") : Pathname.new("/build")
GPG_DIR             = Pathname.new("/root/.gnupg")
SCRIPT_DIR          = Pathname.new(__dir__)
BIN_DIR             = SCRIPT_DIR.join("../bin")
CFG_DIR             = SCRIPT_DIR.join("../config")
REFS_DIR            = BUILD_BASE.join("references")
IMGFAC_DIR          = BUILD_BASE.join("imagefactory")
IMGFAC_CONF         = CFG_DIR.join("imagefactory.conf")
STORAGE_DIR         = BUILD_BASE.join("storage")
ISOS_DIR            = Pathname.new("/build/isos") # NOTE: We are not using run-specific BUILD_BASE in order to share the source iso across builds
IMAGES_DIR          = BUILD_BASE.join("images")
ISO_FILE            = ISOS_DIR.glob("CentOS-Stream-8-x86_64-*-dvd1.iso").sort.last.expand_path

FileUtils.mkdir_p(BIN_DIR)
FileUtils.mkdir_p(BUILD_BASE)
FileUtils.mkdir_p(CFG_DIR)
FileUtils.mkdir_p(IMAGES_DIR)
FileUtils.mkdir_p(IMGFAC_DIR)
FileUtils.mkdir_p(ISOS_DIR)
FileUtils.mkdir_p(REFS_DIR)
FileUtils.mkdir_p(STORAGE_DIR)

# Set Storage directory in imagefactory config
imagefactory_config = CFG_DIR.join("imagefactory.conf")
require 'json'
json = JSON.load(imagefactory_config.read)
json["image_manager_args"]["storage_path"] = STORAGE_DIR
File.write(imagefactory_config, json.to_json)

if !cli_options[:local] && cli_options[:build_url]
  build_repo = cli_options[:build_url]
  cfg_base = REFS_DIR.join(ENV["RUNNER_NAME"].to_s, cli_options[:build_ref])
  FileUtils.rm_rf(cfg_base)
  FileUtils.mkdir_p(cfg_base)
  Dir.chdir(cfg_base) do
    $log.info("Cloning Repo #{build_repo} to #{cfg_base} ...")
    `git clone #{build_repo} .`
    `git checkout #{cli_options[:build_ref]}`             # Checkout existing tag or branch
  end

  unless File.exist?(cfg_base)
    $log.error("Could not checkout repo #{build_repo} for reference #{cli_options[:build_ref]}")
    exit 1
  end
else
  cfg_base = BUILD_BASE
end

$log.info "Using Configuration base directory: #{cfg_base}"

base_file   = CFG_DIR.join("base.json")
target_file = CFG_DIR.join("target.json")
ova_file    = CFG_DIR.join("ova.json")

def verify_run(output)
  if output =~ /UUID: (.*)/
    Regexp.last_match[1]
  else
    $log.error("Could not find UUID. Skipping...")
    nil
  end
end

year_month_day    = Time.now.strftime("%Y%m%d")
hour_minute       = Time.now.strftime("%H%M")
directory_name    = "#{year_month_day}_#{hour_minute}"
timestamp         = "#{year_month_day}#{hour_minute}"

targets = cli_options[:only].collect { |only| Build::Target.new(only) }

ks_gen = Build::KickstartGenerator.new(cfg_base, cli_options[:type], cli_options[:only], cli_options[:product_name], puddle)
ks_gen.run

fileshare_dir         = BUILD_BASE.join("fileshare")
stream_directory      = fileshare_dir.join(directory)
destination_directory = stream_directory.join(build_label == "test" ? "test" : directory_name)

$log.info "Creating Fileshare Directory: #{destination_directory}"
FileUtils.mkdir_p(destination_directory)

Dir.chdir(IMGFAC_DIR) do
  targets.sort.reverse.each do |target|
    imgfac_target = target.imagefactory_type
    ova_format    = target.ova_format
    compression   = target.compression_type
    image_size    = target.image_size # Used by base.tdl.erb
    $log.info "Building for #{target}:"

    tdl_file = CFG_DIR.join("generated", "base_#{target}.tdl")
    File.write(tdl_file, ERB.new(CFG_DIR.join("base.tdl.erb").read, 0, '-').result(binding))

    $log.info "Using inputs: puddle: #{puddle}, build_label: #{build_label}"
    $log.info "              tdl_file: #{tdl_file}, ova_file: #{ova_file}."

    input_file  = ks_gen.gen_file_path("base-#{target}.ks")
    output_file = ks_gen.gen_file_path("base-#{target}-#{build_label}-#{timestamp}.ks")

    FileUtils.cp(input_file, output_file)

    params = "--parameters #{base_file} --file-parameter install_script #{output_file}"
    $log.info "Running #{target} base_image using parameters: #{params}"

    output = `./imagefactory --config #{IMGFAC_CONF} base_image #{params} #{tdl_file}`
    uuid   = verify_run(output)
    next if uuid.nil?

    $log.info "#{target} base_image complete, uuid: #{uuid}"
    temp_file_uuid = [uuid]

    if target.name == "azure"
      $log.info "Resizing and converting Azure image, #{uuid}"
      Build::TargetDiskConverter.new("#{STORAGE_DIR}/#{uuid}.body").fix_azure_disk
    else
      params = "--parameters #{target_file}"
      $log.info "Running #{target} target_image #{imgfac_target} using parameters: #{params}"

      output = `./imagefactory --config #{IMGFAC_CONF} target_image #{params} --id #{uuid} #{imgfac_target}`
      uuid   = verify_run(output)
      next if uuid.nil?

      $log.info "#{target} target_image #{imgfac_target} complete, uuid: #{uuid}"
      temp_file_uuid << uuid
    end

    if ova_format
      params = "--parameters #{ova_file} --parameter #{imgfac_target}_ova_format #{ova_format}"
      $log.info "Running #{target} target_image ova using parameters: #{params}"

      output = `./imagefactory --config #{IMGFAC_CONF} target_image #{params} --id #{uuid} ova`
      uuid   = verify_run(output)
      next if uuid.nil?

      $log.info "#{target} target_image ova complete, uuid: #{uuid}"
      temp_file_uuid << uuid
    end
    $log.info "Built #{target} with final UUID: #{uuid}"

    FileUtils.mkdir_p(destination_directory)
    file_name = "#{cli_options[:product_name]}-#{target}-#{build_label}-#{timestamp}.#{target.file_extension}"
    destination = destination_directory.join(file_name)

    Dir.chdir(STORAGE_DIR) do
      FileUtils.mv("#{uuid}.body", file_name)

      case compression
      when 'gzip'
        destination = destination.sub_ext(destination.extname + '.gz')
        $log.info "Compressing #{file_name} to #{destination}"
        $log.info `gzip -c #{file_name} > #{destination}`
        FileUtils.rm_f(file_name)
      when 'qemu-qcow2'
        $log.info "Compressing and converting #{file_name} to #{destination}"
        $log.info `qemu-img convert -f qcow2 -O qcow2 -o compat=0.10 -c #{file_name} #{destination}`
        FileUtils.rm_f(file_name)
      when 'zip'
        destination = destination.sub_ext('.zip')
        $log.info "Compressing #{file_name} to #{destination}"
        $log.info `zip -m -j #{destination} #{file_name}`
      else
        $log.info "Moving #{file_name} to #{destination}"
        FileUtils.mv(file_name, destination)
      end
    end

    # The final image is moved out of STORAGE_DIR at this point, delete all other files created during build
    temp_file_uuid.each { |file_uuid| FileUtils.rm_f(Dir.glob("#{STORAGE_DIR}/#{file_uuid}.*"), :verbose => true) }
  end

  exit 1 if destination_directory.empty?

  passphrase_file = GPG_DIR.join("pass")
  public_key_file = GPG_DIR.join("manageiq_public.key")
  if File.exist?(passphrase_file) && File.exist?(public_key_file)
    $log.info "Generating Image Checksums in #{destination_directory} ..."
    Dir.chdir(destination_directory) do
      $log.info `/usr/bin/sha256sum * > SHA256SUM`
      $log.info `/usr/bin/gpg --batch --no-tty --passphrase-file #{passphrase_file} --pinentry-mode loopback -b SHA256SUM`
      FileUtils.cp(public_key_file, destination_directory)
    end
  end
end

# Only update the latest symlink for a nightly/release
if cli_options[:type] == "nightly" || cli_options[:type] == "release"
  symlink_name = cli_options[:type] == "nightly" ? "latest" : "stable"
  link = stream_directory.join(symlink_name)
  if File.exist?(link)
    raise "#{link} is not a symlink!" unless File.symlink?(link)
    result = FileUtils.rm(link, :verbose => true)
    $log.info("Deleted symlink: #{result}")
  end

  result = FileUtils.ln_s(directory_name, link, :verbose => true)
  $log.info("Created symlink: #{result}")

  # Also create relese ref symlink (e.g. gaprindashvili-1)
  if cli_options[:type] == "release"
    result = FileUtils.ln_s(directory_name, stream_directory.join(cli_options[:reference]), :verbose => true)
    $log.info("Created release ref link: #{result}")
  end

  Build::Uploader.upload(destination_directory, cli_options[:type], cli_options[:delete]) if cli_options[:upload]
end
