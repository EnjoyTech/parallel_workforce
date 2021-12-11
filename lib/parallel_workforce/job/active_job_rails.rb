module ParallelWorkforce
  module Job
    class ActiveJobRails < ParallelWorkforce::Job::ActiveJob
      class << self
        def enqueue_actor(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          enqueue_actor_job(
            :perform_later,
            actor_class_name: actor_class_name,
            result_key: result_key,
            index: index,
            server_revision: server_revision,
            serialized_actor_args: serialized_actor_args,
            time_zone_name: Time.zone.name,
          )
        end
      end

      def perform(args)
        invoke_performer_with_time_zone_name(args)
      end
    end
  end
end
