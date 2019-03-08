module ParallelWorkforce
  module RedisConnector
    class RedisPool
      def with(&block)
        redis = (Thread.current["#{self.class.name}:redis_connection"] ||= Redis.new)

        yield(redis)
      end
    end
  end
end
