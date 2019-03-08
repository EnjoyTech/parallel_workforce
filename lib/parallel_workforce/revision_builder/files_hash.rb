module ParallelWorkforce
  module RevisionBuilder
    class FilesHash
      attr_reader :revision

      def initialize(files=Dir["#{File.expand_path('.')}/**/*.rb"])
        @revision = build_revision(files).freeze
      end

      protected

      def build_revision(files)
        Digest::MD5.new.tap do |digest|
          files.sort.each { |file| digest << File.read(file) }
        end.hexdigest
      end
    end
  end
end
