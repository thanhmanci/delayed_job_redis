# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name              = 'delayed_job_redis'
  s.version           = '0.1.0.pre'
  s.authors           = ["Matt Griffin"]
  s.summary           = 'Redis backend for DelayedJob'
  s.description       = 'Redis backend for DelayedJob'
  s.email             = ['matt@griffinonline.org']
  s.extra_rdoc_files  = 'README.md'
  s.files             = Dir.glob('{lib,spec}/**/*') +
                        %w(LICENSE README.md)
  s.homepage          = 'http://github.com/betamatt/delayed_job_active_record'
  s.rdoc_options      = ["--main", "README.md", "--inline-source", "--line-numbers"]
  s.require_paths     = ["lib"]
  s.test_files        = Dir.glob('spec/**/*')

  s.add_runtime_dependency      'redis',  '~> 2.2'
  s.add_runtime_dependency      'redis-namespace'
  s.add_runtime_dependency      'delayed_job',   '3.0.0.pre'
  
  s.add_development_dependency  'rspec',          '~> 2.0'
  s.add_development_dependency  'rake',           '~> 0.8'
  s.add_development_dependency  'toystore'
  s.add_development_dependency  'adapter-redis'
end
