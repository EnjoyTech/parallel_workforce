module ParallelWorkforce
  module Job
    class SidekiqRails < ParallelWorkforce::Job::Sidekiq
      class << self
        def enqueue_actor(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          perform_async(
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
        args.symbolize_keys!
        Time.use_zone(args.delete(:time_zone_name)) do
          ParallelWorkforce::Job::Util::Performer.new(**args).perform
        end
      end
    end
  end
end
