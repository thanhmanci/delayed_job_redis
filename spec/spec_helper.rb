$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'delayed_job_redis'

require 'delayed/backend/shared_spec'

require 'toystore'
require 'adapter/redis'
require 'toy/identity/incremented_key_factory'

require 'logger'

RSpec.configure do |config|
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  
  config.before(:each) { Delayed::Job.redis.flushall }
  
  Delayed::Job.redis = "redis://localhost:6379/dj_test"
  Delayed::Worker.delay_jobs = true
  
  Toy.key_factory = Toy::Identity::IncrementedKeyFactory.new(Delayed::Job.redis)
  
  class Story
    include Toy::Store
    store :redis, Delayed::Job.redis
    
    attribute :text, String
    
    def tell; text; end
  end

  # Define some useful equalities for testing purposes
  class SimpleJob
    cattr_accessor :id
    self.id = 0
    
    attr_accessor :id
    
    def initialize
      self.id ||= (@@id += 1);
    end
    
    
    def ==(o)
      self.id == o.id
    end    
  end
  
  class Delayed::Job
    def ==(o)
      self.payload_object == o.payload_object
    end
  end
end