module ParallelWorkforce
  module Job
    class Sidekiq
      include ::Sidekiq::Worker
      include ParallelWorkforce::Job::Util::JobHelper

      sidekiq_options retry: false

      class << self
        def enqueue_actor(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          enqueue_actor_job(
            :perform_async,
            actor_class_name: actor_class_name,
            result_key: result_key,
            index: index,
            server_revision: server_revision,
            serialized_actor_args: serialized_actor_args,
          )
        end
      end

      def perform(args)
        invoke_performer(args)
      end
    end
  end
end
