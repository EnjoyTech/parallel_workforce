require 'spec_helper'

module ParallelWorkforce::Serializer
  describe Yajl do
    include_context 'shared_context_data'
    let(:serializer) { described_class.new }

    describe '#serialize' do
      let(:object) { value }

      subject do
        serializer.serialize(object)
      end

      it 'serializes object' do
        expect(subject).to eq( ::Yajl::Encoder.encode(object))
      end

      context 'with object that cannot be serialized' do
        let(:object) { {a: 0.0/0.0} }  # Yajl cannot serialize 0/0 value

        it 'raises SerializerError' do
          expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
        end
      end
    end

    describe '#deserialize' do
      let(:string) {  ::Yajl::Encoder.encode(value) }

      subject do
        serializer.deserialize(string)
      end

      it 'serializes object' do
        expect(subject).to eq(::Yajl::Parser.parse(string, {:symbolize_names => true}))
      end

      context 'with string that cannot be unparsed/deserialized' do
        let(:string) { 'unparsable' }

        it 'raises SerializerError' do
          expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
        end
      end
    end
  end
end
