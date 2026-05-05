# frozen_string_literal: true

module WillowSword
  class SwordError < StandardError
    attr_reader :sword_error

    def initialize(error)
      @sword_error = error
      super(error.message)
    end
  end
end
