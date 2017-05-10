# frozen_string_literal: true

module AndyCore
  def self.monkeypatch(sourceclass, destclass)
    sourceclass.private_method_defined?(:include) ? sourceclass.send(:include, destclass) : sourceclass.include(destclass)
  end
end
