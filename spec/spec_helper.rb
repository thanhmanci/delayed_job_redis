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

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end


dir = File.dirname(File.expand_path(__FILE__))

#
# start our own redis when the tests start,
# kill it when they end
#

at_exit do
  pid = `ps -A -o pid,command | grep [r]edis_test`.split(" ")[0]
  puts "Killing test redis server..."
  `rm -f #{dir}/dump.rdb`
  Process.kill("KILL", pid.to_i)
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis_test.conf`
raise "Failed to start redis-server: #{$?}" unless 0 == $?

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
  
  Delayed::Job.redis = "redis://localhost:9736/dj_test"
  Delayed::Worker.delay_jobs = true
  
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