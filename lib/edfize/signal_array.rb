# frozen_string_literal: true

module Edfize
  # Extends Array to provide signal-specific functionality
  class SignalArray < Array
    def find_by_label(label)
      label_str = label.to_s
      find { |signal| signal.label.strip.downcase == label_str.strip.downcase }
    end

    def find(*args, &block)
      if args.empty? && !block_given?
        super
      elsif args.size == 1 && !block_given?
        find_by_label(args.first)
      else
        super
      end
    end

    def delete(label)
      signal = find_by_label(label)
      return false unless signal

      super(signal)
      true
    end
  end
end
