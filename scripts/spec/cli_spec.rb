require 'spec_helper'
require 'cli'

describe Build::Cli do
  context "#parse" do
    it "only (default)" do
      expect(described_class.new.parse(%w()).options[:only]).to match_array %w(vsphere ovirt openstack)
    end

    it "all" do
      expect(described_class.new.parse(%w(-o all)).options[:only]).to match_array %w(vsphere ovirt openstack hyperv)
    end

    it "only vsphere and ovirt" do
      expect(described_class.new.parse(%w(-o vsphere ovirt)).options[:only]).to match_array %w(vsphere ovirt)
    end

    it "type (default)" do
      expect(described_class.new.parse(%w()).options[:type]).to eq("nightly")
    end

    it "with DEFAULT_REF as reference" do
      expect(described_class.new.parse(%w(--reference master)).options[:reference]).to eq("master")
    end

    it "release without reference" do
      expect { described_class.new.parse(%w(--type release)) }.to raise_error(SystemExit)
    end

    it "release with DEFAULT_REF as reference" do
      expect { described_class.new.parse(%w(--type release --reference master)) }.to raise_error(SystemExit)
    end

    it "release with non DEFAULT_REF reference" do
      options = described_class.new.parse(%w(--type release --reference abc)).options
      expect(options[:type]).to eq("release")
      expect(options[:reference]).to eq("abc")
    end
  end
end
