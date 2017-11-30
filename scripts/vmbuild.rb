require 'pathname'
require 'fileutils'
require 'logger'
require 'pathname'
require 'yaml'

require_relative 'productization'
require_relative 'kickstart_generator'
require_relative 'git_checkout'
require_relative 'cli'
require_relative 'uploader'
require_relative 'target'
require_relative 'config'

$log = Logger.new(STDOUT)

cli_options = Build::Cli.parse.options

puddle    = nil
directory = cli_options[:copy_dir]

case cli_options[:type]
when "nightly"
  build_label = cli_options[:manageiq_ref]
when "release"
  build_label = cli_options[:manageiq_ref]
when nil
  build_label = "test"
else
  puddle = cli_options[:type]
  build_label = "#{cli_options[:type]}-#{cli_options[:manageiq_ref]}"
end

if !cli_options[:local] && cli_options[:build_url]
  build_repo = cli_options[:build_url]
  cfg_base = REFS_DIR.join(cli_options[:build_ref])
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

base_file = BUILD_BASE.join("config/base.json")
target_file = BUILD_BASE.join("config/target.json")
ova_file = BUILD_BASE.join("config/ova.json")

def verify_run(output)
  if output =~ /UUID: (.*)/
    Regexp.last_match[1]
  else
    $log.error("Could not find UUID.")
    exit 1
  end
end

year_month_day    = Time.now.strftime("%Y%m%d")
hour_minute       = Time.now.strftime("%H%M")
directory_name    = "#{year_month_day}_#{hour_minute}"
timestamp         = "#{year_month_day}#{hour_minute}"

name            = "manageiq"

targets = cli_options[:only].collect { |only| Build::Target.new(only) }

manageiq_checkout  = Build::GitCheckout.new(:remote => cli_options[:manageiq_url],  :ref => cli_options[:manageiq_ref])
appliance_checkout = Build::GitCheckout.new(:remote => cli_options[:appliance_url], :ref => cli_options[:appliance_ref])
sui_checkout       = Build::GitCheckout.new(:remote => cli_options[:sui_url],       :ref => cli_options[:sui_ref])
ks_gen = Build::KickstartGenerator.new(cfg_base, cli_options[:only], puddle, manageiq_checkout, appliance_checkout, sui_checkout)
ks_gen.run

file_rdu_dir_base = FILE_SERVER_BASE.join(directory)
file_rdu_dir      = file_rdu_dir_base.join(directory_name)

stream_directory      = FILESHARE_DIR.join(directory)
destination_directory = stream_directory.join(build_label == "test" ? "test" : directory_name)

$log.info "Creating Fileshare Directory: #{destination_directory}"
FileUtils.mkdir_p(destination_directory)

