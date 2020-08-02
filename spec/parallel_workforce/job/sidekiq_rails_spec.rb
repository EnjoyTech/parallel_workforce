require 'spec_helper'

module ParallelWorkforce::Job
  describe SidekiqRails do
    include_context 'shared_context_data'
    class SidekiqRailsTestActor
      def initialize(value:)
        @value = value
      end

      def perform
        {
          time_zone_name: Time.zone.name,
          value: @value,
        }
      end
    end

    let(:time_zone_name) { 'Pacific Time (US & Canada)' }
    let(:actor_class) { SidekiqRailsTestActor }
    let(:actor_class_name) { actor_class.name }
    let(:actor) { actor_class.new(value: value) }
    let(:index) { 0 }
    let(:server_revision) { nil }
    let(:serialized_actor_args) { ParallelWorkforce.configuration.serializer.serialize(value: value) }
    let(:args) do
      {
        actor_class_name: actor_class_name,
        result_key: result_key,
        index: index,
        server_revision: server_revision,
        serialized_actor_args: serialized_actor_args,
      }
    end

    before do
      ParallelWorkforce.configure do |configuration|
        configuration.revision_builder = nil
      end
    end

    describe '.enqueue_actor' do
      subject do
        Time.use_zone(time_zone_name) do
          described_class.enqueue_actor(args)
        end
      end

      it 'enqueues job' do
        expect(described_class).to receive(:perform_async).with(
          actor_class_name: actor_class_name,
          result_key: result_key,
          index: index,
          server_revision: server_revision,
          serialized_actor_args: serialized_actor_args,
          time_zone_name: time_zone_name,
        ).and_call_original

        subject
      end
    end

    describe '#perform' do
      let(:perform_args) do
        args.merge("time_zone_name" => time_zone_name).stringify_keys!
      end

      subject do
        described_class.new.perform(perform_args)
      end

      it 'performs actor' do
        expect(subject).to eq(
          serialized_value: ParallelWorkforce.configuration.serializer.serialize(
            time_zone_name: time_zone_name,
            value: value,
          ),
        )
      end
    end
  end
end
