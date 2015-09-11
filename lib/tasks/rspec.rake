begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.verbose = true
    t.ruby_opts = "-Iscripts:scripts/spec"
    t.pattern = 'scripts/spec/**/*_spec.rb'
  end
rescue LoadError
end
