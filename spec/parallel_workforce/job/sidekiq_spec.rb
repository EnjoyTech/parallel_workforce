require 'spec_helper'

module ParallelWorkforce::Job
  describe Sidekiq do
    class SidekiqTestActor
      def initialize(value:)
        @value = value
      end

      def perform
        @value
      end
    end

    let(:value) { 'a value' }
    let(:actor_class) { SidekiqTestActor }
    let(:actor_class_name) { actor_class.name }
    let(:actor) { actor_class.new(value: value) }
    let(:result_key) { 'result_key' }
    let(:index) { 0 }
    let(:server_revision) { nil }
    let(:serialized_actor_args) { ParallelWorkforce.configuration.serializer.serialize(value: value) }
    let(:serializer) { nil }
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
        configuration.serializer = serializer if serializer
      end
    end

    shared_context 'with Marshal serializer and invalid UTF-8 sequence' do
      let(:serializer) { ParallelWorkforce::Serializer::Marshal.new }
      let(:value) { "a value with invalid UTF-8 sequence: \x97" }
    end

    describe '.enqueue_actor' do
      it_behaves_like 'enqueue_actor', :perform_async

      context 'with Marshal serializer and invalid UTF-8 sequence' do
        include_context 'with Marshal serializer and invalid UTF-8 sequence'

        it_behaves_like 'enqueue_actor', :perform_async
      end
    end

    describe '#perform' do
      include_examples 'perform', :perform_async

      context 'with Marshal serializer and invalid UTF-8 sequence' do
        include_context 'with Marshal serializer and invalid UTF-8 sequence'

        include_examples 'perform', :perform_async
      end
    end
  end
end
