`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ricardo C. 
// 
// Create Date: 12/31/2025 11:44:53 PM
// Design Name: AOC 2026
// Module Name: day12_tb.v
// Project Name: Day - 12
// Target Devices: KV260
// Description: Testbench for Day 12 accelerator - Tests the accelerator with puzzle 
//                                                 input data from AoC Day 12
// 
//////////////////////////////////////////////////////////////////////////////////

module day12_tb;

// Parameters
parameter CLK_PERIOD = 10.0; // 100 MHz

// (No solver-mode knobs; accelerator is area-only.)
// Signals
reg clk;
reg rst_n;
reg in_valid;
reg [31:0] in_data;
wire in_ready;
wire out_valid;
wire [31:0] out_data;
reg out_ready;

// Test data - Load from preprocessed hex file 

parameter MAX_TEST_WORDS = 10000; // max input size
reg [31:0] test_data [0:MAX_TEST_WORDS-1];
integer i;
integer test_idx;
integer cycles;
integer num_words;
integer fd;
reg [8*32-1:0] line_buf;
reg [31:0] tmp_hex;
integer nconv;

// Instantiation of DUT
day12_top #(
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_data(in_data),
    .in_ready(in_ready),
    .out_valid(out_valid),
    .out_data(out_data),
    .out_ready(out_ready)
);

// Clock generation
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    for (i = 0; i < MAX_TEST_WORDS; i = i + 1) begin
        test_data[i] = 32'h00000000;
    end
    
    $readmemh("test_data.hex", test_data);
    
    if (test_data[0] == 32'h00000000 && test_data[1] == 32'h00000000) begin
        $display("ERROR: Could not load test_data.hex");
        $display("Please run: python3 bin_to_hex.py output.bin test_data.hex");
        $display("Or insert test_data.hex to simulation directory");
        $finish;
    end

    num_words = 0;
    fd = $fopen("test_data.hex", "r");
    if (fd == 0) begin
        $display("ERROR: Could not open test_data.hex");
        $finish;
    end
    while (!$feof(fd) && num_words < MAX_TEST_WORDS) begin
        if ($fgets(line_buf, fd)) begin
            nconv = $sscanf(line_buf, "%h", tmp_hex);
            if (nconv == 1) num_words = num_words + 1;
        end
    end
    $fclose(fd);

    if (num_words == 0 || num_words > MAX_TEST_WORDS) begin
        $display("ERROR: Invalid num_words=%0d", num_words);
        $finish;
    end

    $display("Loaded %0d words from test_data.hex", num_words);
end

// Test stimulus
initial begin
    rst_n = 0;
    in_valid = 0;
    in_data = 32'h0;
    out_ready = 1;
    test_idx = 0;
    cycles = 0;
    
    #(CLK_PERIOD * 5);
    rst_n <= 1'b1;
    #(CLK_PERIOD * 2);
    
    $display("=== Day 12 Accelerator Testbench ===");
    $display("Time: %0t - Starting test", $time);
    $display("Sending %0d words of test data", num_words);
    
    while (!in_ready) begin
        @(posedge clk);
    end
    $display("Time: %0t - Accelerator reports in_ready=1, sending header", $time);
    
    in_valid = 1'b0;
    while (test_idx < num_words) begin
        // Deassert in_valid while waiting for in_ready to prevent spurious accepts
        in_valid = 1'b0;
        while (!in_ready) @(posedge clk);
        @(negedge clk);
        in_valid = 1'b1;
        in_data  = test_data[test_idx];
        @(posedge clk);
        if (in_ready) begin
            if (test_idx < 5) begin
                $display("Time: %0t - Sending data[%0d] = 0x%08h", $time, test_idx, test_data[test_idx]);
            end
            test_idx = test_idx + 1;
        end
    end

    @(negedge clk);
    in_valid = 1'b0;
    $display("Time: %0t - All input data sent, waiting for result...", $time);
    
    while (!out_valid) begin
        @(posedge clk);
        cycles = cycles + 1;
        if (cycles % 1000 == 0) begin
            $display("Time: %0t - Waiting... cycles: %0d, out_valid: %b, in_ready: %b, in_valid: %b", 
                     $time, cycles, out_valid, in_ready, in_valid);
        end
        if (cycles > 100000) begin
            $display("ERROR: Timeout waiting for output after %0d cycles", cycles);
            $display("  in_ready: %b, in_valid: %b", in_ready, in_valid);
            $finish;
        end
    end
        
    $display("Time: %0t - Received result: %0d regions fit", $time, out_data);
    
    #(CLK_PERIOD * 10);
    $display("=== Test Complete ===");
    $finish;
end

// Monitor 
always @(posedge clk) begin
    if (out_valid && out_ready) begin
        $display("Time: %0t - Output valid: %0d", $time, out_data);
    end
end

// Timeout check
initial begin
    #(CLK_PERIOD * 50000);
    $display("ERROR: Testbench timeout");
    $finish;
end

endmodule


