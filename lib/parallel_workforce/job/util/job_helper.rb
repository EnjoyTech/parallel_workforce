module ParallelWorkforce
  module Job
    module Util
      module JobHelper
        def self.included(klass)
          klass.extend(ClassMethods)
        end

        module ClassMethods
          def build_serialized_actor_args_key(result_key, index)
            "#{result_key}:#{index}:serialized-actor-args"
          end

          def enqueue_actor_job(enqueue_method, **kwargs)
            serialized_actor_args = kwargs.delete(:serialized_actor_args)

            ::ParallelWorkforce.configuration.redis_connector.with do |redis|
              redis.setex(
                build_serialized_actor_args_key(kwargs[:result_key], kwargs[:index]),
                ::ParallelWorkforce.configuration.job_key_expiration,
                serialized_actor_args,
              )
            end

            send(
              enqueue_method,
              **kwargs,
            )
          end
        end

        def invoke_performer(args)
          args.transform_keys!(&:to_sym)

          serialized_actor_args = ParallelWorkforce.configuration.redis_connector.with do |redis|
            serialized_actor_args_key = self.class.build_serialized_actor_args_key(args[:result_key], args[:index])

            redis.getset(serialized_actor_args_key, nil).tap do
              redis.del(serialized_actor_args_key)
            end
          end

          raise "Unable to locate serialized data required for Performer" if serialized_actor_args.nil?

          args[:serialized_actor_args] = serialized_actor_args

          ParallelWorkforce::Job::Util::Performer.new(**args).perform
        end

        def invoke_performer_with_time_zone_name_and_locale(args)
          args.transform_keys!(&:to_sym)

          Time.use_zone(args.delete(:time_zone_name)) do
            I18n.with_locale(args.delete(:locale)) do
              invoke_performer(args)
            end
          end
        end
      end
    end
  end
end
