require 'redis'
require 'redis/namespace'
require 'delayed_job'

require 'delayed/backend/redis'
Delayed::Worker.backend = Delayed::Backend::Redis::Job