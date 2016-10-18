require 'spec_helper'
require 'kickstart_generator'

describe Build::KickstartGenerator do
  describe "#run" do
    let(:build_base) { data_file_path("kickstart_generator") }
    let(:generated)  { "#{build_base}/kickstarts/generated" }
    let(:ks_text)    { File.read("#{generated}/base-target.ks") }

    subject { described_class.new(build_base, ["target"], "puddle", "miq_checkout", "app_checkout", "sui_checkout") }

    after do
      FileUtils.rm_rf(generated)
    end

    it "writes ks file" do
      subject.run
      expect(ks_text).to include("base file text")
    end

    it "renders partial files" do
      subject.run
      expect(ks_text).to include("first partial file text")
    end

    it "renders partials in partial files" do
      subject.run
      expect(ks_text).to include("second partial file text")
    end

    it "renders partial files in subdirectories" do
      subject.run
      expect(ks_text).to include("subdir partial text")
    end
  end
end
