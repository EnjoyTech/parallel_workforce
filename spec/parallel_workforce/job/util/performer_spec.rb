require 'spec_helper'

module ParallelWorkforce::Job::Util
  describe Performer do
    def serialize(object)
      ParallelWorkforce.configuration.serializer.serialize(object)
    end

    class IncrementActor
      def initialize(arg:)
        @arg = arg
      end

      def perform
        @arg += 1
      end
    end
    let(:actor_class_name) { IncrementActor.name }
    let(:result_key) { "result_key:#{rand(0..100)}" }
    let(:worker_revision) { "revision:#{rand(0..100)}" }
    let(:revision_builder) do
      Struct.new(:revision).new(worker_revision)
    end
    let(:server_revision) { worker_revision }
    let(:index) { rand(0..10) }
    let(:value) { rand(0..10) }
    let(:actor_args) { { arg: value } }
    let(:serialized_actor_args) { serialize(actor_args) }
    let(:args) do
      {
        actor_class_name: actor_class_name,
        result_key: result_key,
        index: index,
        server_revision: server_revision,
        serialized_actor_args: serialized_actor_args,
      }
    end
    let(:performer) { described_class.new(args) }

    before do
      ParallelWorkforce.configure do |configuration|
        configuration.revision_builder = revision_builder
      end
    end

    describe '#perform' do
      subject do
        performer.perform
      end

      it "executes and serializes value" do
        expect(subject).to eq(serialized_value: serialize(value + 1))
      end

      context 'with parallel_workforce_thread' do
        class ParallelWorkforceThreadActor
          def perform
            Thread.current[:parallel_workforce_thread]
          end
        end
        let(:actor_class_name) { ParallelWorkforceThreadActor.name }
        let(:actor_args) { {} }

        it "sets parallel_workforce_thread thread local variable to true" do
          expect(subject).to eq(serialized_value: serialize(true))
        end
      end

      context 'with different server revision' do
        let(:server_revision) { "different_revision" }

        it "returns revision_mismatch" do
          expect(subject).to eq(error_revision: worker_revision)
        end
      end

      context 'with data that connot be deserialized' do
        let(:serialized_actor_args) { "incorrect serialization format" }

        it "returns revision_mismatch" do
          expect(subject).to eq(error_revision: worker_revision)
        end
      end

      context "with standard error raised" do
        TestStandardError = Class.new(StandardError)
        class StandardErrorActor < IncrementActor
          def perform
            raise TestStandardError.new('test error')
          end
        end
        let(:actor_class_name) { StandardErrorActor.name }

        it "returns error response" do
          expect(subject).to eq(error: "Error in actor perform. #{TestStandardError.name} test error")
        end
      end

      context "with exception raised" do
        TestException = Class.new(Exception)
        class ExceptionActor < IncrementActor
          def perform
            raise TestException.new('test exception')
          end
        end
        let(:actor_class_name) { ExceptionActor.name }

        it "returns error response" do
          expect(subject).to eq(error: "Unhandled exception. #{TestException.name} test exception")
        end
      end
    end
  end
end
