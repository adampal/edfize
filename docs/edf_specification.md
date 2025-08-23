# EDF+ Specification

> The specification is also in the original article as published by Elsevier:  
> **Bob Kemp and Jesus Olivan.** *European data format 'plus' (EDF+), an EDF-alike standard format for the exchange of physiological data.* Clinical Neurophysiology, 114 (2003): 1755–1761.

---

## Acknowledgement

Many EDF users suggested developing something like EDF+. A proposal was made in the summer and the specification was finalized in December 2002. We appreciate constructive discussions with Stig Hanssen, Peter Jacobi, Kevin Menningen, Garðar Þorvarðsson, Thomas Penzel, Marco Roessen, Andreas Robinson and Alpo Värri, mainly on and around Yahoo's EDF users group.

---

## Contents

1. [Introduction](#1-introduction)  
2. [The EDF+ protocol](#2-the-edf-protocol)  
   2.1. [EDF+ compared to EDF](#21-edf-compared-to-edf)  
   2.1.1. [Header](#211-the-edf-header)  
   2.1.2. [Data records](#212-the-edf-data-records)  
   2.1.3. [Additional specifications](#213-additional-specifications-in-edf)  
   2.2. [Annotations for text, time-keeping, events and stimuli](#22-annotations-for-text-time-keeping-events-and-stimuli)  
   2.2.1. [The `EDF Annotations` signal](#221-the-edf-annotations-signal)  
   2.2.2. [Time-stamped Annotations Lists (TALs)](#222-time-stamped-annotations-lists-tals-in-an-edf-annotations-signal)  
   2.2.3. [Annotations in a TAL](#223-annotations-in-a-tal)  
   2.2.4. [Time keeping of data records](#224-time-keeping-of-data-records)  
   2.3. [Analysis results](#23-analysis-results-in-edf)  
3. [Examples](#3-examples)  
   3.1. [Auditory EP recording](#31-auditory-ep-recording)  
   3.2. [Sleep PSG and MSLT](#32-sleep-recording-psg-with-mslt)  
   3.3. [Sleep scoring](#33-sleep-scoring)  
   3.4. [Neurophysiology](#34-a-large-neurophysiological-session)  
   3.5. [Intra-operative monitoring](#35-intra-operative-monitoring)  
   3.6. [Routine EEG](#36-routine-eeg)  
   3.7. [Motor Nerve Conduction file](#37-the-motor-nerve-conduction-file)

---

## 1. Introduction

After its introduction in 1992, the European Data Format (EDF) became the standard for EEG and PSG (sleep) recordings. Users highlighted limitations for other fields (myography, evoked potentials, cardiology), notably that EDF handles only uninterrupted recordings. EDF+ removes that limitation (allowing non-contiguous recordings) while keeping other EDF specifications intact, standardizing labels, and adding storage for annotations and analysis results.

Using EDF+, signals, annotations, and events recorded in one session with one system can be kept together in one file. EDF+ can also store annotations/events only, without signals. Multiple EDF+ files can be used per study (e.g., raw signals/annotations; derived hypnogram; alternate technician scoring).

**Compatibility:** EDF+ permits several **non-contiguous** recordings in one file (the only incompatibility with EDF). Old EDF viewers still display EDF+ as continuous. When possible for EEG/PSG, prefer continuous EDF+.

Because EDF+ is close to EDF, software can be developed by extending existing EDF code.

---

## 2. The EDF+ protocol

EDF+ is based on EDF. Read the EDF specs first. Below are the differences and the EDF+ annotation mechanism.

**Filename convention:** Signals recorded with the same technique and constant amplifier settings may be stored in one file. Different techniques, or identical techniques with different amplifier settings, must be separate files. All EDF+ files use `.edf` / `.EDF` extensions. See also §2.3.

### 2.1. EDF+ compared to EDF

A standard EDF file has a **header record** followed by **data records** (fixed-duration epochs). EDF+ uses the same structure but adds specifications. EDF-compatibility requires supporting, but not relying on, these additions.

#### 2.1.1. The EDF+ header

- The first *reserved* field (44 chars) **must start with**:
  - `EDF+C` if uninterrupted/contiguous (each record starts exactly at previous end).
  - `EDF+D` if **discontinuous** (non-contiguous).
- Time must be kept in each data record as in §2.2.4.
- The **version** field remains `0       ` (like EDF) so old viewers work. EDF+ software distinguishes continuous vs discontinuous using the reserved field.

#### 2.1.2. The EDF+ data records

- Ordinary signals are 2-byte sample series with equal intervals **within** a data record.
- EDF+ data records can be **shorter than 1 s**, and **records need not be continuous**. Records must remain in chronological order in the file.
- Sample intervals are equal within a record; the gap to the next record's first sample may differ.
- Example: in motor nerve conduction, each data record can hold one stimulus "window."
- If a file contains **no ordinary signals** (e.g., only manual sleep scores), set **duration of a data record = `0`**. Also use `0` in the degenerate case where each ordinary signal has one sample per record and the file is discontinuous (`EDF+D`).

#### 2.1.3. Additional specifications in EDF+

1. Header characters: printable US-ASCII (byte 32..126) only.  
2. `startdate` / `starttime`: digits and dot separators (`dd.mm.yy`, `hh.mm.ss`). Use **1985 as clipping year** (1985–1999 → `85–99`; 2000–2084 → `00–84`). After 2084, use full year (see item 4).  
3. **Local patient identification** starts with subfields (space-separated; spaces inside a subfield replaced, e.g., `_`):
   - Hospital admin code  
   - Sex (`F`/`M`)  
   - Birthdate `dd-MMM-yyyy` (month in English 3-letter all-caps)  
   - Patient name  
   Unknown/not applicable/anonymized → `'X'`. Example: `MCH-0234567 F 02-MAY-1951 Haagse_Harry`.  
4. **Local recording identification** starts with subfields:
   - Literal `Startdate`  
   - Startdate `dd-MMM-yyyy`  
   - Hospital investigation code (e.g., EEG or PSG number)  
   - Investigator/technician code  
   - Equipment code  
   Unknown → `'X'`. Example: `Startdate 02-MAR-2002 PSG-1234/2002 NN Telemetry03`.  
5. `digital max` > `digital min`. With negative gain, `physical max` < `physical min`. `physical max` ≠ `physical min`. For uncalibrated signals, **leave physical dimension empty** (8 spaces) but still provide different physical min/max.  
6. No digit grouping; decimal separator is a dot `.` (never a comma).  
7. Ordinary signal samples are **little-endian** 2-byte two's complement.  
8. `starttime` is local time at patient's location.  
9. Use standard texts and polarity rules: http://www.edfplus.info/specs/edftexts.html  
10. `number of data records` may be `-1` only during recording; set the correct value when closing the file.  
11. If filters applied, specify in `prefiltering` (e.g., `HP:0.1Hz LP:75Hz N:50Hz`). For analysis files, put relevant analysis parameters there.  
12. `transducer type` should specify sensor (e.g., `AgAgCl electrode`, `thermistor`).

### 2.2. Annotations for text, time-keeping, events and stimuli

EDF+ encodes annotations/events in a special signal labeled **`EDF Annotations`**. Old EDF software treats it as an "ordinary" signal but it actually carries text/time data.

#### 2.2.1. The `EDF Annotations` signal

- Labeled exactly `EDF Annotations` in the header.  
- `nr of samples in each data record` specifies how many **2-byte integers** are reserved **for characters** (byte-wise, in order).  
- Even if no annotations are present, **at least one** `EDF Annotations` signal **must exist** to carry per-record time-keeping (§2.2.4).  
- For compatibility:
  - `digital min` = `-32768`, `digital max` = `32767`  
  - `physical min` / `physical max` must be different (arbitrary values)  
  - All other header fields of this signal are spaces.

#### 2.2.2. Time-stamped Annotations Lists (TALs) in an `EDF Annotations` signal

- Annotations are grouped into **TALs**, each starting with a **timestamp**:  
  **`Onset`** `0x15` **`Duration`** `0x14`  
  where `0x15` (21) and `0x14` (20) are single bytes (unprintable ASCII).  
- **Onset**: `+` or `-` seconds relative to file startdate/time (US-ASCII `+ - . 0–9`). May include fractional seconds.  
- **Duration**: seconds (no sign). May be omitted (then **omit** its preceding `0x15` as well).  
- After the timestamp, one or more **annotations** (text) follow; each is terminated by a `0x14`. The **TAL ends** with `0x14 0x00`.  
- In each data record:
  - The **first TAL** starts at the **first byte** of the `EDF Annotations` signal.  
  - Subsequent TALs immediately follow the previous TAL's trailing `0x00`.  
  - A TAL (incl. trailing `0x00`) **must not cross** a data record boundary.  
  - Each event is annotated **once**, even if its duration spans multiple records.  
  - Unused bytes in the annotations area are **filled with `0x00`**.  
- Multiple `EDF Annotations` signals may exist if needed.

**Examples**

```
+18020Lights off20Close door200
```
- Lights off and close door at +180 s (3 minutes) after file start.

```
+1800.22125.520Apnea200
```
- Apnea starting at +1800.2 s with duration 25.5 s.

#### 2.2.3. Annotations in a TAL

- Annotation text (between `0x14` and next `0x14`) uses **UTF-8** (UCS / Unicode v3+).  
- US-ASCII control chars allowed **only** if prescribed by EDF+; TAB (`0x09`), LF (`0x0A`), CR (`0x0D`) are allowed to enable multi-line text/tables.  
- For averaging/superimposition: identical events/stimuli must use the **same unique annotation string** each time. Different events/locations must differ.  
- Annotations tied to a particular data record must be in **that** record (e.g., pre-interval stimulus).

#### 2.2.4. Time keeping of data records

- Because records may be non-contiguous, the **first annotation of the first `EDF Annotations` signal in each record is empty**; its **timestamp** specifies the record start time relative to file start.  
  - Example: `+5672020` → record starts at +567 s.  
- If ordinary signals are present, the record start time is the signals' start time.  
- If no ordinary signals are present, a **non-empty annotation immediately following** the time-keeping annotation **must specify** the event defining the record start.  
  - Example: `+3456.7892020R-wave20` → record starts at R-wave occurring +3456.789 s after file start.  
- The header's `startdate of recording` and `starttime of recording` indicate the absolute second containing the **first data record**'s start. The first TAL in the first data record always starts with `+0.X2020`, where `X` is the fractional offset (omit `.X` if zero).

### 2.3. Analysis results in EDF+

- Ideally, one session's signals/annotations/events are in **one** EDF+ file. Other sessions/equipment are in separate files with **identical patient identification** fields.  
- Derived data (averages, QRS parameters, peak latencies, sleep stages, subsets) **must** be stored as follows:
  - If original is `R.edf`, the derived file name is `RA.edf` (append any string after `R`).  
    - Example: `PSG0123_2002.edf` → `PSG0123_2002_hyp.edf`.  
  - Copy the **80-char patient-id line** from recording into analysis file.  
  - Set **startdate/time** and **number/duration of data records** to the analysis period.  
    - Example: analysis from 01:05:00–01:25:00 of a 24-h recording started 02-Aug-1999 23:00:00 → analysis file `startdate 03.08.99`, `starttime 01.05.00`.  
  - Apply **scaling** so analysis result uses a large portion of the `-32768..32767` range; set digital/physical min/max accordingly. Only if impossible, use the **standardized log transform** for floating-point values (legacy EDF viewers will show logarithmic scale).  
  - Hypnogram as ordinary signal: encode W,1,2,3,4,R,M as integers `0,1,2,3,4,5,6`; unscored epochs `9`. If as annotations, use standard texts.  
  - Document analysis method/parameters in header fields (`Recording-id`, and for signals: `Label`, `Transducer type`, `Physical dimension`, `Prefiltering`).

---

## 3. Examples

### 3.1. Auditory EP recording

Each data record has two TALs (first is the mandatory time-keeping; second is a pre-interval stimulus):

```
+02020Stimulus click 35dB both ears20Free text200
-0.06520Pre-stimulus beep 1000Hz200
+0.32020Stimulus click 35dB both ears200
+0.23520Pre-stimulus beep 1000Hz200
```

Averaging can be triggered by the unique texts `"Stimulus click 35dB both ears"` and/or `"Pre-stimulus beep 1000Hz"`.

### 3.2. Sleep recording (PSG) with MSLT

PSG (with lights-off and final wake-up annotations) is a **continuous** EDF+ file. The MSLT is a **discontinuous** EDF+ file containing only the 20-minute bed periods. Alternatively, both can be combined into one discontinuous file.

### 3.3. Sleep scoring

A typical 8–24 h EDF+ recording is ~30–300 MB. Manual analysis (apneas, limb movements, sleep stages) can be stored in a **separate** EDF+ file (~10–100 kB) that may contain one data record, one `EDF Annotations` signal, and **no ordinary signals**. Example (first 30 minutes and last minutes):

```
+02020Recording starts200
+02166020Sleep stage W200
+12020Lights off200
+6602130020Sleep stage N1200
+74220Turning from right side on back200
+9602118020Sleep stage N2200
+993.2211.220Limb movement20R+L leg200
+1019.4210.820Limb movement20R leg200
+11402130020Sleep stage N3200
+1526.82130.020Obstructive apnea200
+1603.22124.120Obstructive apnea200
+14402121020Sleep stage N2200
+16502127020Sleep stage N3200
+163420Turning from back on left side200
+1920213020Sleep stage N2200
. . . . . . . . .
. . . . . . . . .
+3010020Lights on200
+3021020Recording ends2000000000
```

### 3.4. A large neurophysiological session

- **Continuous EMG**: file with raw EMG + `EDF Annotations`. Continuous EDF+ (could also be EDF). With concentric needle, positivity at inner wire vs cannula is stored as positive value.  
- **F response**: raw EMG + annotations; data record duration = window size (e.g., 50 ms); one response per record; annotations describe stimulus timing/characteristics and may include distances/latencies.  
- **Motor Nerve Conduction Velocity** (one EMG channel): raw EMG + annotations; window per record; wrist stimulation in record 1, elbow in record 2; annotations describe stimulus timing/characteristics and measured parameters.  
- **Somatosensory EP (SSEP)** (four recorded signals): file with 5 signals (4 raw + `EDF Annotations`); data record duration = window (e.g., 100 ms); annotations describe stimulus; another EDF+ file contains 4-channel averages (odd/even sweeps in separate records) + `EDF Annotations` for stimulus and measured latencies.  
- **Visual EP**: two sagittal EEG signals during checkerboard stimulation of left/right fields; left/right averages stored in **separate** files; reproducibility → two records per file; each record 300 ms, 3 signals (2 EEG averages + annotations). Sampling starts 10 ms before stimulus; the first two TALs in the "left" file are:
  ```
  0.0002020
  0.01020Stimulus checkerboard left20
  ```

### 3.5. Intra-operative monitoring

Four (left/right) signals with alternating left/right stimulation. Option 1: store **two** EDF+ files (left/right), each with 4 electrophysiological signals + `EDF Annotations`. Option 2: one file with 9 signals (4 left + 4 right + annotations). Each record holds one response; annotations specify stimulus timing/characteristics (e.g., left/right).

### 3.6. Routine EEG

Record 10/20 electrodes vs common reference and save as such. Montages (e.g., F3-C3, T3-C3, C3-Cz, C3-O1) are created during review. Standard texts for electrode locations enable automated re-referencing. Annotations include events such as `Eyes Closed` or `Hyperventilation`.

### 3.7. The Motor Nerve Conduction file

Right Median Nerve conduction: record right Abductor Pollicis Brevis (APB) with wrist and elbow stimuli. Averaged signal and annotations are stored in **two data records** (wrist, elbow).

**Header record contains**

```
8 ascii : version of this data format (0) -> 0
80 ascii : local patient identification -> MCH-0234567 F 02-MAY-1951 Haagse_Harry
80 ascii : local recording identification -> Startdate 02-MAR-2002 EMG561 BK/JOP Sony. MNC R Median Nerve.
8 ascii : startdate of recording (dd.mm.yy) -> 17.04.01
8 ascii : starttime of recording (hh.mm.ss) -> 11.25.00
8 ascii : number of bytes in header record -> 768
44 ascii : reserved -> EDF+D
8 ascii : number of data records (-1 if unknown) -> 2
8 ascii : duration of a data record, in seconds -> 0.050
4 ascii : number of signals (ns) in data record -> 2
```

**Per-signal header fields (ns = 2 signals)**

| Field                                    | 1st Signal (R APB)      | 2nd Signal (EDF Annotations) |
|------------------------------------------|--------------------------|-------------------------------|
| `ns * 16 ascii : label`                  | `R APB`                  | `EDF Annotations`            |
| `ns * 80 ascii : transducer type`        | `AgAgCl electrodes`      | *(spaces)*                   |
| `ns * 8 ascii : physical dimension`      | `mV`                     | *(spaces)*                   |
| `ns * 8 ascii : physical minimum`        | `-100`                   | `-1`                         |
| `ns * 8 ascii : physical maximum`        | `100`                    | `1`                          |
| `ns * 8 ascii : digital minimum`         | `-2048`                  | `-32768`                     |
| `ns * 8 ascii : digital maximum`         | `2047`                   | `32767`                      |
| `ns * 80 ascii : prefiltering`           | `HP:3Hz LP:20kHz`        | *(spaces)*                   |
| `ns * 8 ascii : nr of samples / record`  | `1000`                   | `60`                         |
| `ns * 32 ascii : reserved`               | *(spaces)*               | *(spaces)*                   |

**Each data record contains**

- `1000 × 2-byte` integer: **R APB** samples  
- `60 × 2-byte` integer: **EDF Annotations**

**TALs**

Record 1:
```
+02020Stimulus right wrist 0.2ms x 8.2mA at 6.5cm from recording site20Response 7.2mV at 3.8ms20
```

Record 2:
```
+102020Stimulus right elbow 0.2ms x 15.3mA at 28.5cm from recording site20Response 7.2mV at 7.8ms (55.0m/s)20
```

Because these TALs are <100 chars per record, the header reserves 120 chars (60 "samples") for the `EDF Annotations` signal.

**Optional internal structure (example using XML inside separate TALs)**

```
+1020200
+1020Stimulus_elbow200
+1020<EDF_XMLnote>
<Stimulus_elbow><duration unit="ms">0.2</duration>
<intensity mode="current" unit="mA">15.3</intensity>
<position>right elbow</position>
<distance mode="stimulus to recording" unit="cm">28.5</distance>
</Stimulus_elbow>
</EDF_XMLnote>200
+1020<EDF_XMLnote>
<measurements>
<latency unit="ms">7.8</latency>
<amplitude mode="baseline to peak" unit="mV">7.2</amplitude>
<velocity mode="segmental" unit="m/s">55.0</velocity>
</measurements>
</EDF_XMLnote>200
```