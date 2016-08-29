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
    expect(described_class.new("openstack").imagefactory_type).to eql "openstack-kvm"
  end

  it "#file_extension" do
    expect(described_class.new("openstack").file_extension).to eql "qc2"
  end

  it "#sort" do
    targets = [described_class.new("vsphere"), described_class.new("openstack")]
    expect(targets.sort.collect(&:name)).to eql %w(openstack vsphere)
  end

  it ".supported_types" do
    expect(described_class.supported_types).to match_array %w(openstack ovirt vsphere hyperv azure vagrant libvirt gce)
  end

  it ".default_types" do
    expect(described_class.default_types).to match_array %w(openstack ovirt vsphere hyperv azure vagrant libvirt gce)
  end

  it "#to_s" do
    expect(described_class.new("vsphere").to_s).to eql "vsphere"
  end
end
