Hardware folder (Verilog)
- rtl/day12_top.v: top-level wrapper for the Day 12 accelerator 
- rtl/accelerator.v: streaming area-check accelerator

Constraints
- constraints/kv260.xdc: KV260-safe constraints (clock + relaxes unconstrained-I/O DRCs). Use this only for synthesis/implementation bring-up; assign real pins before running on hardware.

Notes:
- All hardware files are plain Verilog.
- The top-level module exposes clock/reset and a streaming interface; integrate into KV260 petalinux/PL flow.
