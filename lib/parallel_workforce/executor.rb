require 'securerandom'

module ParallelWorkforce
  # rubocop:disable Metrics/ClassLength
  class Executor
    attr_reader(
      :actor_classes,
      :actor_args_array,
      :execute_serially,
      :job_class,
      :execution_block,
    )

    # +actor_classes+: a single class or array of classes that can be instantiated with no args and have a `perform` method.
    # If an array is passed, the array size must batch the actor_args_array size.
    # Return results array with element from each actor in the order of the actor_args_array
    def initialize(actor_classes:, actor_args_array:, execute_serially: nil, job_class: nil, execution_block: nil)
      @actor_classes = normalize_actor_classes!(actor_classes, actor_args_array)
      @actor_args_array = actor_args_array
      @execute_serially = execute_serially.nil? ?
        ParallelWorkforce.configuration.serial_mode_checker&.execute_serially? :
        execute_serially
      @job_class = job_class || ParallelWorkforce.configuration.job_class
      @execution_block = execution_block
    end

    def perform_all
      if execute_serially
        execute_actors_serially(actor_classes, actor_args_array)
      else
        execute_actors_parallel(actor_classes, actor_args_array)
      end
    end

    private

    def serialize(object)
      ParallelWorkforce.configuration.serializer.serialize(object)
    end

    def deserialize(string)
      ParallelWorkforce.configuration.serializer.deserialize(string)
    end

    def serialize_and_deserialize(object)
      deserialize(serialize(object))
    end

    def normalize_actor_classes!(actor_classes, actor_args_array)
      actor_classes = actor_classes.is_a?(Array) ? actor_classes : Array.new(actor_args_array.length) { actor_classes }

      if actor_classes.length != actor_args_array.length
        raise ArgumentError.new("actor_classes and actor_args_array must be same length")
      end

      actor_classes
    end

    def execute_actors_parallel(actor_classes, actor_args_array)
      result_key = "ParallelWorkforce::Executor:result_key:#{SecureRandom.uuid}"

      result = []

      actor_classes.zip(actor_args_array).each.with_index do |(actor_class, actor_args), index|
        enqueue_actor(actor_class, actor_args, index, result_key)
      end

      ParallelWorkforce.configuration.redis_connector.with do |redis|
        redis.expire(result_key, ParallelWorkforce.configuration.job_key_expiration)
      end

      execution_block&.call

      # concat results from enqueued actors
      result.concat(wait_for_actor_results(result_key, actor_classes, actor_args_array))

      result
    ensure
      ParallelWorkforce.configuration.redis_connector.with do |redis|
        redis.del(result_key) if result_key
      end
    end

    def execute_actors_serially(actor_classes, actor_args_array)
      execution_block&.call

      actor_classes.zip(actor_args_array).collect do |actor_class, actor_args|
        execute_actor_serially(actor_class, actor_args)
      end
    end

    def execute_actor_serially(actor_class, actor_args)
      # Mimic serialization behavior in parallel actor execution
      serialize_and_deserialize(
        ParallelWorkforce::Job::Util::Performer.perform(
          actor_class,
          serialize_and_deserialize(actor_args),
        ),
      )
    end

    def enqueue_actor(actor_class, actor_args, index, result_key)
      job_class.enqueue_actor(
        actor_class_name: actor_class.name,
        result_key: result_key,
        index: index,
        server_revision:  ParallelWorkforce.configuration.revision_builder&.revision,
        serialized_actor_args: serialize(actor_args),
      )
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def wait_for_actor_results(result_key, actor_classes, actor_args_array)
      return [] if (num_results = actor_classes.length) == 0

      result_values = Array.new(num_results)
      result_count = 0

      ParallelWorkforce.configuration.redis_connector.with do |redis|
        begin
          Timeout.timeout(ParallelWorkforce.configuration.job_timeout) do
            until result_count == num_results
              _key, response = redis.blpop(result_key, ParallelWorkforce.configuration.job_timeout)
              raise ParallelWorkforce::TimeoutError.new("Timeout waiting for Redis#blpop") if response.nil?

              result_count += 1

              index, value = parse_response!(response, actor_classes, actor_args_array)

              result_values[index] = value
            end
          end
        rescue Timeout::Error
          raise ParallelWorkforce::TimeoutError.new("Timeout from ParallelWorkforce job")
        end
      end

      result_values
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def parse_response!(response, actor_classes, actor_args_array)
      # NOTE: Always stored in Redis with Ruby marshaling, not serializer
      message = Marshal.load(response)
      if (error = message[:error])
        raise ParallelWorkforce::ActorPerformError.new("Error received from parallel actor: #{error}")
      elsif message[:error_revision]
        # recoverable error
        index = message[:index]
        [index, execute_actor_serially(actor_classes[index], actor_args_array[index])]
      else
        begin
          [message[:index], deserialize(message[:serialized_value])]
        rescue ParallelWorkforce::SerializerError => e
          ParallelWorkforce.log(:warn, "Cannot deserialize serialized_value: #{e}")

          index = message[:index]
          [index, execute_actor_serially(actor_classes[index], actor_args_array[index])]
        end
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
