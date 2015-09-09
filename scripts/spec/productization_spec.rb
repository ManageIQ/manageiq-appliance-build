require 'spec_helper'
require 'productization'

describe Build::Productization do
  describe ".file_for" do
    it "finds the file when productization version exists" do
      file = described_class.file_for(data_file_path("prod"), "test_prod")
      expect(file.to_s).to match(%r{productization/test_prod})
    end

    it "finds the file when productization version does not exist" do
      file = described_class.file_for(data_file_path("prod"), "test_no_prod")
      expect(file.to_s).not_to match(%r{productization/test_no_prod})
    end
  end
end
