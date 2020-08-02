module ParallelWorkforce
  module Serializer
    class Json
      def serialize(object)
        ::JSON.dump(object)
      rescue TypeError,::JSON::ParserError,::Encoding::UndefinedConversionError => e
        ParallelWorkforce.log(:error, "#{self.class}: Unable to serialize object: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to serialize object: #{e}")
      end

      def deserialize(string)
        ::JSON.parse(string,{:symbolize_names => true})
      rescue TypeError,::JSON::ParserError,::Encoding::UndefinedConversionError => e
        ParallelWorkforce.log(:warn, "#{self.class}: Unable to deserialize string: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to deserialize string: #{e}")
      end
    end
  end
end
