require_relative 'parallel_workforce/requires'

module ParallelWorkforce
  Error = Class.new(StandardError)
  ActorPerformError = Class.new(Error)
  ActorNotFoundError = Class.new(Error)
  TimeoutError = Class.new(Error)
  SerializerError = Class.new(Error)

  class << self
    # +actor_classes+: a single class or array of classes that have a perform method and can be initialized with no args.
    # If an array is passed, the array size must batch the action_args_array size.
    # Return results array with element from each action in the order of the job_args_array
    # rubocop:disable Metrics/ParameterLists
    def perform_all(actor_classes:, actor_args_array:,
        serial_execution_indexes: nil, execute_serially: nil, job_class: nil, &execution_block)
      ParallelWorkforce::Executor.new(
        actor_classes: actor_classes,
        actor_args_array: actor_args_array,
        execute_serially: execute_serially,
        serial_execution_indexes: serial_execution_indexes,
        job_class: job_class,
        execution_block: execution_block,
      ).perform_all
    end
    # rubocop:enable Metrics/ParameterLists

    def configuration
      @configuration ||= Configuration.new
    end

    def configure(&block)
      yield(configuration)
    end

    def log(level, *messages)
      return if configuration.logger.nil?

      messages.each do |message|
        configuration.logger.send(level, message)
      end

      nil
    end
  end
end
