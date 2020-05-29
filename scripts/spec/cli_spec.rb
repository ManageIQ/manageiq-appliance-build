require 'spec_helper'
require 'cli'

describe Build::Cli do
  context "#parse" do
    it "only (default)" do
      expect(described_class.new.parse(%w()).options[:only]).to match_array %w(vsphere ovirt openstack hyperv azure vagrant libvirt gce ec2)
    end

    it "all" do
      expect(described_class.new.parse(%w(-o all)).options[:only]).to match_array %w(vsphere ovirt openstack hyperv azure vagrant libvirt gce ec2)
    end

    it "only vsphere and ovirt" do
      expect(described_class.new.parse(%w(-o vsphere ovirt)).options[:only]).to match_array %w(vsphere ovirt)
    end

    it "type (default)" do
      expect(described_class.new.parse(%w()).options[:type]).to eq("nightly")
    end

    it "with a branch name for reference override" do
      expect(described_class.new.parse(%w(--reference branch_name)).options[:build_ref]).to eq("branch_name")
      expect(described_class.new.parse(%w(--reference branch_name)).options[:reference]).to eq("branch_name")
    end

    it "with a branch name for build reference" do
      expect(described_class.new.parse(%w(-b branch_name)).options[:build_ref]).to eq("branch_name")
      expect(described_class.new.parse(%w(-b branch_name)).options[:reference]).to eq("master")
    end

    it "with DEFAULT_REF for reference override" do
      expect(described_class.new.parse(%w(--reference master -b branch_name)).options[:build_ref]).to eq("branch_name")
      expect(described_class.new.parse(%w(--reference master -b branch_name)).options[:reference]).to eq("master")
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
      expect(options[:build_ref]).to eq("abc")
    end

    it "release with build reference" do
      options = described_class.new.parse(%w(--type release --reference abc -b branch_name)).options
      expect(options[:type]).to eq("release")
      expect(options[:reference]).to eq("abc")
      expect(options[:build_ref]).to eq("abc")
    end
  end
end
