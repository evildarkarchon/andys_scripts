module Util
  def self.class_exists?(name)
    klass = Module.const_get(name)
    klass.is_a?(Class) unless klass.is_a?(Module)
    klass.is_a?(Module) if klass.is_a?(Module)
    false unless klass.is_a?(Module) || klass.is_a?(Class)
  rescue NameError
    false
  end
end
