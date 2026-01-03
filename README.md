# Advent of FPGA — Day 12

FPGA accelerator for **[Advent of Code 2025 — Day 12](https://adventofcode.com/2025/day/12)**, targeting the **Kria KV260 (xck26)**.

This project focuses on a streaming, hardware-friendly core that performs the “area feasibility” portion of the puzzle: for each region, compute the total requested area and compare it to the available region area.

## Repo structure

- `hardware/`
  - `rtl/`
    - `day12_top.v`: top-level wrapper
    - `accelerator.v`: streaming area-check accelerator
  - `testbench/`
    - `day12_tb.v`: simulation testbench
  - `constraints/`
    - `kv260.xdc`: clock constraint + relaxed DRC severities for bring-up (not safe for real I/O pinout)
- `software/preprocessing/`
  - `preprocess_day12.py`: converts AoC input text → binary stream (`output.bin`)
  - `bin_to_hex.py`: converts binary stream → `$readmemh` hex file (`test_data.hex`)
- `results/`: saved simulation logs + Vivado reports/screenshots

## Build instructions

### 1) Preprocess the AoC input

From `software/preprocessing/`:

```bash
python3 preprocess_day12.py input_c.txt output.bin
python3 bin_to_hex.py output.bin test_data.hex
```

This produces `test_data.hex` (one 32-bit word per line) for the Verilog testbench.

### 2) Run simulation (Vivado XSim)

Compile:

- `hardware/rtl/*.v`
- `hardware/testbench/day12_tb.v`

Make sure `test_data.hex` is in the simulator working directory.      
The testbench uses:

- `$readmemh("test_data.hex", test_data);`

### 3) Run synthesis/implementation (Vivado)

Top module: `day12_top`

Constraint file: `hardware/constraints/kv260.xdc`

> Note: `kv260.xdc` intentionally relaxes UCIO/NSTD/KLOC checks to allow implementation without a real pinout. **Do not use this unchanged to build a hardware bitstream.**

## Introduction 

The input consists of:

- **Shapes**: small grids of `#`/`.` (each `#` is one unit cell of area)
- **Regions**: a rectangular region `WxH` with a quantity requested for each shape

For each region, we compute:

- Available area: `region_area = W * H`
- Required area: `total_area = Σ (shape_cells[i] * quantity[i])`

The accelerator counts how many regions satisfy `total_area <= region_area`.

## Approach

The design is FPGA-simple:

- Host preprocessing parses the text input and emits a packed 32-bit word stream.
- Hardware streams the words in once, does a small amount of stateful parsing, performs a few multiplies/adds per region, and outputs a single 32-bit result.

This avoids storing full shape geometry in BRAM and keeps the datapath tiny.

## Implementation

### Stream format

As implemented in `hardware/rtl/accelerator.v`:

- **Word 0**: `[15:0] num_shapes`, `[31:16] num_regions`
- **Shapes** (for each shape):
  - shape header: `[7:0] w, [15:8] h, [23:16] num_cells, [31:24] reserved`
  - packed cell coords: `ceil(num_cells/4)` words (currently ignored by the accelerator; only `num_cells` is used)
- **Regions** (for each region):
  - region header: `[15:0] w, [31:16] h`
  - quantities word 0: `q0 q1 q2 q3` (bytes)
  - quantities word 1: `q4 q5 q6 q7` (bytes; unused entries are 0)

The interface is a ready/valid stream (`in_valid/in_ready/in_data`) with a single-word output (`out_valid/out_ready/out_data`).

## Results

### Simulation

From `results/day12_tb_result.txt` (100 MHz sim, 3019 input words):

- Output: **595** (regions fit)

### Utilization (KV260 / xck26-sfvc784-2LV-c)

From `results/synthesis/day12_top_utilization_synth.rpt`:

- CLB LUTs: **789** (0.67%)
- Registers: **183** (0.08%)
- DSPs: **1**
- BRAM/URAM: **0**

### Timing 

From `results/implementation/day12_top_timing_summary_routed.rpt` with a 100 MHz constraint:

- **WNS: 1.500 ns** 

## Conclusion

This repo demonstrates a minimal KV260 streaming accelerator workflow:

- Preprocess AoC text input → packed stream
- Stream into RTL core with ready/valid
- Get a single 32-bit answer out

Next step is integrating the stream ports into real hardware and providing a proper KV260 pinout + I/O standards.
