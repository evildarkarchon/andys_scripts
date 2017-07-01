# frozen_string_literal: true

module AndyCore
  def self.monkeypatch(parentclass, childclass)
    if childclass.respond_to?(:each)
      childclass.each { |i| parentclass.private_method_defined?(:include) ? parentclass.send(:include, i) : parentclass.include(i) }
    else
      parentclass.private_method_defined?(:include) ? parentclass.send(:include, childclass) : parentclass.include(childclass)
    end
  end
end
