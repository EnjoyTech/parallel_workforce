require 'spec_helper'

module ParallelWorkforce::RedisConnector
  describe RedisPool do
    let(:redis_connector) { described_class.new }

    describe '#with' do
      let(:return_value) { 'a return value' }

      subject do
        redis_connector.with { |redis| return_value }
      end

      it 'returns block value' do
        expect(subject).to eq(return_value)
      end

      context 'with same thread' do
        it 'uses the same connection' do
          first_redis = nil
          redis_connector.with { |redis| first_redis = redis }

          second_redis = nil
          redis_connector.with { |redis| second_redis = redis }

          expect(first_redis).to eq(second_redis)
        end
      end

      context 'with different threads' do
        it 'uses the different connection' do
          first_redis_object_id = nil
          redis_connector.with { |redis| first_redis_object_id = redis.object_id }

          second_redis_object_id = nil
          Thread.new do
            redis_connector.with { |redis| second_redis_object_id = redis.object_id }
          end.join

          expect(first_redis_object_id).not_to eq(second_redis_object_id)
        end
      end
    end
  end
end
