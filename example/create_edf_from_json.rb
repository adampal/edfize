#!/usr/bin/env ruby

require "bundler/setup"
require "edfize"
require "json"
require "benchmark"

# Configuration
OUTPUT_EDF_FILE = "./example/output_from_json.edf"
JSON_FILE = "./example/values.json"  # Your JSON file with array of values
SIGNAL_LABEL = "JSON Signal"
PHYSICAL_DIMENSION = "mV"
SAMPLING_RATE = 256  # Hz
PHYSICAL_MIN = -100.0
PHYSICAL_MAX = 100.0
DIGITAL_MIN = -32768
DIGITAL_MAX = 32767
BATCH_SIZE = 1000 # Number of values to process at a time

puts "Reading values from: #{JSON_FILE}"

def create_value_enumerator(json_file)
  Enumerator.new do |yielder|
    # Read the file in chunks to handle large files efficiently
    File.open(json_file) do |file|
      # Skip initial whitespace and opening bracket
      file.each_char { |c| break if c == '[' }
      
      buffer = ""
      in_number = false
      
      # Process the file character by character
      file.each_char do |char|
        case char
        when /[\d.-]/  # Part of a number
          buffer << char
          in_number = true
        when /[\s,\]]/ # Delimiter
          if in_number
            # Convert and yield the number
            value = buffer.strip.to_f
            yielder << value
            buffer = ""
            in_number = false
          end
        end
      end
      
      # Handle the last number if any
      if in_number
        value = buffer.strip.to_f
        yielder << value
      end
    end
  end
end

# Create enumerator for counting
puts "Counting total values..."
value_stream_enumerator = create_value_enumerator(JSON_FILE)
total_values = 0
begin
  while value_stream_enumerator.next
    total_values += 1
    print "\rProcessed #{total_values} values..." if total_values % 100_000 == 0
  end
rescue StopIteration
end
puts "\nFound #{total_values} values in file"

# Create new enumerator for processing
value_stream_enumerator = create_value_enumerator(JSON_FILE)

# Create EDF file
edf = Edfize::Edf.create(OUTPUT_EDF_FILE) do |e|
  e.local_patient_identification = "JSON Data Import"
  e.local_recording_identification = "JSON Signal Test"
  e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
  e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
  e.duration_of_a_data_record = 1 # 1 second data records
end

# Add a signal
signal = Edfize::Signal.new
signal.label = SIGNAL_LABEL
signal.transducer_type = "JSON Import"
signal.physical_dimension = PHYSICAL_DIMENSION
signal.physical_minimum = PHYSICAL_MIN
signal.physical_maximum = PHYSICAL_MAX
signal.digital_minimum = DIGITAL_MIN
signal.digital_maximum = DIGITAL_MAX
signal.prefiltering = "None"
signal.samples_per_data_record = SAMPLING_RATE
edf.signals << signal

puts "Writing EDF file to: #{OUTPUT_EDF_FILE}"
puts "Total samples: #{total_values}"
puts "Expected file size: ~#{(total_values * Edfize::Edf::SIZE_OF_SAMPLE_IN_BYTES / (1024.0 * 1024.0)).round(0)}MB"

time_taken = Benchmark.realtime do
  # Calculate number of data records needed
  data_records = (total_values.to_f / SAMPLING_RATE).ceil
  edf.number_of_data_records = data_records
  puts "Data records needed: #{data_records}"

  # The signal.stream_values block will be called repeatedly to get batches of values
  signal.stream_values(total_values, BATCH_SIZE) do |batch_size_requested|
    # Use the enumerator to take the next batch of values
    value_stream_enumerator.take(batch_size_requested)
  end
  edf.write
end

puts "\nFile written successfully!"
puts "Time taken: #{time_taken.round(1)} seconds"
puts "Actual file size: #{(File.size(OUTPUT_EDF_FILE) / (1024.0 * 1024.0)).round(0)}MB"

# Verification (optional)
puts "\nVerifying written EDF file..."
verification_edf = Edfize::Edf.new(OUTPUT_EDF_FILE)
verification_edf.load_signals

puts "\nSignal Information:"
test_signal = verification_edf.signals.find { |s| s.label == SIGNAL_LABEL }
puts "Label: #{test_signal.label}"
puts "Physical Dimension: #{test_signal.physical_dimension}"
puts "Sampling Rate: #{test_signal.samples_per_data_record} Hz"
puts "Total Values: #{test_signal.digital_values.size}"
puts "Physical Range: #{test_signal.physical_minimum} to #{test_signal.physical_maximum} #{test_signal.physical_dimension}"

puts "\nFirst few values:"
puts "Digital values: #{test_signal.digital_values[0..4]}"
puts "Physical values: #{test_signal.physical_values[0..4]}"
