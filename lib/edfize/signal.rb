# frozen_string_literal: true

module Edfize
  # Represents a signal in an EDF file, containing both header information and data values
  class Signal
    attr_accessor :label, :transducer_type, :physical_dimension,
                  :physical_minimum, :physical_maximum,
                  :digital_minimum, :digital_maximum,
                  :prefiltering, :samples_per_data_record,
                  :reserved_area, :digital_values, :physical_values

    SIGNAL_CONFIG = {
      label: { size: 16, after_read: :strip, name: "Label" },
      transducer_type: { size: 80, after_read: :strip, name: "Transducer Type" },
      physical_dimension: { size:  8, after_read: :strip, name: "Physical Dimension" },
      physical_minimum: { size:  8, after_read: :to_f,  name: "Physical Minimum" },
      physical_maximum: { size:  8, after_read: :to_f,  name: "Physical Maximum" },
      digital_minimum: { size:  8, after_read: :to_i,  name: "Digital Minimum" },
      digital_maximum: { size:  8, after_read: :to_i,  name: "Digital Maximum" },
      prefiltering: { size: 80, after_read: :strip, name: "Prefiltering" },
      samples_per_data_record: { size: 8, after_read: :to_i, name: "Samples Per Data Record" },
      reserved_area: { size: 32, name: "Reserved Area" }
    }.freeze

    def initialize
      @digital_values = []
      @physical_values = []
    end

    def self.create
      signal = new
      yield signal if block_given?
      signal
    end

    def print_header
      SIGNAL_CONFIG.each do |section, hash|
        puts "  #{hash[:name]}#{" " * (29 - hash[:name].size)}: " + send(section).to_s
      end
    end

    # Physical value (dimension PhysiDim) = (ASCIIvalue-DigiMin)*(PhysiMax-PhysiMin)/(DigiMax-DigiMin) + PhysiMin.
    def calculate_physical_values!
      return if @digital_values.empty?

      @physical_values = @digital_values.collect do |sample|
        ((sample - @digital_minimum) * (@physical_maximum - @physical_minimum) / 
         (@digital_maximum - @digital_minimum)) + @physical_minimum
      rescue StandardError
        nil
      end
    end

    # For reading back large files, load only the first few values
    def load_preview(count = 5)
      return [] if @digital_values.empty?
      calculate_physical_values! if @physical_values.empty?
      @physical_values[0...count]
    end

    def samples
      @physical_values
    end

    # Convert physical values to digital values
    def convert_to_digital(physical_batch)
      physical_batch.map do |physical|
        ((physical - @physical_minimum) * 
         (@digital_maximum - @digital_minimum) / 
         (@physical_maximum - @physical_minimum) + 
         @digital_minimum).round
      end
    end
  end
end
