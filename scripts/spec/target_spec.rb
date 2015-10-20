require 'spec_helper'
require 'target'

describe Build::Target do
  context "#initialize" do
    it ":vsphere" do
      expect(described_class.new(:vsphere).name).to eql "vsphere"
    end

    it "vsphere" do
      expect(described_class.new("vsphere").name).to eql "vsphere"
    end
  end

  it "#imagefactory_type" do
    expect(described_class.new("vpc").imagefactory_type).to eql "vpc"
  end

  it "#file_extension" do
    expect(described_class.new("vpc").file_extension).to eql "vpc"
  end

  it "#sort" do
    targets = [described_class.new("vsphere"), described_class.new("openstack")]
    expect(targets.sort.collect(&:name)).to eql %w(openstack vsphere)
  end

  it ".supported_types" do
    expect(described_class.supported_types).to match_array %w(openstack ovirt vsphere vhd)
  end

  it "#to_s" do
    expect(described_class.new("vsphere").to_s).to eql "vsphere"
  end
end
