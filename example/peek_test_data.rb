#!/usr/bin/env ruby
# frozen_string_literal: true

require "zlib"

input_path = File.join(File.dirname(__FILE__), "test_data.json.gz")
num_values_to_show = 20

puts "First #{num_values_to_show} values from #{input_path}:"
puts "-" * 50

Zlib::GzipReader.open(input_path) do |gz|
  # Skip opening bracket
  gz.readline
  
  # Read and print first N values
  num_values_to_show.times do |i|
    line = gz.readline.strip
    # Remove trailing comma for all but the last value
    line = line.sub(/,$/, "")
    puts "#{i + 1}: #{line}"
  end
  
  puts "\n... (#{File.size(input_path) / 1024 / 1024}MB compressed file continues)"
end
