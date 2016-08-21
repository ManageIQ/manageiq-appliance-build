require 'spec_helper'
require 'cli'

describe Build::Cli do
  context "#parse" do
    it "only (default)" do
      expect(described_class.new.parse(%w()).options[:only]).to match_array %w(vsphere ovirt openstack hyperv azure vagrant libvirt)
    end

    it "all" do
      expect(described_class.new.parse(%w(-o all)).options[:only]).to match_array %w(vsphere ovirt openstack hyperv azure vagrant libvirt)
    end

    it "only vsphere and ovirt" do
      expect(described_class.new.parse(%w(-o vsphere ovirt)).options[:only]).to match_array %w(vsphere ovirt)
    end

    it "type (default)" do
      expect(described_class.new.parse(%w()).options[:type]).to eq("nightly")
    end

    it "with a branch name for reference override" do
      expect(described_class.new.parse(%w(--reference branch_name)).options[:appliance_ref]).to eq("branch_name")
      expect(described_class.new.parse(%w(--reference branch_name)).options[:build_ref]).to     eq("branch_name")
      expect(described_class.new.parse(%w(--reference branch_name)).options[:manageiq_ref]).to  eq("branch_name")
      expect(described_class.new.parse(%w(--reference branch_name)).options[:ssui_ref]).to      eq("branch_name")
    end

    it "with a branch name for appliance reference" do
      expect(described_class.new.parse(%w(-a branch_name)).options[:appliance_ref]).to eq("branch_name")
      expect(described_class.new.parse(%w(-a branch_name)).options[:build_ref]).to     eq("master")
      expect(described_class.new.parse(%w(-a branch_name)).options[:manageiq_ref]).to  eq("master")
      expect(described_class.new.parse(%w(-a branch_name)).options[:ssui_ref]).to      eq("master")
    end

    it "with a branch name for build reference" do
      expect(described_class.new.parse(%w(-b branch_name)).options[:appliance_ref]).to eq("master")
      expect(described_class.new.parse(%w(-b branch_name)).options[:build_ref]).to     eq("branch_name")
      expect(described_class.new.parse(%w(-b branch_name)).options[:manageiq_ref]).to  eq("master")
      expect(described_class.new.parse(%w(-b branch_name)).options[:ssui_ref]).to      eq("master")
    end

    it "with a branch name for manageiq reference" do
      expect(described_class.new.parse(%w(-m branch_name)).options[:appliance_ref]).to eq("master")
      expect(described_class.new.parse(%w(-m branch_name)).options[:build_ref]).to     eq("master")
      expect(described_class.new.parse(%w(-m branch_name)).options[:manageiq_ref]).to  eq("branch_name")
      expect(described_class.new.parse(%w(-m branch_name)).options[:ssui_ref]).to      eq("master")
    end

    it "with a branch name for ssui reference" do
      expect(described_class.new.parse(%w(-s branch_name)).options[:appliance_ref]).to eq("master")
      expect(described_class.new.parse(%w(-s branch_name)).options[:build_ref]).to     eq("master")
      expect(described_class.new.parse(%w(-s branch_name)).options[:manageiq_ref]).to  eq("master")
      expect(described_class.new.parse(%w(-s branch_name)).options[:ssui_ref]).to      eq("branch_name")
    end

    it "with DEFAULT_REF for reference override" do
      expect(described_class.new.parse(%w(--reference master -a branch_name)).options[:appliance_ref]).to eq("master")
      expect(described_class.new.parse(%w(--reference master -b branch_name)).options[:build_ref]).to     eq("master")
      expect(described_class.new.parse(%w(--reference master -m branch_name)).options[:manageiq_ref]).to  eq("master")
      expect(described_class.new.parse(%w(--reference master -s branch_name)).options[:ssui_ref]).to      eq("master")
    end

    it "release without reference" do
      expect { described_class.new.parse(%w(--type release)) }.to raise_error(SystemExit)
    end

    it "release with DEFAULT_REF for reference" do
      expect { described_class.new.parse(%w(--type release --reference master)) }.to raise_error(SystemExit)
    end

    it "release with non DEFAULT_REF reference" do
      options = described_class.new.parse(%w(--type release --reference abc)).options
      expect(options[:type]).to eq("release")
      expect(options[:reference]).to eq("abc")
    end
  end
end
