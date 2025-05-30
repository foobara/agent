module Foobara
  class Agent < CommandConnector
    module Concerns
      # There's nothing really subclass-specific about this concern, maybe rename it...
      module SubclassCacheable
        def subclass_cache
          @subclass_cache ||= {}
        end

        def clear_subclass_cache
          @subclass_cache = nil
        end

        def cached_subclass(key)
          if subclass_cache.key?(key)
            subclass_cache[key]
          else
            subclass_cache[key] = yield
          end
        end
      end
    end
  end
end
