module Util
  def self.recursive_symbolize_keys(my_hash)
    case my_hash
    when Hash
      Hash[
        my_hash.map do |key, value|
          [key.respond_to?(:to_sym) ? key.to_sym : key, recursive_symbolize_keys(value)]
        end
      ]
    when Enumerable
      my_hash.map { |value| recursive_symbolize_keys(value) }
    else
      my_hash
    end
  end
end
