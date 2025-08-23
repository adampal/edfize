#!/usr/bin/env ruby
# frozen_string_literal: true

require "edfize"

# Output file path
output_path = File.join(File.dirname(__FILE__), "large_output.edf")

begin
  # Create a new EDF file in memory
  edf = Edfize::Edf.create do |e|
    e.local_patient_identification = "Large Dataset Test"
    e.local_recording_identification = "Streaming Example"
    e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
    e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
    e.duration_of_a_data_record = 1  # Each data record is 1 second
  end

  # Create a new signal
  signal = Edfize::Signal.new
  signal.label = "Large Signal"
  signal.transducer_type = "Test Signal"
  signal.physical_dimension = "mV"
  signal.physical_minimum = -500.0
  signal.physical_maximum = 500.0
  signal.digital_minimum = -32768  # Standard 16-bit range
  signal.digital_maximum = 32767
  signal.prefiltering = "None"
  signal.samples_per_data_record = 256  # 256 Hz sampling rate
  signal.reserved_area = " " * 32

  # Set up streaming for a large number of values
  total_samples = 3_200_000  # 3.2 million values
  sample_rate = 256.0
  frequency = 10.0  # 10 Hz sine wave

  # Set up the streaming generator
  signal.stream_values(total_samples, 10000) do |batch_size|
    # Generate a batch of values
    batch = []
    batch_size.times do |i|
      # Calculate the overall sample index
      t = (i + batch.size) / sample_rate
      # Generate sine wave value
      batch << 100.0 * Math.sin(2 * Math::PI * frequency * t)
    end
    batch
  end

  # Add the signal to the EDF
  edf.signals << signal

  # Write the EDF file (as continuous EDF+)
  puts "Writing large EDF file to: #{output_path}"
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
  test_signal = verification_edf.signals.find { |s| s.label == "Large Signal" }
  puts "Physical values: #{test_signal.load_preview(5).inspect}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace
end
