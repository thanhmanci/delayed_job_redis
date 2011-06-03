module Delayed
  module Backend
    module Redis
      class Job
        attr_accessor :priority
        attr_accessor :attempts
        attr_accessor :handler
        attr_accessor :last_error
        attr_accessor :run_at
        attr_accessor :locked_at # not really relevant but the worker requires it
        attr_accessor :locked_by 
        attr_accessor :failed_at
        attr_accessor :queue
        
        include Delayed::Backend::Base
        
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
        end

        def self.redis
          @redis
        end
        
        def initialize(hash = {})
          self.attempts = 0
          self.priority = 0
          hash.each{|k,v| send(:"#{k}=", v)}
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
        
          def create(attrs = {})
            new(attrs).tap do |o|
              o.save
            end
          end
                  
          def create!(*args); create(*args); end
                   
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
            if (job.run_at && job.run_at > Time.current)
              delayed_push(job)
            else
              immediate_push(job)
            end
          end

          private
          
            def pop(queue)
              repush_ready_jobs
              
              result = redis.lpop(queue_key(queue))
              result = YAML.load(result) if result
              result
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
              redis.rpush(queue_key(job.queue), YAML.dump(job))
            end
            
            def delayed_push(job)
              # Add the job to a list for a particular timestamp and record the timestamp in a queue
              redis.rpush(timestamp_key(job.run_at), YAML.dump(job))
              redis.zadd("timestamps", job.run_at.to_i, job.run_at.to_i)
            end
            
            def repush_ready_jobs
              ready_timestamps.each do |time_i| 
                repush_jobs_for_timestamp(time_i) 
              end
            end
            
            def ready_timestamps
              redis.zrangebyscore "timestamps", 0, Time.current.to_i
            end
                        
            def repush_jobs_for_timestamp(time_i)
              while job = redis.lpop(timestamp_key(time_i))
                immediate_push(YAML.load(job))
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

        def self.db_time_now
          Time.current
        end
        
        def update_attributes(attrs = {})
          attrs.each{|k,v| send(:"#{k}=", v)}
          save
        end
        
        # Destroy is handled by not writing the job back to the queue
        def destroy
          true
        end
        
        def save
          raise "Double save. Would create duplicate job." if @saved
          self.queue  ||= 'default'
          self.class.push(self)
          @saved = true
          true
        end
        
        def save!; save; end
        
        def fail!
          destroy
        end
           
        def reload
          reset
          self
        end
        
        private
        
          def redis
            self.class.redis
          end
      end
    end
  end
end