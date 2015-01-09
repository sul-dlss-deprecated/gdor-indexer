require 'rake'
require 'bundler'
require "bundler/gem_tasks"

require 'rspec/core/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

# add tasks defined in lib/tasks
#Dir.glob('lib/tasks/*.rake').each { |r| import r }

#desc "Open an irb session preloaded with this library"
#task :console do
#  sh "irb -rubygems -I lib  -r ./frda_indexer.rb"
#end

task :default => :ci  

desc "run continuous integration suite (tests, coverage, docs)" 
task :ci => [:rspec, :doc]

task :spec => :rspec

RSpec::Core::RakeTask.new(:rspec) do |spec|
  spec.rspec_opts = ["-c", "-f progress", "--tty", "-r ./spec/spec_helper.rb"]
end

RSpec::Core::RakeTask.new(:rspec_wip) do |spec|
  spec.rspec_opts = ["-c", "-f d", "--tty", "-r ./spec/spec_helper.rb", "-t wip"]
end

# Use yard to build docs
begin
  project_root = File.expand_path(File.dirname(__FILE__))
  doc_dest_dir = File.join(project_root, 'doc')

  YARD::Rake::YardocTask.new(:doc) do |yt|
    yt.files = Dir.glob(File.join(project_root, 'lib', '**', '*.rb')) +
                 [ File.join(project_root, 'README.rdoc') ]
    yt.options = ['--output-dir', doc_dest_dir, '--readme', 'README.rdoc', '--title', 'Gryphondor Indexer Documentation']
  end
rescue LoadError
  desc "Generate YARD Documentation"
  task :doc do
    abort "Please install the YARD gem to generate rdoc."
  end
end  

