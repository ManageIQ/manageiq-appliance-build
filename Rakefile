require_relative 'scripts/productization'
require 'pathname'

namespace :build do

  module FilePaths
    BUILD        = Pathname.new(__dir__).join("../manageiq/BUILD")
    VERSION      = Pathname.new(__dir__).join("../manageiq/VERSION")
  end

  class ConfigOptions
    require "yaml"
    include FilePaths
    def self.options
      @options ||= YAML.load_file(Build::Productization.file_for((__dir__), "config/tarball/options.yml"))
    end

    def self.version
      ENV["VERSION_ENV"] || options[:version] || File.read(VERSION).chomp
    end

    def self.prefix
      options[:name_prefix]
    end
  end

  task :build_file do
    date    = Time.now.strftime("%Y%m%d%H%M%S")
    git_sha = `git rev-parse --short HEAD`
    build   = "#{ConfigOptions.version}-#{date}_#{git_sha}"
    File.write(FilePaths::BUILD, build)
  end

  task :version_files do
    File.write(FilePaths::VERSION, "#{ConfigOptions.version}\n")
  end

  task :precompile_assets do
    Dir.chdir(File.join(__dir__, '..', 'manageiq'))
    puts `bundle exec rake evm:compile_assets`
    Dir.chdir(__dir__)
  end

  desc "Builds a tarball."
  task :tar => [:version_files, :build_file, :precompile_assets] do
    exclude_file = Build::Productization.file_for((__dir__), "config/tarball/exclude")
    pkg_path     = Pathname.new(__dir__).join("pkg")
    FileUtils.mkdir_p(pkg_path)

    tar_basename = "#{ConfigOptions.prefix}-#{ConfigOptions.version}"
    tarball = "pkg/#{tar_basename}.tar.gz"

    # Add a prefix-version directory to the top of the files added to the tar.
    # This is needed by rpm tooling.
    transform = RUBY_PLATFORM =~ /darwin/ ? "-s " : "--transform s"
    transform << "',^,#{tar_basename}/,'"

    `tar -C ../manageiq #{transform} -X #{exclude_file} -hcvzf #{tarball} .`
    puts "Built tarball at:\n #{File.expand_path(tarball)}"
  end
end

task :default => "build:tar"
