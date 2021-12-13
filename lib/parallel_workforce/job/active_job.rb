module ParallelWorkforce
  module Job
    class ActiveJob < ::ActiveJob::Base
      include ParallelWorkforce::Job::Util::JobHelper

      discard_on Exception if defined?(discard_on)

      class << self
        def enqueue_actor(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          enqueue_actor_job(
            :perform_later,
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
