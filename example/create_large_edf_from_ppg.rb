#!/usr/bin/env ruby

require "bundler/setup"
require "edfize"
require "benchmark"
require "stringio"

# Configuration
OUTPUT_EDF_FILE = "./example/large_output_from_ppg.edf"
PPG_DATA_FILE = "./example/edf-ppg.txt.zip"
SIGNAL_LABEL = "PPG Signal"
PHYSICAL_DIMENSION = "mV"
SAMPLING_RATE = 256  # Assuming 256Hz sampling rate for PPG
PHYSICAL_MIN = -5.0  # Adjust based on your PPG data range
PHYSICAL_MAX = 5.0   # Adjust based on your PPG data range
DIGITAL_MIN = -32768
DIGITAL_MAX = 32767
BATCH_SIZE = 1000 # Number of values to process at a time

puts "Reading values from: #{PPG_DATA_FILE}"

def process_chunk(chunk)
  # Remove any non-essential characters and split by comma
  values = chunk.strip
                .gsub(/^\[|\]$/, '') # Remove brackets
                .split(',')
                .map(&:strip)
                .reject(&:empty?)
                .map(&:to_f)
  values
end

def create_value_enumerator
  Enumerator.new do |yielder|
    IO.popen(["unzip", "-p", PPG_DATA_FILE]) do |io|
      buffer = ""
      chunk_size = 8192 # Read in 8KB chunks
      
      while chunk = io.read(chunk_size)
        buffer += chunk
        
        # Process complete values from buffer
        while comma_index = buffer.index(',')
          value_str = buffer[0..comma_index].strip
          buffer = buffer[(comma_index + 1)..-1]
          
          # Skip if it's just the opening bracket
          next if value_str == '['
          
          # Clean and convert value
          value_str = value_str.gsub(/[\[\],]/, '').strip
          next if value_str.empty?
          
          begin
            value = value_str.to_f
            yielder << value
          rescue => e
            puts "Warning: Skipping invalid value: #{value_str}"
          end
        end
      end
      
      # Process any remaining values in buffer
      unless buffer.empty?
        values = process_chunk(buffer)
        values.each { |v| yielder << v }
      end
    end
  end
end

# Create enumerator for counting
puts "Counting total values..."
value_stream_enumerator = create_value_enumerator
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
value_stream_enumerator = create_value_enumerator

# Create EDF file
edf = Edfize::Edf.create(OUTPUT_EDF_FILE) do |e|
  e.local_patient_identification = "PPG Recording"
  e.local_recording_identification = "PPG Data Import"
  e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
  e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
  e.duration_of_a_data_record = 1 # 1 second data records
end

# Add a signal
signal = Edfize::Signal.new
signal.label = SIGNAL_LABEL
signal.transducer_type = "PPG"
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
verification_edf.load_signal_preview

puts "\nSignal Information:"
puts "Label: #{verification_edf.signals.first.label}"
puts "Physical Dimension: #{verification_edf.signals.first.physical_dimension}"
puts "Sampling Rate: #{verification_edf.signals.first.samples_per_data_record} Hz"

puts "\nFirst few values (preview):"
puts "Physical values: #{verification_edf.signals.first.load_preview(5)}"