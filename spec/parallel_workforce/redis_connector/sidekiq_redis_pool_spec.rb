require 'spec_helper'

module ParallelWorkforce::RedisConnector
  describe SidekiqRedisPool do
    let(:redis_connector) { described_class.new }

    describe '#with' do
      let(:return_value) { 'a return value' }

      subject do
        redis_connector.with { |redis| return_value }
      end

      it 'returns block value' do
        expect(subject).to eq(return_value)
      end

      it 'uses the sidekiq redis pool' do
        redis_connector_redis = nil
        redis_connector.with { |redis| redis_connector_redis = redis }

        sidekiq_pool_redis = nil
        Sidekiq.redis_pool.with { |redis| sidekiq_pool_redis = redis }

        expect(redis_connector_redis).to eq(sidekiq_pool_redis)
      end
    end
  end
end
