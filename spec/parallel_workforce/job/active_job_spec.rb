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
      it_behaves_like 'enqueue_actor', :perform_later
    end

    describe '#perform' do
      it_behaves_like 'perform', :perform_later
    end
  end
end
