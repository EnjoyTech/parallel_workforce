require 'spec_helper'

module ParallelWorkforce::Serializer
  describe Json do
    include_context 'shared_context_data'
    let(:serializer) { described_class.new }

    describe '#serialize' do
      let(:object) { value }

      subject do
        serializer.serialize(object)
      end

      it 'serializes object' do
        expect(subject).to eq(::JSON.dump(object))
      end

      context 'with object that cannot be serialized' do
        let(:object) { ::Marshal.dump(value) }

        it 'raises SerializerError' do
          expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
        end
      end
    end

    describe '#deserialize' do
      let(:string) { ::JSON.dump(value) }

      subject do
        serializer.deserialize(string)
      end

      it 'serializes object' do
        expect(subject).to eq(::JSON.parse(string,{:symbolize_names => true}))
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
