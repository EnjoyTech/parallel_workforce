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
      end
    end
  end
end
