# advent_of_fpga_day12

Advent of FPGA — Day 12

Problem link: https://adventofcode.com/2025/day/12

Overview
This repository contains the FPGA implementation and supporting software for Advent of Code 2025 Day 12, targeted to run on the KV260 evaluation board. This project was scaffolded using template ideas from bradylindell/advent_of_fpga — thanks to @bradylindell for the template inspiration.

Structure
- hardware/ — Verilog hardware 
  - rtl/ — top-level and accelerator Verilog sources
- software/ — preprocessing and host-side helpers
  - preprocessing/ — scripts to convert AoC input into a format suitable for FPGA
- results/ — 

Introduction

Day 12 is implemented as an FPGA accelerator that performs the combinational/streaming portions of the puzzle algorithm on the KV260. The software performs input parsing and small control tasks, while the FPGA implements the heavy dataflow or parallel parts of the solution.

Approach
- Preprocess AoC input on the host into a compact binary format suitable for DMA to the KV260.
- Implement a streaming accelerator in Verilog that processes the preprocessed data in hardware with minimal host interaction.
- Use the KV260 platform for synthesis and testing; target resources are kept conservative to fit.

Implementation
- Verilog modules are located under hardware/rtl.
- Preprocessing scripts are located under software/preprocessing; they output binary arrays or simple CSV suitable for the board’s DMA engine.
- The top-level Verilog is a lightweight wrapper exposing a simple AXI4-Stream interface.

Results


Conclusion
This repo provides a starting point for implementing Advent of Code Day 12 on the KV260 using an FPGA-first approach.
