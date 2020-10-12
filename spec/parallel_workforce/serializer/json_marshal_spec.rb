require 'spec_helper'

module ParallelWorkforce::Serializer
  describe JsonMarshal do
    let(:serializer) { described_class.new }

    describe '#serialize' do
      let(:object) { 'an object' }

      subject do
        serializer.serialize(object)
      end

      it 'serializes object' do
        expect(subject).to eq(JSON.dump('value' => ::Marshal.dump(object)))
      end

      context 'with object that cannot be serialized' do
        let(:object) { Hash.new { 'default value' } }

        it 'raises SerializerError' do
          expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
        end
      end
    end

    describe '#deserialize' do
      let(:value) { 'an object' }
      let(:string) { JSON.dump('value' => ::Marshal.dump(value)) }

      subject do
        serializer.deserialize(string)
      end

      it 'deserializes string' do
        expect(subject).to eq(value)
      end

      context 'with string that cannot be deserialized' do
        let(:string) { 'unserializable' }

        it 'raises SerializerError' do
          expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
        end
      end
    end
  end
end
