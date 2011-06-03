require 'redis'
require 'redis/namespace'
require 'delayed_job'

Delayed::Worker.backend = :redis