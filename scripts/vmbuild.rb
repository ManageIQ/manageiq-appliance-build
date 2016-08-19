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

BUILD_BASE          = Pathname.new("/build")
GPG_DIR             = Pathname.new("/root/.gnupg")
CFG_DIR             = BUILD_BASE.join("config")
FILESHARE_DIR       = BUILD_BASE.join("fileshare")
REFS_DIR            = BUILD_BASE.join("references")
IMGFAC_DIR          = BUILD_BASE.join("imagefactory")
IMGFAC_CONF         = CFG_DIR.join("imagefactory.conf")
STORAGE_DIR         = BUILD_BASE.join("storage")

FILE_SERVER         = ENV["BUILD_FILE_SERVER"]             # SSH Server to host files
FILE_SERVER_ACCOUNT = ENV["BUILD_FILE_SERVER_ACCOUNT"]     # Account to SSH as
FILE_SERVER_BASE    = Pathname.new(ENV["BUILD_FILE_SERVER_BASE"] || ".") # Subdirectory of Account where to store builds

if !cli_options[:local] && cli_options[:build_url]
  build_repo = cli_options[:build_url]
  cfg_base = REFS_DIR.join(cli_options[:build_ref])
  FileUtils.mkdir_p(cfg_base)
  Dir.chdir(cfg_base) do
    unless File.exist?(".git")
      $log.info("Cloning Repo #{build_repo} to #{cfg_base} ...")
      `git clone #{build_repo} .` unless File.exist?(".git")
    end
    $log.info("Checking out reference #{cli_options[:build_ref]} from repo #{build_repo} ...")
    `git reset --hard`                                    # Drop any local changes
    `git clean -dxf`                                      # Clean up any local untracked changes
    `git checkout #{cli_options[:build_ref]}`             # Checkout existing branch
    `git fetch origin`                                    # Get origin updates
    `git reset --hard origin/#{cli_options[:build_ref]}`  # Reset the branch to the origin
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
ssui_checkout      = Build::GitCheckout.new(:remote => cli_options[:ssui_url],      :ref => cli_options[:ssui_ref])
ks_gen = Build::KickstartGenerator.new(cfg_base, cli_options[:only], puddle, manageiq_checkout, appliance_checkout, ssui_checkout)
ks_gen.run

file_rdu_dir_base = FILE_SERVER_BASE.join(directory)
file_rdu_dir      = file_rdu_dir_base.join(directory_name)

fileshare_dir         = BUILD_BASE.join("fileshare")
stream_directory      = fileshare_dir.join(directory)
destination_directory = stream_directory.join(build_label == "test" ? "test" : directory_name)

$log.info "Creating Fileshare Directory: #{destination_directory}"
FileUtils.mkdir_p(destination_directory)

Dir.chdir(IMGFAC_DIR) do
  targets.sort.reverse.each do |target|
    imgfac_target = target.imagefactory_type
    ova_format    = target.ova_format
    vhd_image     = target.file_extension == "vhd"
    gce_image     = target == "gce"
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

    params = "--parameters #{target_file}"
    $log.info "Running #{target} target_image #{imgfac_target} using parameters: #{params}"

    if !vhd_image && !gce_image
      $log.info "Running #{target} target_image with #{imgfac_target} and uuid: #{uuid}"
      output = `./imagefactory --config #{IMGFAC_CONF} target_image --id #{uuid} #{imgfac_target}`
      uuid   = verify_run(output)
      $log.info "#{target} target_image with imgfac_target: #{imgfac_target} and uuid #{uuid} complete"

    output = `./imagefactory --config #{IMGFAC_CONF} target_image #{params} --id #{uuid} #{imgfac_target}`
    uuid   = verify_run(output)
    $log.info "#{target} target_image #{imgfac_target} complete, uuid: #{uuid}"

    if ova_format
      params = "--parameters #{ova_file} --parameter #{imgfac_target}_ova_format #{ova_format}"
      $log.info "Running #{target} target_image ova using parameters: #{params}"

      output = `./imagefactory --config #{IMGFAC_CONF} target_image #{params} --id #{uuid} ova`
      uuid   = verify_run(output)
      $log.info "#{target} target_image ova complete, uuid: #{uuid}"
    end
    $log.info "Built #{target} with final UUID: #{uuid}"
    source = STORAGE_DIR.join("#{uuid}.body")

    FileUtils.mkdir_p(destination_directory)
    file_name = "#{name}-#{target}-#{build_label}-#{timestamp}-#{manageiq_checkout.commit_sha}.#{target.file_extension}"
    destination = destination_directory.join(file_name)
    $log.info `mv #{source} #{destination}`

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
