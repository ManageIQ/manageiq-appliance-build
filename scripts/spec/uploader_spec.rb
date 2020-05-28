require 'spec_helper'
require 'uploader'

describe Build::Uploader do
  subject { described_class.new("directory", "type") }

  it "#devel_filename" do
    expect(subject.send(:devel_filename, "manageiq-vsphere-master-20200213-2ddd5aa7ba.ova")).to eq("manageiq-vsphere-devel.ova")
    expect(subject.send(:devel_filename, "manageiq-gce-master-20200213-2ddd5aa7ba.tar.gz")).to eq("manageiq-gce-devel.tar.gz")
  end

  it "#nightly_filename" do
    expect(subject.send(:nightly_filename, "manageiq-vsphere-master-202002130919-2ddd5aa7ba.ova")).to eq("manageiq-vsphere-master-20200213-2ddd5aa7ba.ova")
    expect(subject.send(:nightly_filename, "manageiq-gce-ivanchuk-202002130919-2ddd5aa7ba.tar.gz")).to eq("manageiq-gce-ivanchuk-20200213-2ddd5aa7ba.tar.gz")
  end

  it "#release_filename" do
    expect(subject.send(:release_filename, "manageiq-azure-ivanchuk-1-beta1-201907251305-cede8d335c.zip")).to eq("manageiq-azure-ivanchuk-1-beta1.zip")
    expect(subject.send(:release_filename, "manageiq-gce-ivanchuk-1-201909111431-9f959bdc02.tar.gz")).to eq("manageiq-gce-ivanchuk-1.tar.gz")
    expect(subject.send(:release_filename, "manageiq-gce-hammer-1-beta1.1-201810101501-7992680416.tar.gz")).to eq("manageiq-gce-hammer-1-beta1.1.tar.gz")
  end
end
