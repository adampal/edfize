# frozen_string_literal: true

require "test_helper"
require "tempfile"

# Test to assure EDFs can be loaded and updated.
class EdfTest < Minitest::Test
  def setup
    @valid_edf_no_data_records = Edfize::Edf.new("test/support/zero-data-records.edf")
    @valid_edf_with_three_signals = Edfize::Edf.new("test/support/simulated-01.edf")
    @edf_invalid_date = Edfize::Edf.new("test/support/invalid-date.edf")
  end

  def test_create_edf_from_values
    # Create a temporary file for our test
    output_file = Tempfile.new(["test-values", ".edf"])
    begin
      # Sample values representing a sine wave
      sample_rate = 256  # 256 Hz
      duration = 1.0     # 1 second
      frequency = 10.0   # 10 Hz sine wave
      physical_values = []
      
      # Generate one second of a 10 Hz sine wave
      (0...sample_rate).each do |i|
        t = i.to_f / sample_rate
        physical_values << 100.0 * Math.sin(2 * Math::PI * frequency * t)
      end

      # Create a new EDF file
      edf = Edfize::Edf.create do |e|
        e.local_patient_identification = "Test Patient"
        e.local_recording_identification = "Sine Wave Test"
        e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
        e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
        e.duration_of_a_data_record = duration
      end

      # Create a signal for our sine wave
      signal = Edfize::Signal.new
      signal.label = "Sine Wave"
      signal.transducer_type = "Test Signal"
      signal.physical_dimension = "mV"
      signal.physical_minimum = -100.0
      signal.physical_maximum = 100.0
      signal.digital_minimum = -32768
      signal.digital_maximum = 32767
      signal.prefiltering = "None"
      signal.samples_per_data_record = sample_rate
      signal.reserved_area = " " * 32

      # Convert physical values to digital values
      digital_values = physical_values.map do |physical|
        ((physical - signal.physical_minimum) * 
         (signal.digital_maximum - signal.digital_minimum) / 
         (signal.physical_maximum - signal.physical_minimum) + 
         signal.digital_minimum).round
      end

      # Set the digital values
      signal.digital_values = digital_values

      # Add the signal to the EDF
      edf.signals << signal

      # Write the EDF file
      edf.write(output_file.path, is_continuous: true)

      # Read back and verify
      verification_edf = Edfize::Edf.new(output_file.path)
      verification_edf.load_signals

      # Verify header information
      assert_equal "Test Patient", verification_edf.local_patient_identification
      assert_equal "Sine Wave Test", verification_edf.local_recording_identification
      assert_equal duration, verification_edf.duration_of_a_data_record
      # number_of_data_records will be 1 since we're writing one second of data
      assert_equal 1, verification_edf.number_of_data_records

      # Verify signal information (2 signals: our sine wave and the EDF Annotations signal)
      assert_equal 2, verification_edf.signals.size
      assert verification_edf.signals.any? { |s| s.label == "EDF Annotations" }, "EDF Annotations signal not found"
      # Find our sine wave signal (not the annotations signal)
      test_signal = verification_edf.signals.find { |s| s.label == "Sine Wave" }
      assert_equal "Sine Wave", test_signal.label
      assert_equal "mV", test_signal.physical_dimension
      assert_equal sample_rate, test_signal.samples_per_data_record

      # Verify signal values (allowing for small conversion differences)
      test_signal.physical_values.each_with_index do |value, index|
        assert_in_delta physical_values[index], value, 0.1, 
                       "Value mismatch at index #{index}"
      end

      # Verify we can read all the data
      assert_equal sample_rate, test_signal.physical_values.size
      assert_equal sample_rate, test_signal.digital_values.size

      # Verify signal properties were preserved
      assert_equal -100.0, test_signal.physical_minimum
      assert_equal 100.0, test_signal.physical_maximum
      assert_equal -32768, test_signal.digital_minimum
      assert_equal 32767, test_signal.digital_maximum
    ensure
      output_file.close
      output_file.unlink
    end
  end

  def test_edf_version
    assert_equal 0, @valid_edf_no_data_records.send("compute_offset", :version)
    assert_equal 0, @valid_edf_no_data_records.version
  end

  def test_edf_local_patient_identification
    assert_equal 8, @valid_edf_no_data_records.send("compute_offset", :local_patient_identification)
    assert_equal "", @valid_edf_no_data_records.local_patient_identification
  end

  def test_edf_local_recording_identification
    assert_equal 88, @valid_edf_no_data_records.send("compute_offset", :local_recording_identification)
    assert_equal "", @valid_edf_no_data_records.local_recording_identification
  end

  def test_edf_start_date_of_recording
    assert_equal 168, @valid_edf_no_data_records.send("compute_offset", :start_date_of_recording)
    assert_equal "31.01.85", @valid_edf_no_data_records.start_date_of_recording
  end

  def test_edf_start_date
    assert_equal Date.parse("1985-01-31"), @valid_edf_no_data_records.start_date
    assert_nil @edf_invalid_date.start_date
  end

  def test_edf_start_time_of_recording
    assert_equal 176, @valid_edf_no_data_records.send("compute_offset", :start_time_of_recording)
    assert_equal "20.14.57", @valid_edf_no_data_records.start_time_of_recording
  end

  def test_edf_number_of_bytes_in_header
    assert_equal 184, @valid_edf_no_data_records.send("compute_offset", :number_of_bytes_in_header)
    assert_equal 3840, @valid_edf_no_data_records.number_of_bytes_in_header
  end

  def test_edf_reserved
    assert_equal 192, @valid_edf_no_data_records.send("compute_offset", :reserved)
    assert_equal " " * 44, @valid_edf_no_data_records.reserved
  end

  def test_edf_number_of_data_records
    assert_equal 236, @valid_edf_no_data_records.send("compute_offset", :number_of_data_records)
    assert_equal 0, @valid_edf_no_data_records.number_of_data_records
  end

  def test_edf_duration_of_a_data_record
    assert_equal 244, @valid_edf_no_data_records.send("compute_offset", :duration_of_a_data_record)
    assert_equal 1, @valid_edf_no_data_records.duration_of_a_data_record
  end

  def test_edf_number_of_signals
    assert_equal 252, @valid_edf_no_data_records.send("compute_offset", :number_of_signals)
    assert_equal 14, @valid_edf_no_data_records.number_of_signals
  end

  # Signal Header Tests

  def test_edf_signal_labels
    assert_equal 0, @valid_edf_no_data_records.send("compute_signal_offset", :label)
    assert_equal [
      "SaO2", "H.R.", "EEG(sec)", "ECG", "EMG", "EOG(L)", "EOG(R)", "EEG",
      "THOR RES", "ABDO RES", "POSITION", "LIGHT", "NEW AIR", "OX stat"
    ], @valid_edf_no_data_records.signals.collect(&:label)
  end

  def test_edf_signal_transducer_types
    assert_equal 16, @valid_edf_no_data_records.send("compute_signal_offset", :transducer_type)
    assert_equal [""] * 14, @valid_edf_no_data_records.signals.collect(&:transducer_type)
  end

  def test_edf_signal_physical_dimensions
    assert_equal 96, @valid_edf_no_data_records.send("compute_signal_offset", :physical_dimension)
    assert_equal [
      "", "", "uV", "mV", "uV", "uV", "uV", "uV", "", "", "", "", "uV", ""
    ], @valid_edf_no_data_records.signals.collect(&:physical_dimension)
  end

  def test_edf_signal_physical_minimums
    assert_equal 104, @valid_edf_no_data_records.send("compute_signal_offset", :physical_minimum)
    assert_equal [
      0.0, 0.0, -125.0, -1.25, -31.25, -125.0, -125.0, -125.0, 1.0, 1.0, 0.0, 0.0, -125.0, 0.0
    ], @valid_edf_no_data_records.signals.collect(&:physical_minimum)
  end

  def test_edf_signal_physical_maximums
    assert_equal 112, @valid_edf_no_data_records.send("compute_signal_offset", :physical_maximum)
    assert_equal [
      100.0, 250.0, 125.0, 1.25, 31.25, 125.0, 125.0, 125.0, -1.0, -1.0, 3.0, 1.0, 125.0, 3.0
    ], @valid_edf_no_data_records.signals.collect(&:physical_maximum)
  end

  def test_edf_signal_digital_minimums
    assert_equal 120, @valid_edf_no_data_records.send("compute_signal_offset", :digital_minimum)
    assert_equal [
      -32_768, -32_768, -128, -128, -128, -128, -128, -128, -128, -128, 0, 0, -128, 0
    ], @valid_edf_no_data_records.signals.collect(&:digital_minimum)
  end

  def test_edf_signal_digital_maximums
    assert_equal 128, @valid_edf_no_data_records.send("compute_signal_offset", :digital_maximum)
    assert_equal [
      32_767, 32_767, 127, 127, 127, 127, 127, 127, 127, 127, 3, 1, 127, 3
    ], @valid_edf_no_data_records.signals.collect(&:digital_maximum)
  end

  def test_edf_signal_prefilterings
    assert_equal 136, @valid_edf_no_data_records.send("compute_signal_offset", :prefiltering)
    assert_equal [""] * 14, @valid_edf_no_data_records.signals.collect(&:prefiltering)
  end

  def test_edf_signal_samples_per_data_records
    assert_equal 216, @valid_edf_no_data_records.send("compute_signal_offset", :samples_per_data_record)
    assert_equal [
      1, 1, 125, 125, 125, 50, 50, 125, 10, 10, 1, 1, 10, 1
    ], @valid_edf_no_data_records.signals.collect(&:samples_per_data_record)
  end

  def test_edf_signal_reserved_areas
    assert_equal 224, @valid_edf_no_data_records.send("compute_signal_offset", :reserved_area)
    assert_equal [" " * 32] * 14, @valid_edf_no_data_records.signals.collect(&:reserved_area)
  end

  def test_loads_single_epoch
    # Load the first epoch (0 index), with the epoch size being 1 second
    @valid_edf_with_three_signals.load_epoch(0, 1)
    @signal_one   = @valid_edf_with_three_signals.signals[0]
    @signal_two   = @valid_edf_with_three_signals.signals[1]
    @signal_three = @valid_edf_with_three_signals.signals[2]
    assert_equal [0, 1], @signal_one.digital_values
    assert_equal [50.000762951094835, 50.002288853284504], @signal_one.physical_values
    assert_equal [0, 1], @signal_two.digital_values
    assert_equal [125.00190737773708, 125.00572213321126], @signal_two.physical_values
    assert_equal [0, 1, 2, 3], @signal_three.digital_values
    assert_equal [
      0.49019607843136725, 1.470588235294116, 2.4509803921568647, 3.4313725490196134
    ], @signal_three.physical_values
  end

  def test_loads_last_epoch
    # Load the last epoch (0 index), with the epoch size being 1 second
    @valid_edf_with_three_signals.load_epoch(9, 1)
    @signal_one   = @valid_edf_with_three_signals.signals[0]
    @signal_two   = @valid_edf_with_three_signals.signals[1]
    @signal_three = @valid_edf_with_three_signals.signals[2]
    assert_equal [9, nil], @signal_one.digital_values
    assert_equal [50.01449607080186, nil], @signal_one.physical_values
    assert_equal [9, nil], @signal_two.digital_values
    assert_equal [125.03624017700466, nil], @signal_two.physical_values
    assert_equal [18, 19, nil, nil], @signal_three.digital_values
    assert_equal [18.137254901960773, 19.117647058823536, nil, nil], @signal_three.physical_values
  end

  def test_loads_last_epoch_of_two_seconds
    # Load the fourth epoch (0 index), with the epoch size being 2 seconds
    @valid_edf_with_three_signals.load_epoch(3, 2)
    @signal_one   = @valid_edf_with_three_signals.signals[0]
    @signal_two   = @valid_edf_with_three_signals.signals[1]
    @signal_three = @valid_edf_with_three_signals.signals[2]
    assert_equal [6, 7, 8], @signal_one.digital_values
    assert_equal [50.00991836423285, 50.01144426642252, 50.01297016861219], @signal_one.physical_values
    assert_equal [6, 7, 8], @signal_two.digital_values
    assert_equal [125.02479591058213, 125.02861066605631, 125.03242542153048], @signal_two.physical_values
    assert_equal [12, 13, 14, 15, 16, 17], @signal_three.digital_values
    assert_equal [
      12.25490196078431, 13.235294117647072, 14.215686274509807,
      15.196078431372541, 16.176470588235304, 17.15686274509804
    ], @signal_three.physical_values
  end

  def test_should_rewrite_start_date_of_recording
    file = Tempfile.new("invalid-date-copy.edf")
    FileUtils.cp("test/support/invalid-date.edf", file.path)
    edf = Edfize::Edf.new(file.path)
    assert_equal "00.00.00", edf.start_date_of_recording
    edf.update(start_date_of_recording: "01.01.85")
    edf_new = Edfize::Edf.new(file.path) # Load new EDF to check that change is written to disk.
    assert_equal "01.01.85", edf_new.start_date_of_recording
  ensure
    file.close
    file.unlink # Deletes temporary file.
  end

  def test_should_rewrite_start_time_of_recording
    file = Tempfile.new("invalid-date-copy.edf")
    FileUtils.cp("test/support/invalid-date.edf", file.path)
    edf = Edfize::Edf.new(file.path)
    assert_equal "20.14.57", edf.start_time_of_recording
    edf.update(start_time_of_recording: "12.34.56")
    edf_new = Edfize::Edf.new(file.path) # Load new EDF to check that change is written to disk.
    assert_equal "12.34.56", edf_new.start_time_of_recording
  ensure
    file.close
    file.unlink # Deletes temporary file.
  end

  def test_find_signal
    # Create a new EDF file with test signals
    edf = Edfize::Edf.create do |e|
      e.local_patient_identification = "Test Patient"
      e.local_recording_identification = "Test Recording"
      e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
      e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
      e.duration_of_a_data_record = 1
    end

    # Create a PPG signal
    ppg_signal = Edfize::Signal.new
    ppg_signal.label = "ppg"
    ppg_signal.transducer_type = "Test Signal"
    ppg_signal.physical_dimension = "mV"
    ppg_signal.physical_minimum = -100.0
    ppg_signal.physical_maximum = 100.0
    ppg_signal.digital_minimum = -32768
    ppg_signal.digital_maximum = 32767
    ppg_signal.prefiltering = "None"
    ppg_signal.samples_per_data_record = 256
    ppg_signal.reserved_area = " " * 32
    edf.signals << ppg_signal

    # Create another signal
    ecg_signal = Edfize::Signal.new
    ecg_signal.label = "ecg"
    ecg_signal.transducer_type = "Test Signal"
    ecg_signal.physical_dimension = "mV"
    ecg_signal.physical_minimum = -100.0
    ecg_signal.physical_maximum = 100.0
    ecg_signal.digital_minimum = -32768
    ecg_signal.digital_maximum = 32767
    ecg_signal.prefiltering = "None"
    ecg_signal.samples_per_data_record = 256
    ecg_signal.reserved_area = " " * 32
    edf.signals << ecg_signal

    # Test finding signals
    found_signal = edf.signals.find_by_label(:ppg)
    assert_equal "ppg", found_signal.label
    assert_equal ppg_signal, found_signal

    found_signal = edf.signals.find_by_label(:ecg)
    assert_equal "ecg", found_signal.label
    assert_equal ecg_signal, found_signal

    # Test finding non-existent signal
    found_signal = edf.signals.find_by_label(:xyz)
    assert_nil found_signal
  end

  def test_delete_signal
    # Create a new EDF file with test signals
    edf = Edfize::Edf.create do |e|
      e.local_patient_identification = "Test Patient"
      e.local_recording_identification = "Test Recording"
      e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
      e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
      e.duration_of_a_data_record = 1
    end

    # Create a PPG signal
    ppg_signal = Edfize::Signal.new
    ppg_signal.label = "ppg"
    ppg_signal.transducer_type = "Test Signal"
    ppg_signal.physical_dimension = "mV"
    ppg_signal.physical_minimum = -100.0
    ppg_signal.physical_maximum = 100.0
    ppg_signal.digital_minimum = -32768
    ppg_signal.digital_maximum = 32767
    ppg_signal.prefiltering = "None"
    ppg_signal.samples_per_data_record = 256
    ppg_signal.reserved_area = " " * 32
    edf.signals << ppg_signal

    # Create another signal
    ecg_signal = Edfize::Signal.new
    ecg_signal.label = "ecg"
    ecg_signal.transducer_type = "Test Signal"
    ecg_signal.physical_dimension = "mV"
    ecg_signal.physical_minimum = -100.0
    ecg_signal.physical_maximum = 100.0
    ecg_signal.digital_minimum = -32768
    ecg_signal.digital_maximum = 32767
    ecg_signal.prefiltering = "None"
    ecg_signal.samples_per_data_record = 256
    ecg_signal.reserved_area = " " * 32
    edf.signals << ecg_signal

    # Test deleting signals
    assert_equal 2, edf.signals.size
    assert edf.signals.delete(:ppg)
    assert_equal 1, edf.signals.size
    assert_nil edf.signals.find_by_label(:ppg)
    assert_equal "ecg", edf.signals.first.label

    # Test deleting non-existent signal
    refute edf.signals.delete(:xyz)
    assert_equal 1, edf.signals.size
  end

  def test_write_modified_edf_file
    # Create a new EDF file with test signals
    edf = Edfize::Edf.create do |e|
      e.local_patient_identification = "Test Patient"
      e.local_recording_identification = "Test Recording"
      e.start_date_of_recording = Time.now.strftime("%d.%m.%y")
      e.start_time_of_recording = Time.now.strftime("%H.%M.%S")
      e.duration_of_a_data_record = 1
    end

    # Create a PPG signal
    ppg_signal = Edfize::Signal.new
    ppg_signal.label = "ppg"
    ppg_signal.transducer_type = "Test Signal"
    ppg_signal.physical_dimension = "mV"
    ppg_signal.physical_minimum = -100.0
    ppg_signal.physical_maximum = 100.0
    ppg_signal.digital_minimum = -32768
    ppg_signal.digital_maximum = 32767
    ppg_signal.prefiltering = "None"
    ppg_signal.samples_per_data_record = 4
    ppg_signal.reserved_area = " " * 32
    ppg_signal.digital_values = [0, 1, 2, 3]
    edf.signals << ppg_signal

    # Create another signal
    ecg_signal = Edfize::Signal.new
    ecg_signal.label = "ecg"
    ecg_signal.transducer_type = "Test Signal"
    ecg_signal.physical_dimension = "mV"
    ecg_signal.physical_minimum = -100.0
    ecg_signal.physical_maximum = 100.0
    ecg_signal.digital_minimum = -32768
    ecg_signal.digital_maximum = 32767
    ecg_signal.prefiltering = "None"
    ecg_signal.samples_per_data_record = 4
    ecg_signal.reserved_area = " " * 32
    ecg_signal.digital_values = [4, 5, 6, 7]
    edf.signals << ecg_signal

    # Create a temporary file for writing
    output_file = Tempfile.new(["test-modified", ".edf"])
    begin
      # Modify the signals
      edf.signals.delete(:ppg)
      ecg_signal = edf.signals.find_by_label(:ecg)
      ecg_signal.digital_values = [8, 9, 10, 11]

      # Write the modified EDF file
      edf.write(output_file.path)

      # Read back the written file
      written_edf = Edfize::Edf.new(output_file.path)
      written_edf.load_signals

      # Verify the signals
      assert_equal 2, written_edf.signals.size # 1 signal + 1 EDF Annotations signal
      assert_nil written_edf.signals.find_by_label(:ppg)
      written_ecg = written_edf.signals.find_by_label(:ecg)
      assert_equal [8, 9, 10, 11], written_ecg.digital_values
    ensure
      output_file.close
      output_file.unlink
    end
  end

  def test_write_edf_file
    # Load an existing EDF file
    original_edf = Edfize::Edf.new("test/support/simulated-01.edf")

    # Create a temporary file for writing
    output_file = Tempfile.new(["test-write", ".edf"])
    begin
      # Write the EDF file
      original_edf.write(output_file.path)

      # Read back the written file
      written_edf = Edfize::Edf.new(output_file.path)

      # Compare header fields
      Edfize::Edf::HEADER_CONFIG.each_key do |field|
        next if field == :reserved # Skip reserved as it will be different (EDF+C/D)

        assert_equal original_edf.send(field), written_edf.send(field),
                     "Header field #{field} does not match"
      end

      # Verify EDF+ format in reserved area
      assert_match(/^EDF\+[CD]/, written_edf.reserved.strip)

      # Compare signal headers
      original_edf.signals.each_with_index do |orig_signal, i|
        written_signal = written_edf.signals[i]
        next if orig_signal.label == "EDF Annotations" # Skip annotations signal

        Edfize::Signal::SIGNAL_CONFIG.each_key do |field|
          assert_equal orig_signal.send(field), written_signal.send(field),
                       "Signal #{i} field #{field} does not match"
        end

        # Compare digital values
        written_signal = written_edf.signals[i]
        next if orig_signal.label == "EDF Annotations" # Skip annotations signal

        assert_equal orig_signal.digital_values, written_signal.digital_values,
                     "Digital values for signal #{i} do not match"
      end
    ensure
      output_file.close
      output_file.unlink
    end
  end
end