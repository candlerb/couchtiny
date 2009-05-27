require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/clean'

task :default => :test

Rake::TestTask.new do |t|
  t.ruby_opts << "-rubygems"
  t.test_files = FileList['test/t-*.rb']
  t.verbose = true
end

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.template = ENV['template'] if ENV['template']
  rdoc.title    = 'CouchTiny Documentation'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.options << '--charset' << 'utf-8'
  rdoc.rdoc_files.include('*.rdoc')
  rdoc.rdoc_files.include('doc/**/*.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.main = "README.rdoc"
}

begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/t-*.rb']
    t.verbose = true
  end

rescue LoadError
end
