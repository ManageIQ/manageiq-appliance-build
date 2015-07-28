require 'pathname'
require 'fileutils'
require 'logger'
require 'pathname'
require 'yaml'

require_relative 'productization'
require_relative 'kickstart_generator'
require_relative 'git_checkout'
require_relative 'cli'
$log = Logger.new(STDOUT)

cli_options = Build::Cli.parse.options

puddle = nil
case cli_options[:type]
when "nightly"
  build_label = cli_options[:reference]
when nil
  build_label = "test"
else
  puddle = cli_options[:type]
  build_label = "#{cli_options[:type]}-#{cli_options[:reference]}"
end

BUILD_BASE          = "/build"
GPG_DIR             = "/root/.gnupg"
CFG_DIR             = "#{BUILD_BASE}/config"
FILESHARE_DIR       = "#{BUILD_BASE}/fileshare"
REFS_DIR            = "#{BUILD_BASE}/references"
IMGFAC_DIR          = "#{BUILD_BASE}/imagefactory"
IMGFAC_CONF         = "#{CFG_DIR}/imagefactory.conf"
STORAGE_DIR         = "#{BUILD_BASE}/storage"

FILE_SERVER         = ENV["BUILD_FILE_SERVER"]             # SSH Server to host files
FILE_SERVER_ACCOUNT = ENV["BUILD_FILE_SERVER_ACCOUNT"]     # Account to SSH as
FILE_SERVER_BASE    = ENV["BUILD_FILE_SERVER_BASE"] || "." # Subdirectory of Account where to store builds

if !cli_options[:local] && cli_options[:build_url]
  build_repo = cli_options[:build_url]
  cfg_base = "#{REFS_DIR}/#{cli_options[:reference]}"
  FileUtils.mkdir_p(cfg_base)
  Dir.chdir(cfg_base) do
    unless File.exist?(".git")
      $log.info("Cloning Repo #{build_repo} to #{cfg_base} ...")
      `git clone #{build_repo} .` unless File.exist?(".git")
    end
    $log.info("Checking out reference #{cli_options[:reference]} from repo #{build_repo} ...")
    `git reset --hard`                                    # Drop any local changes
    `git clean -dxf`                                      # Clean up any local untracked changes
    `git checkout #{cli_options[:reference]}`             # Checkout existing branch
    `git fetch origin`                                    # Get origin updates
    `git reset --hard origin/#{cli_options[:reference]}`  # Reset the branch to the origin
  end

  unless File.exist?(cfg_base)
    $log.error("Could not checkout repo #{build_repo} for reference #{cli_options[:reference]}")
    exit 1
  end
else
  cfg_base = BUILD_BASE
end

$log.info "Using Configuration base directory: #{cfg_base}"

targets_file      = Build::Productization.file_for(cfg_base, "config/targets.yml")
tdl_file          = Build::Productization.file_for(cfg_base, "config/base.tdl")
ova_file          = Build::Productization.file_for(cfg_base, "config/ova.json")

$log.info "Using inputs: puddle: #{puddle}, build_label: #{build_label}, targets_file: #{targets_file}"
$log.info "              tdl_file: #{tdl_file}, ova_file: #{ova_file}."

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

targets_config    = YAML.load_file(targets_file)
name, directory, targets = targets_config.values_at("name", "directory", "targets")

appliance_git_url, manageiq_git_url = cli_options.values_at(:appliance_url, :manageiq_url)

manageiq_checkout  = Build::GitCheckout.new(:remote => manageiq_git_url, :ref => cli_options[:reference])
appliance_checkout = Build::GitCheckout.new(:remote => appliance_git_url, :ref => cli_options[:reference])

file_rdu_dir_base = "#{FILE_SERVER_BASE}/#{directory}"
file_rdu_dir      = "#{file_rdu_dir_base}/#{directory_name}"

ks_gen            = Build::KickstartGenerator.new(cfg_base, targets.keys, puddle, appliance_checkout, manageiq_checkout)
ks_gen.run

FILE_TYPE = {
  'vsphere'       => 'ova',
  'rhevm'         => 'ova',
  'openstack-kvm' => 'qc2'
}

fileshare_dir         = Pathname.new("#{BUILD_BASE}/fileshare")
stream_directory      = fileshare_dir.join(directory)
destination_directory = stream_directory.join(build_label == "test" ? "test" : directory_name)

$log.info "Creating Fileshare Directory: #{destination_directory}"
FileUtils.mkdir_p(destination_directory)

Dir.chdir(IMGFAC_DIR) do
  targets.sort.reverse.each do |target, imgfac_target|
    $log.info "Building for #{target}:"

    input_file  = ks_gen.gen_file_path("base-#{target}.json")
    output_file = ks_gen.gen_file_path("base-#{target}-#{build_label}-#{timestamp}.json")

    FileUtils.cp(input_file, output_file)

    log_params = "kickstart: #{output_file} copied from #{input_file}. tdl: #{tdl_file}"
    $log.info "Running base_image using parameters: #{log_params}"

    output = `./imagefactory --config #{IMGFAC_CONF} base_image --parameters #{output_file} #{tdl_file}`
    uuid   = verify_run(output)
    $log.info "#{target} base_image complete, uuid: #{uuid}"

    $log.info "Running #{target} target_image with #{imgfac_target} and uuid: #{uuid}"
    output = `./imagefactory --config #{IMGFAC_CONF} target_image --id #{uuid} #{imgfac_target}`
    uuid   = verify_run(output)
    $log.info "#{target} target_image with imgfac_target: #{imgfac_target} and uuid #{uuid} complete"

    unless imgfac_target == "openstack-kvm"
      $log.info "Running #{target} target_image ova with ova file: #{ova_file} and uuid: #{uuid}"
      output = `./imagefactory --config #{IMGFAC_CONF} target_image ova --parameters #{ova_file} --id #{uuid}`
      uuid   = verify_run(output)
      $log.info "#{target} target_image ova with uuid: #{uuid} complete"
    end
    $log.info "Built #{target} with final UUID: #{uuid}"
    source      = "#{STORAGE_DIR}/#{uuid}.body"

    FileUtils.mkdir_p(destination_directory)
    file_name = "#{name}-#{target}-#{build_label}-#{timestamp}-#{manageiq_checkout.commit_sha}.#{FILE_TYPE[imgfac_target]}"
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
        $log.info `scp #{destination} #{FILE_SERVER_ACCOUNT}@#{FILE_SERVER}:#{file_rdu_dir}/#{file_name}`
      end
    end
  end
  passphrase_file = "#{GPG_DIR}/pass"
  public_key_file = "#{GPG_DIR}/manageiq_public.key"
  if File.exist?(passphrase_file) && File.exist?(public_key_file)
    $log.info "Generating Image Checksums in #{destination_directory} ..."
    Dir.chdir(destination_directory) do
      $log.info `/usr/bin/sha256sum * > SHA256SUM`
      $log.info `/usr/bin/gpg --batch --no-tty --passphrase-file #{passphrase_file} -b SHA256SUM`
      FileUtils.cp(public_key_file, destination_directory)
    end
  end
end

# Only update the latest symlink for a nightly
unless build_label == "test"
  symlink_name = "latest"
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
end
