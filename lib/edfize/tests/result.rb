# frozen_string_literal: true

module Edfize
  module Tests
    # Represents the result of a validation test, including pass/fail status and details
    class Result
      attr_accessor :passes, :pass_fail, :expected, :actual
    end
  end
end
