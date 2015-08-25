require 'rubygems'
require 'trollop'
require_relative 'target'

module Build
  class Cli
    attr_reader :options
    ALLOWED_TYPES = %w(nightly test)
    DEFAULT_TYPE  = "nightly"
    DEFAULT_REF   = "master"
    APPLIANCE_URL = "https://github.com/ManageIQ/manageiq-appliance.git"
    BUILD_URL     = "https://github.com/ManageIQ/manageiq-appliance-build.git"
    MANAGEIQ_URL  = "https://github.com/ManageIQ/manageiq.git"

    def parse(args = ARGV)
      git_ref_desc  = "provide a git reference such as a branch or tag"
      type_desc     = "build type: nightly, test, a named yum repository"
      local_desc    = "Use local config and kickstart for build"
      share_desc    = "Copy builds to file share"
      appliance_desc = "Repo URL containing appliance scripts and configs(COPY/LINK/TEMPLATE)"
      build_desc     = "Repo URL containing the build config and kickstart"
      manageiq_desc  = "Repo URL containing the main manageiq code"
      only_desc      = "Build only specific image types.  Example: --only ovirt openstack.  Defaults to all images."

      @options = Trollop.options(args) do
        banner "Usage: build.rb [options]"

        opt :type,          type_desc,      :type => :string,  :short => "t", :default => DEFAULT_TYPE
        opt :reference,     git_ref_desc,   :type => :string,  :short => "r", :default => DEFAULT_REF
        opt :local,         local_desc,     :type => :boolean, :short => "l", :default => false
        opt :fileshare,     share_desc,     :type => :boolean, :short => "s", :default => true
        opt :appliance_url, appliance_desc, :type => :string,  :short => "A", :default => APPLIANCE_URL
        opt :build_url,     build_desc,     :type => :string,  :short => "B", :default => BUILD_URL
        opt :manageiq_url,  manageiq_desc,  :type => :string,  :short => "M", :default => MANAGEIQ_URL
        opt :only,          only_desc,      :type => :strings, :short => "o", :default => Target.supported_types
      end

      options[:type] &&= options[:type].strip

      Trollop.die(:reference, git_ref_desc) if options[:reference].to_s.empty?
      options[:reference] = options[:reference].to_s.strip
      self
    end

    def self.parse
      new.parse
    end
  end
end
