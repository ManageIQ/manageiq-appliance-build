require 'spec_helper'
require 'kickstart_generator'

describe "main/firewall.ks.erb" do
  let(:build_base) { data_file_path("kickstarts/firewall_ks_spec") }
  let(:generated)  { "#{build_base}/kickstarts/generated" }
  let(:ks_text)    { File.read("#{generated}/base.ks") }
  let(:generator)  { Build::KickstartGenerator.new(build_base, ["target"], "puddle", "app_checkout", "miq_checkout") }

  after do
    FileUtils.rm_rf(generated)
  end

  it "expands the VNC port range" do
    # use real partials
    stub_const(
      "Build::KickstartGenerator::KS_PART_DIR",
      REPO_ROOT.join("kickstarts/partials").expand_path.to_s
    )

    generator.run(nil)

    expect(ks_text).to include("5900:tcp,5901:tcp,5902:tcp")
    expect(ks_text).to include("5997:tcp,5998:tcp,5999:tcp")
  end
end
