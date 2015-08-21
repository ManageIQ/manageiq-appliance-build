require 'erb'
require 'json'
require 'fileutils'
require 'pathname'

module Build
  class KickstartGenerator
    KS_DIR      = "kickstarts"
    KS_GEN_DIR  = "#{KS_DIR}/generated"
    KS_PART_DIR = "#{KS_DIR}/partials"

    attr_reader :targets, :puddle, :appliance_checkout, :manageiq_checkout

    def initialize(build_base, targets, puddle, appliance_checkout, manageiq_checkout)
      @build_base         = build_base
      @ks_gen_base        = @build_base.join(KS_GEN_DIR)
      @targets            = targets
      @puddle             = puddle # used during ERB evaluation
      @appliance_checkout = appliance_checkout
      @manageiq_checkout  = manageiq_checkout
    end

    def run(task = :all)
      targets.each do |target|
        @target = target # used during ERB evaluation

        result = evaluate_erb

        FileUtils.mkdir_p(@ks_gen_base)
        File.write(@ks_gen_base.join("base.ks"), result)

        write_config(result) if [:all, :config].include?(task)
        write_json(result)   if [:all, :json].include?(task)
      end
    end

    def gen_file_path(file)
      @ks_gen_base.join(file)
    end

    private

    def write_config(result)
      file = @ks_gen_base.join("base-#{@target}.cfg")
      $log.info("Writing kickstart in config format: #{file}") if $log
      File.write(file, result)
    end

    def write_json(result)
      json = {
        "install_script"  => result,
        "generate_icicle" => false
      }.to_json

      file = @ks_gen_base.join("base-#{@target}.json")
      $log.info("Writing kickstart in json format: #{file}") if $log
      File.write(file, json)
    end

    def evaluate_erb
      ks_file = @build_base.join("#{KS_DIR}/base.ks.erb")
      ERB.new(File.read(ks_file)).result(binding)
    end

    def render_partial(filename)
      file = Productization.file_for(@build_base, "#{KS_PART_DIR}/#{filename}.ks.erb")
      ERB.new(File.read(file)).result(binding)
    end
  end
end
