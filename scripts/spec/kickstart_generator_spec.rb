require 'spec_helper'
require 'kickstart_generator'

describe Build::KickstartGenerator do
  describe "#run" do
    def build_base
      data_file_path("kickstart_generator")
    end

    def generated
      "#{build_base}/kickstarts/generated"
    end

    def ks_text
      File.read("#{generated}/base.ks")
    end

    after(:each) do
      FileUtils.rm_f(Dir.glob("#{generated}/*"))
    end

    before(:each) do
      @generator = described_class.new(build_base, ["target"], "puddle", "app_checkout", "miq_checkout")
      @generator.run(nil)
    end

    it "writes ks file" do
      expect(ks_text).to include("base file text")
    end

    it "renders partial files" do
      expect(ks_text).to include("first partial file text")
    end

    it "renders partials in partial files" do
      expect(ks_text).to include("second partial file text")
    end

    it "renders partial files in subdirectories" do
      expect(ks_text).to include("subdir partial text")
    end
  end
end
