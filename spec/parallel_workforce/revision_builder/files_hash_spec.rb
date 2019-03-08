require 'spec_helper'

module ParallelWorkforce::RevisionBuilder
  describe FilesHash do
    describe '#revision' do
      let(:files) { Dir["#{File.expand_path('../..', __dir__)}/**/*.rb"][0..1] }
      let(:revision_builder) { described_class.new(files) }

      subject do
        revision_builder.revision
      end

      it 'calculates same digest with files in different sort order' do
        expect(subject).to eq(described_class.new(files.reverse).revision)
      end
    end
  end
end
