module ParallelWorkforce
  module Serializer
    class Yajl
      def serialize(object)
        ::Yajl::Encoder.encode(object)
      rescue TypeError,::Yajl::EncodeError,::Yajl::ParseError,::Encoding::UndefinedConversionError => e
        ParallelWorkforce.log(:error, "#{self.class}: Unable to serialize object: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to serialize object: #{e}")
      end

      def deserialize(string)
        ::Yajl::Parser.parse(string, {:symbolize_names => true})
      rescue TypeError,::Yajl::EncodeError,::Yajl::ParseError,::Encoding::UndefinedConversionError => e
        ParallelWorkforce.log(:warn, "#{self.class}: Unable to deserialize string: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to deserialize string: #{e}")
      end
    end
  end
end
