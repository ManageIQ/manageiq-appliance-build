require 'spec_helper'
require 'cli'

describe Build::Cli do
  context "#parse" do
    it "only (default)" do
      expect(described_class.new.parse(%w()).options[:only]).to match_array %w(vsphere ovirt openstack vhd)
    end

    it "only vsphere and ovirt" do
      expect(described_class.new.parse(%w(-o vsphere ovirt)).options[:only]).to match_array %w(vsphere ovirt)
    end
  end
end
