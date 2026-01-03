`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ricardo C.
// 
// Create Date: 12/31/2025 11:04:45 PM
// Design Name: AOC 2026
// Module Name: day12_top.v
// Project Name: Day - 12
// Target Devices: KV260
// Description: Top-level wrapper for Day 12 accelerator
// 
//////////////////////////////////////////////////////////////////////////////////

module day12_top #(
    parameter MAX_REGION_W = 64,
    parameter MAX_REGION_H = 64
) (
    input  wire clk,
    input  wire rst_n,

    // inputs
    input  wire in_valid,
    input  wire [31:0] in_data,
    output wire in_ready,

    // outputs
    output wire out_valid,
    output wire [31:0] out_data,
    input  wire out_ready
);

// Instantiation of accelerator
accelerator #(
    .MAX_REGION_W(MAX_REGION_W),
    .MAX_REGION_H(MAX_REGION_H)
) accel (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_data(in_data),
    .in_ready(in_ready),
    .out_valid(out_valid),
    .out_data(out_data),
    .out_ready(out_ready)
);

endmodule