`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ricardo C.
// 
// Create Date: 12/31/2025 11:14:22 PM
// Design Name: AOC 2026
// Module Name: accelerator.v
// Project Name: Day - 12
// Target Devices: KV260
// Description: Verilog accelerator for AoC Day 12 - Presents
// 
//////////////////////////////////////////////////////////////////////////////////

module accelerator (
    input  wire clk,
    input  wire rst_n,

    input  wire in_valid,
    input  wire [31:0] in_data,
    output wire in_ready,

    output wire out_valid,
    output wire [31:0] out_data,
    input  wire out_ready
);

// Parameters
parameter MAX_SHAPES = 8;
parameter MAX_REGION_W = 64;
parameter MAX_REGION_H = 64;
parameter MAX_SHAPE_CELLS = 16;

// Streaming area-only implementation (self-contained; no extra core files).
//
// Input stream format:
//   word0: [15:0] num_shapes, [31:16] num_regions
//   shapes: for each shape:
//     shape header: [7:0] w, [15:8] h, [23:16] num_cells, [31:24] reserved
//     then ceil(num_cells/4) words of packed cell coords (ignored here)
//   regions: for each region:
//     region header: [15:0] w, [31:16] h
//     quantities word0: q0 q1 q2 q3 (bytes)
//     quantities word1: q4 q5 q6 q7 (bytes)
//
// Output:
//   single word = count of regions where sum(shape_cells[i]*quantity[i]) <= w*h

function integer clog2;
    input integer value;
    integer v;
    begin
        v = value - 1;
        for (clog2 = 0; v > 0; clog2 = clog2 + 1)
            v = v >> 1;
    end
endfunction

localparam integer SHAPE_IDX_W = clog2(MAX_SHAPES + 1);

localparam ST_IDLE        = 3'd0;
localparam ST_LOAD_SHAPES = 3'd1;
localparam ST_LOAD_REGION = 3'd2;
localparam ST_OUTPUT      = 3'd3;

reg [2:0] state;

reg [15:0] num_shapes;
reg [15:0] num_regions;
reg [15:0] regions_seen;
reg [31:0] regions_that_fit;

// shape metadata (only num_cells needed for area check)
reg [7:0] shape_num_cells [0:MAX_SHAPES-1];
reg [SHAPE_IDX_W-1:0] shape_idx;
reg [1:0] shape_substate; // 0=header, 1=consume cell words
reg [7:0] cells_remaining;

// region parsing (one at a time)
reg [15:0] region_w;
reg [15:0] region_h;
reg [7:0] region_q [0:MAX_SHAPES-1];
reg [1:0] region_substate; // 0=hdr,1=q0-3,2=q4-7

integer i;

wire accept = in_valid && in_ready;

// Determine if we're about to transition out of current input state
// This prevents accepting data on the transition cycle
wire shape_loading_done = (shape_idx >= num_shapes);
wire region_loading_done = (regions_seen >= num_regions);

assign in_ready =
    (state == ST_IDLE)        ? 1'b1 :
    (state == ST_LOAD_SHAPES) ? !shape_loading_done :
    (state == ST_LOAD_REGION) ? !region_loading_done :
    1'b0; // stall input while outputting result

assign out_valid = (state == ST_OUTPUT);
assign out_data  = regions_that_fit;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        num_shapes <= 16'd0;
        num_regions <= 16'd0;
        regions_seen <= 16'd0;
        regions_that_fit <= 32'd0;
        shape_idx <= {SHAPE_IDX_W{1'b0}};
        shape_substate <= 2'd0;
        cells_remaining <= 8'd0;
        region_substate <= 2'd0;
        region_w <= 16'd0;
        region_h <= 16'd0;
        for (i = 0; i < MAX_SHAPES; i = i + 1) begin
            shape_num_cells[i] <= 8'd0;
            region_q[i] <= 8'd0;
        end
    end else begin
        case (state)
            ST_IDLE: begin
                if (accept) begin
                    num_shapes <= (in_data[15:0] > MAX_SHAPES) ? MAX_SHAPES : in_data[15:0];
                    num_regions <= in_data[31:16];
                    regions_seen <= 16'd0;
                    regions_that_fit <= 32'd0;
                    shape_idx <= {SHAPE_IDX_W{1'b0}};
                    shape_substate <= 2'd0;
                    cells_remaining <= 8'd0;
                    region_substate <= 2'd0;
                    state <= ST_LOAD_SHAPES;
                end
            end

            ST_LOAD_SHAPES: begin
                if (shape_idx >= num_shapes) begin
                    region_substate <= 2'd0;
                    state <= ST_LOAD_REGION;
                end else if (accept) begin
                    case (shape_substate)
                        2'd0: begin
                            shape_num_cells[shape_idx] <= in_data[23:16];
                            cells_remaining <= in_data[23:16];
                            if (in_data[23:16] == 0) begin
                                shape_idx <= shape_idx + 1'b1;
                                shape_substate <= 2'd0;
                            end else begin
                                shape_substate <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // consume packed cell coords words; ignore contents
                            if (cells_remaining <= 8'd4) begin
                                cells_remaining <= 8'd0;
                                shape_idx <= shape_idx + 1'b1;
                                shape_substate <= 2'd0;
                            end else begin
                                cells_remaining <= cells_remaining - 8'd4;
                                shape_substate <= 2'd1;
                            end
                        end
                        default: shape_substate <= 2'd0;
                    endcase
                end
            end

            ST_LOAD_REGION: begin
                if (regions_seen >= num_regions) begin
                    state <= ST_OUTPUT;
                end else if (accept) begin
                    case (region_substate)
                        2'd0: begin
                            region_w <= in_data[15:0];
                            region_h <= in_data[31:16];
                            for (i = 0; i < MAX_SHAPES; i = i + 1) begin
                                region_q[i] <= 8'd0;
                            end
                            region_substate <= 2'd1;
                        end
                        2'd1: begin
                            region_q[0] <= in_data[7:0];
                            if (MAX_SHAPES > 1) region_q[1] <= in_data[15:8];
                            if (MAX_SHAPES > 2) region_q[2] <= in_data[23:16];
                            if (MAX_SHAPES > 3) region_q[3] <= in_data[31:24];
                            region_substate <= 2'd2;
                        end
                        2'd2: begin
                            if (MAX_SHAPES > 4) region_q[4] <= in_data[7:0];
                            if (MAX_SHAPES > 5) region_q[5] <= in_data[15:8];
                            if (MAX_SHAPES > 6) region_q[6] <= in_data[23:16];
                            if (MAX_SHAPES > 7) region_q[7] <= in_data[31:24];

                            // Compute fit and advance to next region
                            begin : area_calc_block
                                reg [31:0] ra;
                                reg [31:0] ta;
                                integer k;
                                ra = region_w * region_h;
                                ta = 32'd0;
                                // region_q[] is only populated for q0..q3 at this point.
                                for (k = 0; (k < MAX_SHAPES) && (k < 4); k = k + 1) begin
                                    ta = ta + (shape_num_cells[k] * region_q[k]);
                                end
                                // Add q4..q7 from the current word (since region_q updates are nonblocking)
                                if (MAX_SHAPES > 4) ta = ta + (shape_num_cells[4] * in_data[7:0]);
                                if (MAX_SHAPES > 5) ta = ta + (shape_num_cells[5] * in_data[15:8]);
                                if (MAX_SHAPES > 6) ta = ta + (shape_num_cells[6] * in_data[23:16]);
                                if (MAX_SHAPES > 7) ta = ta + (shape_num_cells[7] * in_data[31:24]);

                                if (ta <= ra) begin
                                    regions_that_fit <= regions_that_fit + 1'b1;
                                end
                            end

                            regions_seen <= regions_seen + 1'b1;
                            region_substate <= 2'd0;
                        end
                        default: region_substate <= 2'd0;
                    endcase
                end
            end

            ST_OUTPUT: begin
                if (out_valid && out_ready) begin
                    state <= ST_IDLE;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
