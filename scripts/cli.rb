require 'rubygems'
require 'optimist'
require_relative 'target'

module Build
  class Cli
    attr_reader :options
    ALLOWED_TYPES   = %w(nightly release test)
    DEFAULT_TYPE    = "nightly"
    DEFAULT_REF     = "master"
    DEFAULT_PRODUCT = "manageiq"
    BUILD_URL       = "https://github.com/ManageIQ/manageiq-appliance-build.git"

    def parse(args = ARGV)
      git_ref_desc   = "provide a git reference such as a branch or tag, non \"#{DEFAULT_REF}\" is required for 'release' type"
      product_desc   = "product name.  Defaults to \"#{DEFAULT_PRODUCT}\"."
      type_desc      = "build type: nightly, release, test, a named yum repository"
      local_desc     = "Use local config and kickstart for build"
      dir_desc       = "Directory to copy builds to"
      share_desc     = "Copy builds to file share"
      build_desc     = "Repo URL containing the build config and kickstart"
      upload_desc    = "Upload appliance builds to the website"
      only_desc      = "Build only specific image types.  Example: --only ovirt openstack.  Defaults to all images."
      delete_desc    = "Delete artifacts from fileshare after upload"

      @options = Optimist.options(args) do
        banner "Usage: build.rb [options]"
        opt :build_ref,     git_ref_desc,   :type => :string,  :short => "b", :default => nil
        opt :build_url,     build_desc,     :type => :string,  :short => "B", :default => BUILD_URL
        opt :reference,     git_ref_desc,   :type => :string,  :short => "r", :default => DEFAULT_REF
        opt :product_name,  product_desc,   :type => :string,  :short => "p", :default => DEFAULT_PRODUCT
        opt :copy_dir,      dir_desc,       :type => :string,  :short => "d", :default => DEFAULT_REF
        opt :fileshare,     share_desc,     :type => :boolean, :short => "f", :default => true
        opt :local,         local_desc,     :type => :boolean, :short => "l", :default => false
        opt :only,          only_desc,      :type => :strings, :short => "o", :default => Target.default_types
        opt :type,          type_desc,      :type => :string,  :short => "t", :default => DEFAULT_TYPE
        opt :upload,        upload_desc,    :type => :boolean, :short => "u", :default => false
        opt :delete,        delete_desc,    :type => :boolean, :short => "e", :default => false
      end

      options[:type] &&= options[:type].strip

      if options[:only].include?('all')
        options[:only] = Target.supported_types
      end

      # release build: always set build_ref to be same as reference
      # non-release build: build_ref overrides the reference argument if provided
      if options[:type] == "release"
        options[:build_ref] = options[:reference]
      else
        options[:build_ref] = (options[:build_ref] || options[:reference]).to_s.strip
      end

      # 'release' build requires non DEFAULT_REF reference
      Optimist.die(:reference, git_ref_desc) if options[:type] == "release" && options[:reference] == DEFAULT_REF

      self
    end

    def self.parse
      new.parse
    end
  end
end
