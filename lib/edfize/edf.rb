# frozen_string_literal: true

require "edfize/signal"
require "date"

module Edfize
  # Class used to load and manipulate EDFs
  class Edf
    # EDF File Path
    attr_reader   :filename

    # Header Information
    attr_accessor :version

    attr_accessor :local_patient_identification, :local_recording_identification,
                  :start_date_of_recording, :start_time_of_recording,
                  :number_of_bytes_in_header, :reserved, :number_of_data_records,
                  :duration_of_a_data_record, :number_of_signals, :signals

    HEADER_CONFIG = {
      version: { size: 8, after_read: :to_i, name: "Version" },
      local_patient_identification: { size: 80, after_read: :strip, name: "Local Patient Identification" },
      local_recording_identification: { size: 80, after_read: :strip, name: "Local Recording Identification" },
      start_date_of_recording: { size: 8,                     name: "Start Date of Recording",
                                 description: "(dd.mm.yy)" },
      start_time_of_recording: { size: 8,                     name: "Start Time of Recording",
                                 description: "(hh.mm.ss)" },
      number_of_bytes_in_header: { size: 8, after_read: :to_i, name: "Number of Bytes in Header" },
      reserved: { size: 44, name: "Reserved" },
      number_of_data_records: { size: 8, after_read: :to_i, name: "Number of Data Records" },
      duration_of_a_data_record: { size: 8, after_read: :to_i, name: "Duration of a Data Record",
                                   units: "second" },
      number_of_signals: { size: 4, after_read: :to_i,  name: "Number of Signals" }
    }.freeze

    HEADER_OFFSET = HEADER_CONFIG.collect { |_k, h| h[:size] }.inject(:+)

    SIZE_OF_SAMPLE_IN_BYTES = 2

    # Used by tests
    RESERVED_SIZE = HEADER_CONFIG[:reserved][:size]

    def self.create(filename = nil)
      edf = new(filename, initialize_empty: true)
      yield edf if block_given?
      edf
    end

    def initialize(filename, initialize_empty: false)
      @filename = filename
      @signals = []
      @is_new_file = initialize_empty

      if initialize_empty
        initialize_empty_edf
      else
        read_header
        read_signal_header
      end
    end

    def initialize_empty_edf
      @version = 0
      @local_patient_identification = ""
      @local_recording_identification = ""
      @start_date_of_recording = Time.now.strftime("%d.%m.%y")
      @start_time_of_recording = Time.now.strftime("%H.%M.%S")
      @number_of_bytes_in_header = 0  # Will be calculated before writing
      @reserved = " " * RESERVED_SIZE
      @number_of_data_records = 0
      @duration_of_a_data_record = 1
      @number_of_signals = 0
    end

    def load_signals
      data_records
    end

    # Epoch Number is Zero Indexed, and Epoch Size is in Seconds (Not Data Records)
    def load_epoch(epoch_number, epoch_size)
      # reset_signals!
      load_digital_signals_by_epoch(epoch_number, epoch_size)
      calculate_physical_values!
    end

    def size_of_header
      HEADER_OFFSET + (ns * Signal::SIGNAL_CONFIG.collect { |_k, h| h[:size] }.inject(:+))
    end

    def expected_size_of_header
      @number_of_bytes_in_header
    end

    # Total File Size In Bytes
    def edf_size
      File.size(@filename)
    end

    # Data Section Size In Bytes
    def expected_data_size
      @signals.collect(&:samples_per_data_record).inject(:+).to_i * @number_of_data_records * SIZE_OF_SAMPLE_IN_BYTES
    end

    def expected_edf_size
      expected_data_size + size_of_header
    end

    def section_value_to_string(section)
      instance_variable_get("@#{section}").to_s
    end

    def section_units(section)
      units = HEADER_CONFIG[section][:units].to_s
      if units == ""
        ""
      else
        " #{units}" + (instance_variable_get("@#{section}") == 1 ? "" : "s")
      end
    end

    def section_description(section)
      description = HEADER_CONFIG[section][:description].to_s
      if description == ""
        ""
      else
        " #{description}"
      end
    end

    def print_header
      puts "\nEDF                            : #{@filename}"
      puts "Total File Size                : #{edf_size} bytes"
      puts "\nHeader Information"
      HEADER_CONFIG.each do |section, hash|
        puts "#{hash[:name]}#{" " * (31 - hash[:name].size)}: " + section_value_to_string(section) + section_units(section) + section_description(section)
      end
      puts "\nSignal Information"
      signals.each_with_index do |signal, index|
        puts "\n  Position                     : #{index + 1}"
        signal.print_header
      end
      puts "\nGeneral Information"
      puts "Size of Header (bytes)         : #{size_of_header}"
      puts "Size of Data   (bytes)         : #{data_size}"
      puts "Total Size     (bytes)         : #{edf_size}"

      puts "Expected Size of Header (bytes): #{expected_size_of_header}"
      puts "Expected Size of Data   (bytes): #{expected_data_size}"
      puts "Expected Total Size     (bytes): #{expected_edf_size}"
    end

    def start_date
      (dd, mm, yy) = start_date_of_recording.split(".")
      dd = parse_integer(dd)
      mm = parse_integer(mm)
      yy = parse_integer(yy)
      yyyy = if yy && yy >= 85
               yy + 1900
             else
               yy + 2000
             end
      Date.strptime("#{mm}/#{dd}/#{yyyy}", "%m/%d/%Y")
    rescue StandardError
      nil
    end

    def parse_integer(string)
      Integer(format("%g", string))
    rescue StandardError
      nil
    end

    def update(hash)
      hash.each do |section, value|
        update_header_section?(section, value)
      end
    end

    def update_header_section?(section, value)
      return false unless HEADER_CONFIG.keys.include?(section)

      send "#{section}=", value
      size = HEADER_CONFIG[section][:size]
      string = format("%-#{size}.#{size}s", send(section).to_s)
      File.binwrite(filename, string, send(:compute_offset, section))
      true
    end

    # Load just enough data to preview the signals
    def load_signal_preview
      load_digital_signals(preview_mode: true)
      calculate_physical_values!
    end

    protected

    def read_header
      HEADER_CONFIG.each_key do |section|
        read_header_section(section)
      end
    end

    def read_header_section(section)
      result = File.binread(@filename, HEADER_CONFIG[section][:size], compute_offset(section))
      result = result.to_s.send(HEADER_CONFIG[section][:after_read]) unless HEADER_CONFIG[section][:after_read].to_s == ""
      instance_variable_set("@#{section}", result)
    end

    def compute_offset(section)
      offset = 0
      HEADER_CONFIG.each do |key, hash|
        break if key == section

        offset += hash[:size]
      end
      offset
    end

    def ns
      @number_of_signals
    end

    def reset_signals!
      @signals = []
      read_signal_header
    end

    def create_signals
      (0..(ns - 1)).to_a.each do |signal_number|
        @signals[signal_number] ||= Signal.new
      end
    end

    def read_signal_header
      create_signals
      Signal::SIGNAL_CONFIG.each_key do |section|
        read_signal_header_section(section)
      end
    end

    def compute_signal_offset(section)
      offset = 0
      Signal::SIGNAL_CONFIG.each do |key, hash|
        break if key == section

        offset += hash[:size]
      end
      offset
    end

    def read_signal_header_section(section)
      offset = HEADER_OFFSET + (ns * compute_signal_offset(section))
      (0..(ns - 1)).to_a.each do |signal_number|
        section_size = Signal::SIGNAL_CONFIG[section][:size]
        result = File.binread(@filename, section_size, offset + (signal_number * section_size))
        result = result.to_s.send(Signal::SIGNAL_CONFIG[section][:after_read]) unless Signal::SIGNAL_CONFIG[section][:after_read].to_s == ""
        @signals[signal_number].send("#{section}=", result)
      end
    end

    def data_records
      load_digital_signals
      calculate_physical_values!
    end

    def load_digital_signals_by_epoch(epoch_number, epoch_size)
      size_of_data_record_in_bytes = @signals.collect(&:samples_per_data_record).inject(:+).to_i * SIZE_OF_SAMPLE_IN_BYTES
      data_records_to_retrieve = begin
        epoch_size / @duration_of_a_data_record
      rescue StandardError
        0
      end
      length_of_bytes_to_read = (data_records_to_retrieve + 1) * size_of_data_record_in_bytes
      epoch_offset_size = epoch_number * epoch_size * size_of_data_record_in_bytes # TODO: The size in bytes of an epoch

      all_signal_data = begin
        File.binread(@filename, length_of_bytes_to_read,
                     size_of_header + epoch_offset_size).unpack("s<*")
      rescue StandardError
        []
      end
      load_signal_data(all_signal_data, data_records_to_retrieve + 1)
    end

    # 16-bit signed integer size = 2 Bytes = 2 ASCII characters
    # 16-bit signed integer in "Little Endian" format (least significant byte first)
    # unpack:  s<         16-bit signed, (little-endian) byte order
    def load_digital_signals(preview_mode: false)
      if preview_mode
        # Load just enough data for a preview (first data record)
        size_of_data_record = @signals.collect(&:samples_per_data_record).inject(:+).to_i * SIZE_OF_SAMPLE_IN_BYTES
        all_signal_data = File.binread(@filename, size_of_data_record, size_of_header).unpack("s<*")
        load_signal_data(all_signal_data, 1)
      else
        # Load all data (original behavior)
        all_signal_data = File.binread(@filename, nil, size_of_header).unpack("s<*")
        load_signal_data(all_signal_data, @number_of_data_records)
      end
    end

    # Load just enough data to preview the signals
    def load_signal_preview
      load_digital_signals(preview_mode: true)
      calculate_physical_values!
    end

    def load_signal_data(all_signal_data, data_records_retrieved)
      all_samples_per_data_record = @signals.collect(&:samples_per_data_record)
      total_samples_per_data_record = all_samples_per_data_record.inject(:+).to_i

      offset = 0
      offsets = []
      all_samples_per_data_record.each do |samples_per_data_record|
        offsets << offset
        offset += samples_per_data_record
      end

      (0..(data_records_retrieved - 1)).to_a.each do |data_record_index|
        @signals.each_with_index do |signal, signal_index|
          read_start = (data_record_index * total_samples_per_data_record) + offsets[signal_index]
          (0..(signal.samples_per_data_record - 1)).to_a.each do |value_index|
            signal.digital_values << all_signal_data[read_start + value_index]
          end
        end
      end
    end

    def calculate_physical_values!
      @signals.each(&:calculate_physical_values!)
    end

    def data_size
      File.binread(@filename, nil, size_of_header).size
    end

    private

    def write_main_header(file)
      HEADER_CONFIG.each do |section, config|
        value = format_header_value(section)
        file.write(value.ljust(config[:size])[0, config[:size]])
      end
    end

    def format_header_value(section)
      value = instance_variable_get("@#{section}")
      value.to_s
    end

    def write_signal_headers(file)
      Signal::SIGNAL_CONFIG.each do |section, config|
        @signals.each do |signal|
          value = signal.send(section).to_s
          file.write(value.ljust(config[:size])[0, config[:size]])
        end
      end
    end

    def write_data_records(file)
      @signals.each do |signal|
        # Use the signal's write method which handles both streaming and regular modes
        signal.write_values_to(file)
      end
    end

    def calculate_header_size
      main_header_size = HEADER_CONFIG.values.sum { |config| config[:size] }
      signal_header_size = @signals.size * Signal::SIGNAL_CONFIG.values.sum { |config| config[:size] }
      main_header_size + signal_header_size
    end

    def ensure_annotations_signal
      return if @signals.any? { |s| s.label == "EDF Annotations" }

      annotation_signal = Signal.new
      annotation_signal.label = "EDF Annotations"
      annotation_signal.transducer_type = " " * 80
      annotation_signal.physical_dimension = " " * 8
      annotation_signal.physical_minimum = -1
      annotation_signal.physical_maximum = 1
      annotation_signal.digital_minimum = -32_768
      annotation_signal.digital_maximum = 32_767
      annotation_signal.prefiltering = " " * 80
      annotation_signal.samples_per_data_record = 60 # Standard size for annotations
      annotation_signal.reserved_area = " " * 32

      @signals << annotation_signal
      @number_of_signals = @signals.size
    end

    public

    # Writes the EDF file to the specified path
    # @param output_path [String] The path where the EDF file should be written
    # @param is_continuous [Boolean] Whether this is a continuous (EDF+C) or discontinuous (EDF+D) recording
    # Load just enough data to preview the signals
    def load_signal_preview
      load_digital_signals(preview_mode: true)
      calculate_physical_values!
    end

    def write(output_path = nil, is_continuous: true)
      # Use provided path or stored filename
      target_path = output_path || @filename
      raise "No output path specified" if target_path.nil?

      # Update the filename for future operations
      @filename = target_path

      # Update number of signals
      @number_of_signals = @signals.size

      # Ensure we have at least one EDF Annotations signal for time-keeping
      ensure_annotations_signal

      # Calculate and update header size
      @number_of_bytes_in_header = calculate_header_size

      # Set EDF+ format in reserved area
      @reserved = "EDF+#{is_continuous ? "C" : "D"}".ljust(RESERVED_SIZE)

      # Calculate number of data records if not set
      if @number_of_data_records == 0 && !@signals.empty?
        max_values = @signals.map { |s| s.digital_values.size / s.samples_per_data_record.to_f }.max
        @number_of_data_records = max_values.ceil
      end

      File.open(target_path, "wb") do |file|
        write_main_header(file)
        write_signal_headers(file)
        write_data_records(file)
      end

      # If this was a new file, we're no longer in new file mode
      @is_new_file = false
    end
  end
end
