# frozen_string_literal: true

class Array
  def cleanup!(unique: true)
    flatten!
    compact!
    uniq! if unique
  end

  def cleanup(unique: true)
    out = flatten
    out = compact
    out = uniq if unique
    out
  end
end
