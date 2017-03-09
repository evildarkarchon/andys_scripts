class Object
  def in?(*arr)
    arr.flatten! if arr.respond_to?(:flatten!)
    arr.uniq! if arr.respond_to?(:uniq!)
    arr.include? self
  end
end
