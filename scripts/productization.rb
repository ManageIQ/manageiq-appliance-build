require 'pathname'

module Build
  class Productization
    PROD_DIR  = "productization"

    def self.file_for(build_base, path)
      build_dir  = Pathname.new(build_base)
      prod_file  = build_dir.join(PROD_DIR).join(path)
      build_file = build_dir.join(path)
      [prod_file, build_file].detect { |f| File.exist?(f) }
    end
  end
end
