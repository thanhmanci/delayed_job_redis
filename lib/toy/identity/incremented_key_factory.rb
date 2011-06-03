module Toy
  module Identity
    class IncrementedKeyFactory
      def initialize(store)
        @store = store
      end
      
      def key_type
        String
      end

      def next_key(object)
        id = @store.incr("keys:#{object.class.name}")
        "#{object.class.name}:#{id}"
      end
    end
  end
end