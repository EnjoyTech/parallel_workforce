require 'spec_helper'

module ParallelWorkforce::Serializer
  describe Marshal do
    let(:serializer) { described_class.new }

    describe '#serialize' do
      let(:object) { 'an object' }

      subject do
        serializer.serialize(object)
      end

      it 'serializes object' do
        expect(subject).to eq(::Marshal.dump(object))
      end

      context 'with object that cannot be serialized' do
        let(:object) { Hash.new { 'default value' } }

        it 'raises SerializerError' do
          expect { subject }.to raise_error(ParallelWorkforce::SerializerError)
        end
      end
    end

    describe '#deserialize' do
      let(:string) { ::Marshal.dump('an object') }

      subject do
        serializer.deserialize(string)
      end

      it 'serializes object' do
        expect(subject).to eq(::Marshal.load(string))
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
