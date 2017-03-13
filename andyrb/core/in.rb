require_relative 'cleanup'
class Object
  def in?(*arr)
    arr.cleanup!
    arr.include? self
  end
end
