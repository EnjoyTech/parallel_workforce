module ParallelWorkforce
  module Job
    module Util
      module JobHelper
        def self.included(klass)
          klass.extend(ClassMethods)
        end

        module ClassMethods
          def enqueue_actor_job(enqueue_method, **kwargs)
            send(
              enqueue_method,
              **kwargs,
            )
          end
        end

        def invoke_performer(args)
          args.transform_keys!(&:to_sym)

          ParallelWorkforce::Job::Util::Performer.new(**args).perform
        end

        def invoke_performer_with_time_zone_name(args)
          args.transform_keys!(&:to_sym)

          Time.use_zone(args.delete(:time_zone_name)) do
            invoke_performer(args)
          end
        end
      end
    end
  end
end
