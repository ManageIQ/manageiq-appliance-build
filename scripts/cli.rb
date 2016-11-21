require 'rubygems'
require 'trollop'
require_relative 'target'

module Build
  class Cli
    attr_reader :options
    ALLOWED_TYPES = %w(nightly release test)
    DEFAULT_TYPE  = "nightly"
    DEFAULT_REF   = "master"
    VANEQ_REF     = "darga-vaneq"
    MANAGEIQ_URL  = "http://gitlab.vanecloud.com:8077/anyisalin/vaneq.git"
    APPLIANCE_URL = "http://gitlab.vanecloud.com:8077/anyisalin/manageiq-appliance.git"
    BUILD_URL     = "http://gitlab.vanecloud.com:8077/anyisalin/manageiq-appliance-build.git"
    SUI_URL       = "http://gitlab.vanecloud.com:8077/anyisalin/manageiq-ui-service.git"

    def parse(args = ARGV)
      git_ref_desc   = "provide a git reference such as a branch or tag, non \"#{DEFAULT_REF}\" is required for 'release' type"
      type_desc      = "build type: nightly, release, test, a named yum repository"
      local_desc     = "Use local config and kickstart for build"
      dir_desc       = "Directory to copy builds to"
      share_desc     = "Copy builds to file share"
      manageiq_desc  = "Repo URL containing the ManageIQ code"
      appliance_desc = "Repo URL containing appliance scripts and configs(COPY/LINK/TEMPLATE)"
      build_desc     = "Repo URL containing the build config and kickstart"
      ssui_desc      = "Repo URL containing the ManageIQ self service UI code"
      upload_desc    = "Upload appliance builds to the website"
      only_desc      = "Build only specific image types.  Example: --only ovirt openstack.  Defaults to all images."

      @options = Trollop.options(args) do
        banner "Usage: build.rb [options]"
        opt :appliance_ref, git_ref_desc,   :type => :string,  :short => "a", :default => DEFAULT_REF
        opt :appliance_url, appliance_desc, :type => :string,  :short => "A", :default => APPLIANCE_URL
        opt :build_ref,     git_ref_desc,   :type => :string,  :short => "b", :default => DEFAULT_REF
        opt :build_url,     build_desc,     :type => :string,  :short => "B", :default => BUILD_URL
        opt :reference,     git_ref_desc,   :type => :string,  :short => "r", :default => nil
        opt :copy_dir,      dir_desc,       :type => :string,  :short => "d", :default => DEFAULT_REF
        opt :fileshare,     share_desc,     :type => :boolean, :short => "f", :default => true
        opt :local,         local_desc,     :type => :boolean, :short => "l", :default => false
        opt :manageiq_ref,  git_ref_desc,   :type => :string,  :short => "m", :default => DEFAULT_REF
        opt :manageiq_url,  manageiq_desc,  :type => :string,  :short => "M", :default => MANAGEIQ_URL
        opt :only,          only_desc,      :type => :strings, :short => "o", :default => Target.default_types
        opt :ssui_ref,      git_ref_desc,   :type => :string,  :short => "s", :default => DEFAULT_REF
        opt :ssui_url,      ssui_desc,      :type => :string,  :short => "S", :default => SSUI_URL
        opt :type,          type_desc,      :type => :string,  :short => "t", :default => DEFAULT_TYPE
        opt :upload,        upload_desc,    :type => :boolean, :short => "u", :default => false
      end

      options[:type] &&= options[:type].strip

      if options[:only].include?('all')
        options[:only] = Target.supported_types
      end

      # --reference overrides all other reference arguments
      [:manageiq_ref, :appliance_ref, :build_ref, :ssui_ref].each do |ref|
        options[ref] = (options[:reference] || options[ref]).to_s.strip
      end
      Trollop.die(:manageiq_ref, git_ref_desc) if options[:manageiq_ref].to_s.empty?

      # 'release' build requires non DEFAULT_REF reference
      Trollop.die(:manageiq_ref, git_ref_desc) if options[:type] == "release" && options[:manageiq_ref] == DEFAULT_REF

      self
    end

    def self.parse
      new.parse
    end
  end
end
