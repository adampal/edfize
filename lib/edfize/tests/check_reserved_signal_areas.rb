# frozen_string_literal: true

module Edfize
  module Tests
    # This test checks that the reserved areas in the signal headers are blank
    module CheckReservedSignalAreas
      def test_reserved_signal_areas_blank(runner)
        reserved_areas = runner.edf.signals.collect(&:reserved_area)

        result = Result.new
        result.passes = (reserved_areas.reject { |r| r.to_s.strip == "" }.none?)
        result.pass_fail = "#{"  #{result.passes ? "PASS" : "FAIL"}".send(result.passes ? :green : :red)} Signal Reserved Area Blank"
        result.expected  = "    Expected : #{[""] * runner.edf.signals.count}"
        result.actual    = "    Actual   : #{reserved_areas}"
        result
      end
    end
  end
end
