require 'toystore'
require 'toy/identity/incremented_key_factory'

module Delayed
  module Backend
    module Redis
      class Job
        include Delayed::Backend::Base
        include Toy::Store
        
        cattr_accessor :default_queue
        self.default_queue = "default"
        
        attribute :priority, Integer
        attribute :attempts, Integer
        attribute :handler, String
        attribute :last_error, String
        attribute :run_at, Time
        attribute :locked_at, Time
        attribute :locked_by, String
        attribute :failed_at, Time
        attribute :queue, String
                
        before_create do |o|
          o.attempts   = 0
          o.priority ||= 0
          o.queue    ||= self.class.default_queue
          o.run_at   ||= self.class.db_time_now
          self.class.push(o)
        end
        
        # Accepts:
        #   1. A 'hostname:port' String
        #   2. A 'hostname:port:db' String (to select the Redis db)
        #   3. A 'hostname:port/namespace' String (to set the Redis namespace)
        #   4. A Redis URL String 'redis://host:port'
        #   5. An instance of `Redis`, `Redis::Client`, `Redis::DistRedis`,
        #      or `Redis::Namespace`.
        def self.redis=(server)
          case server
          when String
            if server =~ /redis\:\/\//
              redis = ::Redis.connect(:url => server, :thread_safe => true)
            else
              server, namespace = server.split('/', 2)
              host, port, db = server.split(':')
              redis = ::Redis.new(:host => host, :port => port,
                :thread_safe => true, :db => db)
            end
            namespace ||= :delayed_job

            @redis = ::Redis::Namespace.new(namespace, :redis => redis)
          when ::Redis::Namespace
            @redis = server
          else
            @redis = ::Redis::Namespace.new(:delayed_job, :redis => server)
          end         
          
          @redis.tap do |redis|
            store :redis, redis
            key Toy::Identity::IncrementedKeyFactory.new(redis)
          end
        end

        def self.redis
          raise "Delayed::Job.redis is not set. A redis instance or connections string must be provided." unless @redis
          @redis
        end
        
        class << self
          def count
            queues.map{ |q| redis.llen(queue_key(q)) }.sum
          end
          
          def delete_all
            queues.each do |q|
              redis.del(queue_key(q))
              del_queue(q)
            end
            timestamps.each do |t|
              redis.del(timestamp_key(t))
            end
            %w(queues timestamps).each{ |k| redis.del(k) }
          end
        
          def queues
            redis.smembers('queues') || []
          end
                   
          # jobs are never locked
          def clear_locks!(worker_name)
            return true
          end

          def reserve(worker, _ = nil)
            search_queues = worker.queues.any? ? worker.queues : queues
            result = nil
            search_queues.detect{ |q| result = pop(q) }
            result
          end
            
          def push(job)
            if (job.run_at && job.run_at > db_time_now)
              delayed_push(job)
            else
              immediate_push(job)
            end
          end

          def db_time_now
            Time.current
          end
          
          private
          
            def pop(queue)
              repush_ready_jobs
              
              id = redis.lpop(queue_key(queue))
              get(id) if id
            end
            
            def add_queue(queue)
              redis.sadd('queues', queue)
            end

            def del_queue(queue)
              redis.srem('queues', queue)
            end

            def queue_key(queue)
              "queues:#{queue}"
            end
            
            def timestamp_key(time)
              "delayed:#{time.to_i}"
            end
            
            def timestamps
              redis.zrange("timestamps", 0, -1)
            end
            
            def immediate_push(job)
              add_queue(job.queue)
              redis.rpush(queue_key(job.queue), job.id)
            end
            
            def delayed_push(job)
              # Add the job to a list for a particular timestamp and record the timestamp in a queue
              redis.rpush(timestamp_key(job.run_at), job.id)
              redis.zadd("timestamps", job.run_at.to_i, job.run_at.to_i)
            end
            
            def repush_ready_jobs
              ready_timestamps.each do |time_i| 
                repush_jobs_for_timestamp(time_i) 
              end
            end
            
            def ready_timestamps
              redis.zrangebyscore "timestamps", 0, db_time_now.to_i
            end
                        
            def repush_jobs_for_timestamp(time_i)
              while id = redis.lpop(timestamp_key(time_i))
                immediate_push(self.class.get(id))
              end                            
              redis.zrem("timestamps", time_i)
            end
        end
      
        # Jobs for this backend, once popped don't require locking
        def lock_exclusively!(max_run_time, worker)
          self.locked_at = self.class.db_time_now
          self.locked_by = worker.name
          return true
        end
           
        def reload
          reset
          super
        end
        
        private
        
          def redis
            self.class.redis
          end
      end
    end
  end
end