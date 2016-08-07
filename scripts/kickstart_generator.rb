require_relative 'productization'

require 'erb'
require 'json'
require 'fileutils'
require 'pathname'

module Build
  class KickstartGenerator
    KS_DIR      = "kickstarts"
    KS_GEN_DIR  = "#{KS_DIR}/generated"
    KS_PART_DIR = "#{KS_DIR}/partials"

    attr_reader :targets, :puddle, :manageiq_checkout, :appliance_checkout, :ssui_checkout

    def initialize(build_base, targets, puddle, manageiq_checkout, appliance_checkout, ssui_checkout)
      @build_base         = Pathname.new(build_base)
      @ks_gen_base        = @build_base.join(KS_GEN_DIR)
      @targets            = targets
      @puddle             = puddle # used during ERB evaluation
      @manageiq_checkout  = manageiq_checkout
      @appliance_checkout = appliance_checkout
      @ssui_checkout      = ssui_checkout
    end

    def run
      FileUtils.mkdir_p(@ks_gen_base)

      targets.each do |target|
        @target = target # used during ERB evaluation

        result = evaluate_erb

        file = @ks_gen_base.join("base-#{@target}.ks")
        $log.info("Writing kickstart file: #{file}") if $log
        File.write(file, result)
      end
    end

    def gen_file_path(file)
      @ks_gen_base.join(file)
    end

    private

    def evaluate_erb
      ks_file = Productization.file_for(@build_base, "#{KS_DIR}/base.ks.erb")
      ERB.new(File.read(ks_file)).result(binding)
    end

    def render_partial(filename)
      file = Productization.file_for(@build_base, "#{KS_PART_DIR}/#{filename}.ks.erb")
      ERB.new(File.read(file)).result(binding)
    end
  end
end
