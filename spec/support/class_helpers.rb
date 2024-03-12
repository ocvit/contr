# frozen_string_literal: true

module ClassHelpers
  def define_class(class_name, superclass, &block)
    klass = Class.new(superclass, &block)
    stub_const(class_name, klass)
  end

  def define_contract_class(contract_name, superclass = Contr::Base, &block)
    define_class(contract_name, superclass, &block)
  end
end
