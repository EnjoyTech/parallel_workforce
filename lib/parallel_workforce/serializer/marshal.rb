module ParallelWorkforce
  module Serializer
    class Marshal
      def serialize(object)
        ::Marshal.dump(object)
      rescue TypeError => e
        ParallelWorkforce.log(:error, "#{self.class}: Unable to serialize object: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to serialize object: #{e}")
      end

      def deserialize(string)
        ::Marshal.load(string)
      rescue TypeError => e
        ParallelWorkforce.log(:warn, "#{self.class}: Unable to deserialize string: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to deserialize string: #{e}")
      end
    end
  end
end
