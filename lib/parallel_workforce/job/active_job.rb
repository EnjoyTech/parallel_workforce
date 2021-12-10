module ParallelWorkforce
  module Job
    class ActiveJob < ::ActiveJob::Base
      discard_on Exception if defined?(discard_on)

      class << self
        def enqueue_actor(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          perform_later(
            actor_class_name: actor_class_name,
            result_key: result_key,
            index: index,
            server_revision: server_revision,
            serialized_actor_args: serialized_actor_args,
          )
        end
      end

      def perform(args)
        ParallelWorkforce::Job::Util::Performer.new(**args.symbolize_keys).perform
      end
    end
  end
end
