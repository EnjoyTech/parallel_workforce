module ParallelWorkforce
  module Job
    module Util
      class Performer
        attr_reader(
          :actor_class_name,
          :result_key,
          :index,
          :server_revision,
          :serialized_actor_args,
        )

        class << self
          def perform(actor_class, actor_args)
            actor_args = actor_args.each_with_object({}) { |(k, v), result| result[k.to_sym] = v }

            (actor_args.empty? ? actor_class.new : actor_class.new(**actor_args)).perform
          end

          def parallel_workforce_thread?
            !!Thread.current[:parallel_workforce_thread]
          end
        end

        def initialize(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          @actor_class_name = actor_class_name
          @result_key = result_key
          @index = index
          @server_revision = server_revision
          @serialized_actor_args = serialized_actor_args
        end

        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        def perform
          result = {}

          if server_revision == worker_revision
            begin
              result[:serialized_value] = serialize(perform_actor)
            rescue ParallelWorkforce::Error => e
              warn("#{self.class}: Actor revision error: #{e}")
              result[:error_revision] = worker_revision
            rescue => e
              warn("#{self.class}: Error in actor perform: #{e}", *e.backtrace)
              result[:error] = "Error in actor perform. #{e.class} #{e.message}"
            end
          else
            warn("#{self.class}: Revision mismatch from caller")
            result[:error_revision] = worker_revision
          end

          result
        rescue Exception => exception
          result = handle_exception(exception)
        ensure
          ParallelWorkforce.configuration.redis_connector.with do |redis|
            # always publish a message result to avoid a Timeout in subscriber
            # NOTE: always using Ruby marshaling to store in Redis, not serializer
            redis.rpush(result_key, Marshal.dump(result.merge(index: index)))
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        private

        def perform_actor
          actor_class = begin
            Object.const_get(actor_class_name)
          rescue NameError
            raise ParallelWorkforce::SerializerError.new("Unable to locate actor class: #{actor_class_name}")
          end

          in_parallel_workforce_thread do
            self.class.perform(actor_class, deserialize(serialized_actor_args))
          end
        end

        def in_parallel_workforce_thread(&block)
          original_parallel_workforce_thread = Thread.current[:parallel_workforce_thread]

          Thread.current[:parallel_workforce_thread] = true
          yield
        ensure
          Thread.current[:parallel_workforce_thread] = original_parallel_workforce_thread
        end

        def serialize(object)
          ParallelWorkforce.configuration.serializer.serialize(object)
        end

        def deserialize(string)
          ParallelWorkforce.configuration.serializer.deserialize(string)
        end

        def worker_revision
          ParallelWorkforce.configuration.revision_builder&.revision
        end

        def warn(*messages)
          ParallelWorkforce.log(:warn, *messages)
        end

        def error(*messages)
          ParallelWorkforce.log(:error, *messages)
        end

        def handle_exception(exception)
          # swallow exceptions, no need to retry
          error("#{self.class}: #{exception}", *exception.backtrace)

          {
            error: "Unhandled exception. #{exception.class} #{exception.message}",
          }
        end
      end
    end
  end
end
