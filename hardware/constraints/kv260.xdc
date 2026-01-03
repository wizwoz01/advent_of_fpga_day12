# KV260 / Kria K26 SOM - minimal constraints for this repo
#
# IMPORTANT:
# - This file intentionally DOES NOT assign PACKAGE_PINs for top-level data ports.
#
#  this file provides:
# - A clock constraint on the `clk` port (defaulting to 100 MHz).
# - Downgrades "unconstrained I/O" and "missing IOSTANDARD" DRCs to warnings so implementation can run
#   even without LOC/IOSTANDARD assignments.
# - Clears any previously-applied PACKAGE_PIN/IOSTANDARD assignments for these top-level ports.

## Clock (assume 100 MHz; adjust to match actual PL clock)
create_clock -name clk -period 10.000 [get_ports clk]
set_false_path -from [get_ports rst_n]


reset_property PACKAGE_PIN  [get_ports {in_data[*]}]
reset_property IOSTANDARD   [get_ports {in_data[*]}]
reset_property PACKAGE_PIN  [get_ports {out_data[*]}]
reset_property IOSTANDARD   [get_ports {out_data[*]}]
reset_property PACKAGE_PIN  [get_ports {in_valid in_ready out_valid out_ready clk rst_n}]
reset_property IOSTANDARD   [get_ports {in_valid in_ready out_valid out_ready clk rst_n}]

## Allow implementation without pin/IOSTANDARD assignments (simulation/IP-only flow)
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]  ;# Unconstrained logical ports
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]  ;# Unspecified I/O standard

## Downgrading this lets implementation continue, but such placement is NOT usable on real hardware.
set_property SEVERITY {Warning} [get_drc_checks KLOC-1]

