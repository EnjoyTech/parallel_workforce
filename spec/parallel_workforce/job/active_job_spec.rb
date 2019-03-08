require 'spec_helper'

module ParallelWorkforce::Job
  describe ActiveJob do
    class ActiveJobTestActor
      def initialize(value:)
        @value = value
      end

      def perform
        @value
      end
    end

    let(:value) { 'a value' }
    let(:actor_class) { ActiveJobTestActor }
    let(:actor_class_name) { actor_class.name }
    let(:actor) { actor_class.new(value: value) }
    let(:result_key) { 'result_key' }
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
        described_class.enqueue_actor(args)
      end

      it 'enqueues job' do
        expect(described_class).to receive(:perform_later).with(
          actor_class_name: actor_class_name,
          result_key: result_key,
          index: index,
          server_revision: server_revision,
          serialized_actor_args: serialized_actor_args,
        ).and_call_original

        subject
      end
    end

    describe '#perform' do
      subject do
        described_class.new.perform(args)
      end

      it 'performs actor' do
        expect(subject).to eq(serialized_value: ParallelWorkforce.configuration.serializer.serialize(value))
      end
    end
  end
end
