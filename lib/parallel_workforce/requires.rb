require "yajl"
require_relative "version"
require_relative "executor"
require_relative "configuration"
require_relative "job/util/performer"
require_relative "redis_connector/redis_pool"
require_relative "revision_builder/files_hash"
require_relative "serializer/marshal"
require_relative "serializer/json"
require_relative "serializer/yajl"

# rubocop:disable Lint/HandleExceptions
begin
  require 'active_job'
rescue LoadError
end
begin
  require 'rails'
rescue LoadError
end
begin
  require 'sidekiq'
rescue LoadError
end
# rubocop:enable Lint/HandleExceptions

if defined?(::ActiveJob)
  require_relative 'job/active_job'
  if defined?(::Rails)
    require_relative 'job/active_job_rails'
  end
end

if defined?(::Sidekiq)
  require_relative 'redis_connector/sidekiq_redis_pool'
  require_relative 'job/sidekiq'
  if defined?(::Rails)
    require_relative 'job/sidekiq_rails'
  end
end
