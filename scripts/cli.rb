require 'rubygems'
require 'trollop'

module Build
  class Cli
    attr_reader :options
    ALLOWED_TYPES = %w(nightly test)
    DEFAULT_TYPE  = "nightly"
    DEFAULT_REF   = "master"
    DEFAULT_REPO  = "http://github.com/ManageIQ/manageiq-appliance.git"

    def parse
      git_ref_desc  = "provide a git reference such as a branch or tag"
      type_desc     = "build type: nightly, test, a named yum repository"
      local_desc    = "Use local config and kickstart for build"
      share_desc    = "Copy builds to file share"
      repo_desc     = "repository to use for build config and kickstart"

      @options = Trollop.options do
        banner "Usage: build.rb [options]"

        opt :type,        type_desc,     :type => :string,  :default => DEFAULT_TYPE, :short => "t"
        opt :reference,   git_ref_desc,  :type => :string,  :default => DEFAULT_REF,  :short => "r"
        opt :local,       local_desc,    :type => :boolean, :default => false,        :short => "l"
        opt :fileshare,   share_desc,    :type => :boolean, :default => true,         :short => "s"
        opt :repo,        repo_desc,     :type => :string,  :default => DEFAULT_REPO, :short => "R"
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
