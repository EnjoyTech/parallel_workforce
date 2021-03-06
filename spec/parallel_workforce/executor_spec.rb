require 'spec_helper'

module ParallelWorkforce
  describe Executor do
    def serialize(object)
      configuration.serializer.serialize(object)
    end

    class TestJob
      class << self
        def enqueue_actor(actor_class_name:, result_key:, index:, server_revision:, serialized_actor_args:)
          raise NotImplementedError
        end
      end

      def perform(args)
        ParallelWorkforce::Job::Util::Performer.new(**args.symbolize_keys).perform
      end
    end

    class SumActor
      def initialize(arg1:, arg2:)
        @arg1 = arg1
        @arg2 = arg2
      end

      def perform
        @arg1 + @arg2
      end
    end

    let(:server_revision) { "revision-#{rand}" }
    let(:allow_nested_parallelization) { nil }
    let(:execute_serially_parameter) { nil }
    let(:execute_serially_checker) { nil }
    let(:expect_serial_execution) { false }
    let(:serial_execution_indexes) { nil }
    let(:serial_mode_checker) { nil }
    let(:uuid) { "uuid-#{rand(0..1000000)}" }
    let(:result_key) { "#{described_class}:result_key:#{uuid}" }
    let(:actor_class) { SumActor }
    let(:actor_args_array) do
      [
        { arg1: 1, arg2: 2 },
        { arg1: 3, arg2: 4 },
      ]
    end
    let(:sum_array) do
      actor_args_array.map(&:values).map { |array| array.inject(:+) }
    end
    let(:redis_connector) do
      Struct.new(:redis) do
        def with(&block)
          yield(redis)
        end
      end.new(redis)
    end
    let(:revision_builder) do
      Struct.new(:revision).new(server_revision)
    end

    let(:serializer) do
      # use a custom serializer for specs
      Class.new do
        def serialize(object)
          JSON.dump(value: ::Marshal.dump(object))
        rescue
          raise ParallelWorkforce::SerializerError.new
        end

        def deserialize(string)
          Marshal.load(JSON.parse(string)['value'])
        rescue
          raise ParallelWorkforce::SerializerError.new
        end
      end.new
    end
    let(:logger) { Logger.new('/dev/null') }
    let(:job_timeout) { rand(100..200) }
    let(:redis) { Redis.new }
    let(:configuration) { ParallelWorkforce.configuration }
    let(:job_class) { configuration.job_class }
    let(:execution_block) { nil }
    let(:blpop_value) { Marshal.dump(index: 0, serialized_value: serialize('invalid')) }

    before do
      ParallelWorkforce.configure do |configuration|
        configuration.logger = logger
        configuration.redis_connector = redis_connector
        configuration.revision_builder = revision_builder
        configuration.job_timeout = job_timeout
        configuration.serial_mode_checker = serial_mode_checker
        configuration.serializer = serializer
        configuration.job_class = TestJob
        configuration.allow_nested_parallelization = allow_nested_parallelization
      end
    end

    describe '.perform_all' do
      before do
        allow(redis).to receive(:blpop).and_return([result_key, blpop_value])

        allow(job_class).to receive(:enqueue_actor)

        allow(SecureRandom).to receive(:uuid).and_return(uuid)

        Timeout.stub(:timeout) { |&block| block.call }
      end

      subject do
        described_class.new(
          actor_classes: actor_class,
          actor_args_array: actor_args_array,
          serial_execution_indexes: serial_execution_indexes,
          execute_serially: execute_serially_parameter,
          job_class: job_class,
          execution_block: execution_block,
        ).perform_all
      end

      context 'with timeout from Timeout' do
        before do
          allow(Timeout).to receive(:timeout).with(job_timeout).and_raise(Timeout::Error)
        end

        it 'raises TimeoutError with result_values' do
          expect { subject }.to raise_error(an_instance_of(ParallelWorkforce::TimeoutError).and(having_attributes(
            message: "Timeout from ParallelWorkforce job",
            result_values: [nil, nil],
          )))
        end
      end

      context 'with timeout from blpop' do
        let(:blpop_value) { nil }

        it 'raises TimeoutError with result_values' do
          expect { subject }.to raise_error(an_instance_of(ParallelWorkforce::TimeoutError).and(having_attributes(
            message: "Timeout waiting for Redis#blpop",
            result_values: [nil, nil],
          )))
        end
      end

      context "with enqueued actor args" do
        let(:blpop_results) do
          (actor_args_array.reject.with_index do |actor_args, index|
            index.in?(Array.wrap(serial_execution_indexes))
          end).map.with_index do |actor_args, index|
            Marshal.dump(index: index, serialized_value: serialize(actor_args.values.inject(:+)))
          end
        end

        before do
          blpop_results.each.with_index do |blpop_result, index|
            unless expect_serial_execution
              expect(redis).to receive(:blpop).with(
                result_key, job_timeout
              ).and_return([result_key, blpop_result])
            end
          end
        end

        it "enqueues job with actor" do
          actor_args_array.each.with_index do |actor_args, index|
            expect(job_class).to receive(:enqueue_actor).with(
              actor_class_name: actor_class.name,
              result_key: result_key,
              index: index,
              server_revision:  server_revision,
              serialized_actor_args: serialize(actor_args),
            ).and_return(nil)
          end

          subject
        end

        it "sums args" do
          expect(subject).to eq(sum_array)
        end

        context 'with execution block' do
          let(:execution_block) { proc { @execution_block_value = true } }

          it 'evaluates execution block' do
            subject

            expect(@execution_block_value).to eq(true)
          end
        end

        context 'with no logger' do
          let(:logger) { nil }

          it "sums args" do
            expect(subject).to eq(sum_array)
          end
        end

        context 'with no revision builder' do
          let(:revision_builder) { nil }

          it "sums args" do
            expect(subject).to eq(sum_array)
          end
        end

        context 'with actor returning result value that cannot be deserialized' do
          let(:blpop_results) do
            actor_args_array.map.with_index do |actor_args, index|
              Marshal.dump(index: index, serialized_value: 'not deserializable')
            end
          end

          it 'executes the actor serially and returns correct result' do
            subject

            expect(subject).to eq(sum_array)
          end
        end

        context 'with serial_execution_indexes specified' do
          context 'with invalid index' do
            let(:serial_execution_indexes) { [actor_args_array.length] }
            let(:blpop_results) { [] }

            it 'raises argument error' do
              expect { subject }.to raise_error(ArgumentError)
            end
          end

          {
            no_indexes: [],
            first_index: [0],
            last_index: [1],
            all_indexes: [0, 1],
            reverse_order_indexes: [1, 0],
          }.each do |name, indexes|
            context "with valid #{name}" do
              let(:serial_execution_indexes) { indexes }

              it "sums args both in parallel and serially" do
                expect(subject).to eq(sum_array)
              end
            end
          end
        end

        context "with serial execution parameter true" do
          let(:execute_serially_parameter) { true }
          let(:expect_serial_execution) { true }

          it "sums args" do
            expect(subject).to eq(sum_array)
          end

          context "with unserializable actor args array" do
            let(:actor_args_array) { [Hash.new { 'value' }] } # Hash with default proc can't be with Marshal serializer

            it 'raises ParallelWorkforce::SerializerError since actor arguments cannot be serialized' do
              expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
            end
          end
        end

        context "when in parallel_workforce_thread" do
          before do
            allow(ParallelWorkforce::Job::Util::Performer).to receive(:parallel_workforce_thread?).and_return(true)
          end

          context 'with allow_nested_parallelization true' do
            let(:allow_nested_parallelization) { true }
            let(:expect_serial_execution) { false }

            it "sums args in parallel" do
              expect(subject).to eq(sum_array)
            end
          end

          context 'with allow_nested_parallelization false' do
            let(:allow_nested_parallelization) { false }
            let(:expect_serial_execution) { true }

            it "sums args serially" do
              expect(subject).to eq(sum_array)
            end
          end
        end

        context "with serial execution checker true" do
          let(:serial_mode_checker) do
            Struct.new(:execute_serially) do
              def execute_serially?
                execute_serially
              end
            end.new(execute_serially_checker)
          end
          let(:execute_serially_checker) { true }
          let(:expect_serial_execution) { true }

          it "sums args" do
            expect(subject).to eq(sum_array)
          end

          context 'with execution block' do
            let(:execution_block) { proc { @execution_block_value = true } }

            it 'evaluates execution block' do
              subject

              expect(@execution_block_value).to eq(true)
            end
          end
        end

        context "with job error" do
          let(:error) { "An error has occurred in job!!!" }

          let(:blpop_results) do
            [
              Marshal.dump(index: 0, error: error),
            ]
          end

          it "raises argument error" do
            expect { subject }.to raise_error(
              ParallelWorkforce::ActorPerformError, "Error received from parallel actor: #{error}"
            )
          end
        end

        context "with revision mismatch" do
          let(:blpop_results) do
            actor_args_array.map.with_index do |actor_args, index|
              Marshal.dump(
                index: index,
                error_revision: 'some other revision',
              )
            end
          end

          it "executes serially and sums args" do
            expect(subject).to eq(sum_array)
          end
        end

        context "with job unable to deserialize serialized_actor_args" do
          let(:blpop_results) do
            actor_args_array.map.with_index do |actor_args, index|
              Marshal.dump(
                index: index,
                revision_mismatch: server_revision,
              )
            end
          end

          it "executes serially and sums args" do
            expect(subject).to eq(sum_array)
          end
        end
      end
    end
  end
end
