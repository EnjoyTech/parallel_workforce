module ParallelWorkforce
  module RedisConnector
    class SidekiqRedisPool
      def with(&block)
        Sidekiq.redis_pool.with do |redis|
          yield(redis)
        end
      end
    end
  end
end
