require 'securerandom'

module ParallelWorkforce
  # rubocop:disable Metrics/ClassLength
  class Executor
    attr_reader(
      :actor_classes,
      :actor_args_array,
      :execute_serially,
      :serial_execution_indexes,
      :job_class,
      :allow_partial_result,
      :execution_block,
    )

    # +actor_classes+: a single class or array of classes that can be instantiated with no args and have a `perform` method.
    # If an array is passed, the array size must batch the actor_args_array size.
    # Return results array with element from each actor in the order of the actor_args_array
    # rubocop:disable Metrics/ParameterLists
    def initialize(actor_classes:, actor_args_array:,
        serial_execution_indexes: nil, execute_serially: nil, job_class: nil, allow_partial_result: nil, execution_block: nil)
      @actor_classes = normalize_actor_classes!(actor_classes, actor_args_array)
      @actor_args_array = actor_args_array
      @serial_execution_indexes = serial_execution_indexes
      @execute_serially = execute_serially.nil? ? calculate_execute_serially : execute_serially
      @job_class = job_class || configuration.job_class
      @allow_partial_result = allow_partial_result || configuration.allow_partial_result
      @execution_block = execution_block
    end
    # rubocop:enable Metrics/ParameterLists

    def perform_all
      serial_execution_indexes = calculate_serial_execution_indexes
      serial_actor_classes, serial_actor_args_array, parallel_actor_classes, parallel_actor_args_array =
        split_serial_parallel(serial_execution_indexes, actor_classes, actor_args_array)

      serial_results = nil
      parallel_results = execute_actors(parallel_actor_classes, parallel_actor_args_array) do
        serial_results = serial_actor_classes.zip(serial_actor_args_array).collect do |actor_class, actor_args|
          execute_actor_serially(actor_class, actor_args)
        end
      end

      Array.new(actor_args_array.length) do |index|
        if index == serial_execution_indexes.first
          serial_execution_indexes.shift
          serial_results.shift
        else
          parallel_results.shift
        end
      end
    end

    private

    def split_serial_parallel(serial_execution_indexes, actor_classes, actor_args_array)
      serial_execution_indexes = serial_execution_indexes.dup

      [[], [], [], []].tap do |result|
        actor_classes.zip(actor_args_array).each_with_index do |(actor_class, actor_args), index|
          if index == serial_execution_indexes.first
            serial_execution_indexes.shift
            result[0] << actor_class
            result[1] << actor_args
          else
            result[2] << actor_class
            result[3] << actor_args
          end
        end
      end
    end

    def calculate_serial_execution_indexes
      if execute_serially
        actor_args_array.length.times.to_a
      elsif serial_execution_indexes
        serial_execution_indexes.sort.each do |index|
          if index < 0 || index >= actor_args_array.size
            raise ArgumentError.new("serial_execution_indexes must be between 0 and #{actor_args_array.size}")
          end
        end
      else
        []
      end
    end

    def configuration
      ParallelWorkforce.configuration
    end

    def calculate_execute_serially
      if ParallelWorkforce::Job::Util::Performer.parallel_workforce_thread? && !configuration.allow_nested_parallelization
        return true
      end

      configuration.serial_mode_checker&.execute_serially?
    end

    def serialize(object)
      configuration.serializer.serialize(object)
    end

    def deserialize(string)
      configuration.serializer.deserialize(string)
    end

    def serialize_and_deserialize(object)
      return object if configuration.production_environment

      deserialize(serialize(object))
    end

    def normalize_actor_classes!(actor_classes, actor_args_array)
      actor_classes = actor_classes.is_a?(Array) ? actor_classes : Array.new(actor_args_array.length) { actor_classes }

      if actor_classes.length != actor_args_array.length
        raise ArgumentError.new("actor_classes and actor_args_array must be same length")
      end

      actor_classes
    end

    # rubocop:disable Metrics/AbcSize
    def execute_actors(actor_classes, actor_args_array, &execute_actors_serially_proc)
      result_key = "ParallelWorkforce::Executor:result_key:#{SecureRandom.uuid}"

      result = []

      actor_classes.zip(actor_args_array).each.with_index do |(actor_class, actor_args), index|
        enqueue_actor(actor_class, actor_args, index, result_key)
      end

      configuration.redis_connector.with do |redis|
        redis.expire(result_key, configuration.job_key_expiration)
      end

      execute_actors_serially_proc.call

      execution_block&.call

      # concat results from enqueued actors
      result.concat(wait_for_actor_results(result_key, actor_classes, actor_args_array))

      result
    ensure
      configuration.redis_connector.with do |redis|
        redis.del(result_key) if result_key
      end
    end
    # rubocop:enable Metrics/AbcSize

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
        server_revision:  configuration.revision_builder&.revision,
        serialized_actor_args: serialize(actor_args),
      )
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def wait_for_actor_results(result_key, actor_classes, actor_args_array)
      return [] if (num_results = actor_classes.length) == 0

      result_values = Array.new(num_results)
      result_count = 0

      configuration.redis_connector.with do |redis|
        begin
          Timeout.timeout(configuration.job_timeout) do
            until result_count == num_results
              _key, response = redis.blpop(result_key, configuration.job_timeout)
              raise ParallelWorkforce::TimeoutError.new("Timeout waiting for Redis#blpop") if response.nil?

              result_count += 1

              index, value = parse_response!(response, actor_classes, actor_args_array)

              result_values[index] = value
            end
          end
        rescue Timeout::Error
          if allow_partial_result == true
            return result_values.reject(&:nil?)
          else
            raise ParallelWorkforce::TimeoutError.new("Timeout from ParallelWorkforce job")
          end
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
