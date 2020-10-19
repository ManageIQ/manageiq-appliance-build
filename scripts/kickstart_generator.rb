require 'erb'
require 'json'
require 'fileutils'
require 'pathname'

require_relative 'productization'

module Build
  class KickstartGenerator
    KS_DIR      = "kickstarts"
    KS_GEN_DIR  = "#{KS_DIR}/generated"
    KS_PART_DIR = "#{KS_DIR}/partials"

    attr_reader :targets, :product_name, :puddle

    def initialize(build_base, build_type, targets, product_name, puddle)
      @build_base         = Pathname.new(build_base)
      @build_type         = build_type
      @ks_gen_base        = @build_base.join(KS_GEN_DIR)
      @targets            = targets
      @product_name       = product_name
      @puddle             = puddle # used during ERB evaluation
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

    def render(dir, filename, raise_on_missing = true)
      file = Productization.file_for(@build_base, "#{dir}/#{filename}.ks.erb")

      if file.nil?
        if raise_on_missing
          raise ArgumentError, "partial file #{filename.inspect} not found"
        else
          return
        end
      end

      ERB.new(File.read(file)).result(binding)
    end

    def evaluate_erb
      render(KS_DIR, "base")
    end

    def render_partial(filename)
      render(KS_PART_DIR, filename)
    end

    def render_partial_if_exist(filename)
      render(KS_PART_DIR, filename, false)
    end
  end
end
