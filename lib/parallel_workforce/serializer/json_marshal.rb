module ParallelWorkforce
  module Serializer
    class JsonMarshal < Marshal
      def serialize(object)
        JSON.dump(value: super(object)) # super always returns a String
      end

      def deserialize(string)
        super(JSON.parse(string)['value'])
      rescue JSON::ParserError => e
        ParallelWorkforce.log(:warn, "#{self.class}: Unable to deserialize string: #{e}", e, *e.backtrace)

        raise ParallelWorkforce::SerializerError.new("Unable to deserialize string: #{e}")
      end
    end
  end
end
