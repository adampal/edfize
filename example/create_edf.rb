#!/usr/bin/env ruby
# frozen_string_literal: true

require "edfize"

# Output file path
output_path = File.join(File.dirname(__FILE__), "output.edf")

begin
  # Create a new EDF file in memory
  edf = Edfize::Edf.create do |e|
    # Set header information
    e.local_patient_identification = "Patient X"
    e.local_recording_identification = "Recording 001"
    e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
    e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
    e.duration_of_a_data_record = 1  # Each data record is 1 second
  end

  # Create a new signal
  signal = Edfize::Signal.new
  signal.label = "Example Signal"
  signal.transducer_type = "Custom Sensor"
  signal.physical_dimension = ""
  signal.physical_minimum = 0
  signal.physical_maximum = 255
  signal.digital_minimum = 0
  signal.digital_maximum = 255
  signal.prefiltering = ""
  signal.samples_per_data_record = 125  # 256 Hz sampling rate
  signal.reserved_area = " " * 32  # Required blank space

  # Your array of values (example values here)
  physical_values = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  # Pad with zeros to match samples_per_data_record
  physical_values += [0.0] * (signal.samples_per_data_record - physical_values.length)

  # Convert physical values to digital values
  # Using the formula: digital = (physical - physical_min) * (digital_max - digital_min) / (physical_max - physical_min) + digital_min
  digital_values = physical_values.map do |physical|
    ((physical - signal.physical_minimum) * (signal.digital_maximum - signal.digital_minimum) / 
     (signal.physical_maximum - signal.physical_minimum) + signal.digital_minimum).round
  end
  
  # Set the digital values
  signal.digital_values = digital_values

  # Add the signal to the EDF
  edf.signals << signal

  # Write the EDF file (as continuous EDF+)
  puts "Writing EDF file to: #{output_path}"
  edf.write(output_path, is_continuous: true)
  
  # Verify by reading back
  puts "\nVerifying written EDF file..."
  verification_edf = Edfize::Edf.new(output_path)
  verification_edf.load_signals
  
  puts "\nSignal Information:"
  puts "Label: #{verification_edf.signals[0].label}"
  puts "Physical Dimension: #{verification_edf.signals[0].physical_dimension}"
  puts "Sampling Rate: #{verification_edf.signals[0].samples_per_data_record} Hz"
  puts "\nFirst few values:"
  puts "Physical values: #{verification_edf.signals[0].physical_values.first(5).inspect}"
  puts "Digital values: #{verification_edf.signals[0].digital_values.first(5).inspect}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace
end