#!/usr/bin/env ruby
# frozen_string_literal: true

require "edfize"
require "json"
require "zlib"

# Input and output paths
input_path = File.join(File.dirname(__FILE__), "test_data.json.gz")
output_path = File.join(File.dirname(__FILE__), "large_output_from_file.edf")

begin
  # Create a new EDF file in memory
  edf = Edfize::Edf.create do |e|
    e.local_patient_identification = "File Import Test"
    e.local_recording_identification = "Streaming From File Example"
    e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
    e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
    e.duration_of_a_data_record = 1  # Each data record is 1 second
  end

  # Create a new signal
  signal = Edfize::Signal.new
  signal.label = "Imported Signal"
  signal.transducer_type = "Test Signal"
  signal.physical_dimension = "mV"
  signal.physical_minimum = -500.0
  signal.physical_maximum = 500.0
  signal.digital_minimum = -32768  # Standard 16-bit range
  signal.digital_maximum = 32767
  signal.prefiltering = "None"
  signal.samples_per_data_record = 256  # 256 Hz sampling rate
  signal.reserved_area = " " * 32

  # Get total samples by counting lines in the gzipped file
  total_samples = 0
  Zlib::GzipReader.open(input_path) do |gz|
    # Skip opening bracket
    gz.readline
    
    # Count lines (excluding brackets)
    while (line = gz.readline)
      break if line.strip == "]"
      total_samples += 1
    end
  end

  puts "Found #{total_samples} values in file"

  # Read all values from the gzipped JSON file into memory
  physical_values = []
  Zlib::GzipReader.open(input_path) do |gz|
    # Skip opening bracket
    gz.readline
    
    # Read values until we hit the closing bracket
    while (line = gz.readline)
      break if line.strip == "]"
      # Parse the value (remove trailing comma if present)
      value = line.strip.sub(/,$/, "").to_f
      physical_values << value
    end
  end

  # Update total_samples based on actual data read
  total_samples = physical_values.size

  # Convert physical values to digital and assign to signal
  signal.digital_values = signal.convert_to_digital(physical_values)
  signal.physical_values = physical_values

  # Add the signal to the EDF
  edf.signals << signal

  # Write the EDF file (as continuous EDF+)
  puts "Writing EDF file to: #{output_path}"
  puts "Total samples: #{total_samples}"
  puts "Expected file size: ~#{(total_samples * 2 + 2048) / 1024 / 1024}MB"

  start_time = Time.now
  edf.write(output_path, is_continuous: true)
  end_time = Time.now

  puts "\nFile written successfully!"
  puts "Time taken: #{(end_time - start_time).round(2)} seconds"
  puts "Actual file size: #{File.size(output_path) / 1024 / 1024}MB"

  # Verify by reading back (just the header and first few values)
  puts "\nVerifying written EDF file..."
  verification_edf = Edfize::Edf.new(output_path)
  verification_edf.load_signal_preview

  puts "\nSignal Information:"
  puts "Label: #{verification_edf.signals[0].label}"
  puts "Physical Dimension: #{verification_edf.signals[0].physical_dimension}"
  puts "Sampling Rate: #{verification_edf.signals[0].samples_per_data_record} Hz"
  puts "\nFirst few values (preview):"
  test_signal = verification_edf.signals.find { |s| s.label == "Imported Signal" }
  puts "Physical values: #{test_signal.load_preview(5).inspect}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace
end