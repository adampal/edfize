#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "zlib"

# Parameters for generating the sine wave
TOTAL_SAMPLES = 3_200_000  # 3.2 million values
SAMPLE_RATE = 256.0        # 256 Hz
FREQUENCY = 10.0           # 10 Hz sine wave
AMPLITUDE = 100.0          # 100 mV

output_path = File.join(File.dirname(__FILE__), "test_data.json.gz")

puts "Generating #{TOTAL_SAMPLES} values..."
start_time = Time.now

# Open a gzipped file for writing
Zlib::GzipWriter.open(output_path) do |gz|
  # Write opening bracket
  gz.write("[\n")
  
  # Generate and write values in batches to avoid memory issues
  batch_size = 10000
  batches = (TOTAL_SAMPLES.to_f / batch_size).ceil
  
  batches.times do |batch_index|
    start_index = batch_index * batch_size
    current_batch_size = [batch_size, TOTAL_SAMPLES - start_index].min
    
    # Generate batch of values
    values = current_batch_size.times.map do |i|
      sample_index = start_index + i
      t = sample_index / SAMPLE_RATE
      AMPLITUDE * Math.sin(2 * Math::PI * FREQUENCY * t)
    end
    
    # Write values with commas
    values.each_with_index do |value, i|
      gz.write(value.to_s)
      # Add comma unless this is the last value of the last batch
      gz.write(",\n") unless batch_index == batches - 1 && i == values.size - 1
    end
    
    # Progress update
    if (batch_index + 1) % 10 == 0
      percent = ((batch_index + 1) * 100.0 / batches).round(1)
      puts "Progress: #{percent}% (#{batch_index + 1}/#{batches} batches)"
    end
  end
  
  # Write closing bracket
  gz.write("\n]")
end

end_time = Time.now
file_size = File.size(output_path)
puts "\nDone!"
puts "Time taken: #{(end_time - start_time).round(2)} seconds"
puts "File size: #{(file_size.to_f / 1024 / 1024).round(2)} MB"