Dir.chdir(IMGFAC_DIR) do
  targets.sort.reverse.each do |target|
    imgfac_target = target.imagefactory_type
    ova_format    = target.ova_format
    $log.info "Building for #{target}:"

    tdl_name = target.name == "azure" ? "base_azure.tdl" : "base.tdl"
    tdl_file = BUILD_BASE.join("config", tdl_name)
    $log.info "Using inputs: puddle: #{puddle}, build_label: #{build_label}"
    $log.info "              tdl_file: #{tdl_file}, ova_file: #{ova_file}."

    input_file  = ks_gen.gen_file_path("base-#{target}.ks")
    output_file = ks_gen.gen_file_path("base-#{target}-#{build_label}-#{timestamp}.ks")

    FileUtils.cp(input_file, output_file)

    params = "--parameters #{base_file} --file-parameter install_script #{output_file}"
    $log.info "Running #{target} base_image using parameters: #{params}"

    output = `./imagefactory --config #{IMGFAC_CONF} base_image #{params} #{tdl_file}`
    uuid   = verify_run(output)
    $log.info "#{target} base_image complete, uuid: #{uuid}"
    temp_file_uuid = [uuid]

    params = "--parameters #{target_file}"
    $log.info "Running #{target} target_image #{imgfac_target} using parameters: #{params}"

    output = `./imagefactory --config #{IMGFAC_CONF} target_image #{params} --id #{uuid} #{imgfac_target}`
    uuid = target_image_uuid = verify_run(output)
    $log.info "#{target} target_image #{imgfac_target} complete, uuid: #{uuid}"
    temp_file_uuid << uuid

    if ova_format
      params = "--parameters #{ova_file} --parameter #{imgfac_target}_ova_format #{ova_format}"
      $log.info "Running #{target} target_image ova using parameters: #{params}"

      output = `./imagefactory --config #{IMGFAC_CONF} target_image #{params} --id #{uuid} ova`
      uuid   = verify_run(output)
      $log.info "#{target} target_image ova complete, uuid: #{uuid}"
      temp_file_uuid << uuid
    end
    $log.info "Built #{target} with final UUID: #{uuid}"
    source = STORAGE_DIR.join("#{uuid}.body")

    FileUtils.mkdir_p(destination_directory)
    file_name = "#{name}-#{target}-#{build_label}-#{timestamp}-#{manageiq_checkout.commit_sha}.#{target.file_extension}"
    destination = destination_directory.join(file_name)
    $log.info `ln #{source} #{destination}`

    if !File.exist?(destination)
      $log.warn "Cannot find the target file #{destination}"
    else
      # Let's copy the file to the file server
      if cli_options[:fileshare] && FILE_SERVER && File.size(destination)
        $log.info "Creating File server #{FILE_SERVER} directory #{file_rdu_dir} ..."
        $log.info `ssh #{FILE_SERVER_ACCOUNT}@#{FILE_SERVER} mkdir -p #{file_rdu_dir}`
        $log.info "Copying file #{file_name} to #{FILE_SERVER}:#{file_rdu_dir}/ ..."
        $log.info `scp #{destination} #{FILE_SERVER_ACCOUNT}@#{FILE_SERVER}:#{file_rdu_dir.join(file_name)}`
      end
    end

    # Ovirt/RHV 4.1 doesn't support ova import, create both qcow2 and ova
    if target.name == "ovirt"
      file_name = "#{name}-#{target}-#{build_label}-#{timestamp}-#{manageiq_checkout.commit_sha}.qc2"
      destination = destination_directory.join(file_name)
      source = STORAGE_DIR.join("#{target_image_uuid}.qc2")
      $log.info "Compress qcow image, #{target_image_uuid}.body"
      $log.info `qemu-img convert -f qcow2 -O qcow2 -o compat=0.10 -c #{STORAGE_DIR.join("#{target_image_uuid}.body")} #{source}`
      $log.info `mv #{source} #{destination}`
      if cli_options[:fileshare] && FILE_SERVER && File.size(destination)
        $log.info `scp #{destination} #{FILE_SERVER_ACCOUNT}@#{FILE_SERVER}:#{file_rdu_dir.join(file_name)}`
      end
    end

    # The final image is moved out of STORAGE_DIR at this point, delete all other files created during build
    temp_file_uuid.each { |file_uuid| FileUtils.rm_f(Dir.glob("#{STORAGE_DIR}/#{file_uuid}.*"), :verbose => true) }
  end

  passphrase_file = GPG_DIR.join("pass")
  public_key_file = GPG_DIR.join("manageiq_public.key")
  if File.exist?(passphrase_file) && File.exist?(public_key_file)
    $log.info "Generating Image Checksums in #{destination_directory} ..."
    Dir.chdir(destination_directory) do
      $log.info `/usr/bin/sha256sum * > SHA256SUM`
      $log.info `/usr/bin/gpg --batch --no-tty --passphrase-file #{passphrase_file} -b SHA256SUM`
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

  if cli_options[:fileshare] && FILE_SERVER
    $log.info "Updating #{symlink_name} symlink on #{FILE_SERVER} ..."
    ssh_cmd = "cd #{file_rdu_dir_base}; rm -f #{symlink_name}; ln -s #{directory_name} #{symlink_name}"
    $log.info `ssh #{FILE_SERVER_ACCOUNT}@#{FILE_SERVER} "#{ssh_cmd}"`
  end

  Build::Uploader.upload(destination_directory, cli_options[:type]) if cli_options[:upload]
end
