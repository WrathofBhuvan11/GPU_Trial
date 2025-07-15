`default_nettype none
`timescale 1ns/1ns
// DUT - GPU
// Top-level module for the GPU, integrating all submodules
// Interfaces with external asynchronous memory using multi-channel read/write
// Assumes program and data are pre-loaded into respective memories
// Thread count is set in the device control register before the start signal
// configurable number of cores and threads per block for flexibility
module gpu #(
    parameter DATA_MEM_ADDR_BITS = 8,        // Data memory address width (256 rows)
    parameter DATA_MEM_DATA_BITS = 8,        // Data memory data width (8-bit data)
    parameter DATA_MEM_NUM_CHANNELS = 4,     // Number of concurrent data memory channels
    parameter PROGRAM_MEM_ADDR_BITS = 8,     // Program memory address width (256 rows)
    parameter PROGRAM_MEM_DATA_BITS = 16,    // Program memory data width (16-bit instructions)
    parameter PROGRAM_MEM_NUM_CHANNELS = 1,  // Number of concurrent program memory channels
    parameter NUM_CORES = 2,                 // Number of compute cores
    parameter THREADS_PER_BLOCK = 4          // Number of threads per block
) (
    input clk,                          // Clock signal
    input reset,                        // Reset signal
    // Kernel Execution
    input start,                        // Start signal to initiate kernel execution
    output logic done,                        // Done signal when kernel execution completes
    // Device Control Register
    input logic device_control_write_enable,  // Write enable for thread count
    input logic [7:0] device_control_data,    // Thread count data
    // Program Memory Interface
    output logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid, // Program memory read requests
    output logic [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address [PROGRAM_MEM_NUM_CHANNELS-1:0], // Program memory addresses
    input logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready,  // Program memory ready signals
    input logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0], // Program memory data
    // Data Memory Interface
    output logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid,       // Data memory read requests
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0], // Data memory read addresses
    input logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready,        // Data memory read ready signals
    input logic [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0], // Data memory read data
    output logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid,      // Data memory write requests
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0], // Data memory write addresses
    output logic [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0], // Data memory write data
    input logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready        // Data memory write ready signals
);
    // Internal signals
    logic [7:0] thread_count; // Thread count from device control register
    logic [NUM_CORES-1:0] core_start; // Start signals for each core
    logic [NUM_CORES-1:0] core_reset; // Reset signals for each core
    logic [NUM_CORES-1:0] core_done;  // Done signals from each core
    logic [7:0] core_block_id [NUM_CORES-1:0]; // Block IDs for each core
    logic [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0]; // Thread counts for each core

    // LSU to Data Memory Controller Channels
    localparam NUM_LSUS = NUM_CORES * THREADS_PER_BLOCK; // Total number of LSUs
    logic [NUM_LSUS-1:0] lsu_read_valid; // LSU read requests
    logic [DATA_MEM_ADDR_BITS-1:0] lsu_read_address [NUM_LSUS-1:0]; // LSU read addresses
    logic [NUM_LSUS-1:0] lsu_read_ready; // LSU read ready signals
    logic [DATA_MEM_DATA_BITS-1:0] lsu_read_data [NUM_LSUS-1:0]; // LSU read data
    logic [NUM_LSUS-1:0] lsu_write_valid; // LSU write requests
    logic [DATA_MEM_ADDR_BITS-1:0] lsu_write_address [NUM_LSUS-1:0]; // LSU write addresses
    logic [DATA_MEM_DATA_BITS-1:0] lsu_write_data [NUM_LSUS-1:0]; // LSU write data
    logic [NUM_LSUS-1:0] lsu_write_ready; // LSU write ready signals

    // Fetcher to Program Memory Controller Channels
    localparam NUM_FETCHERS = NUM_CORES; // Total number of fetchers
    logic [NUM_FETCHERS-1:0] fetcher_read_valid; // Fetcher read requests
    logic [PROGRAM_MEM_ADDR_BITS-1:0] fetcher_read_address [NUM_FETCHERS-1:0]; // Fetcher read addresses
    logic [NUM_FETCHERS-1:0] fetcher_read_ready; // Fetcher read ready signals
    logic [PROGRAM_MEM_DATA_BITS-1:0] fetcher_read_data [NUM_FETCHERS-1:0]; // Fetcher read data

    // Device Control Register
    dcr dcr_instance (
        .clk(clk),
        .reset(reset),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .thread_count(thread_count)
    );

    // Data Memory Controller
    controller #(
        .ADDR_BITS(DATA_MEM_ADDR_BITS),
        .DATA_BITS(DATA_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_LSUS),
        .NUM_CHANNELS(DATA_MEM_NUM_CHANNELS)
    ) data_memory_controller (
        .clk(clk),
        .reset(reset),
        .consumer_read_valid(lsu_read_valid),
        .consumer_read_address(lsu_read_address),
        .consumer_read_ready(lsu_read_ready),
        .consumer_read_data(lsu_read_data),
        .consumer_write_valid(lsu_write_valid),
        .consumer_write_address(lsu_write_address),
        .consumer_write_data(lsu_write_data),
        .consumer_write_ready(lsu_write_ready),
        .mem_read_valid(data_mem_read_valid),
        .mem_read_address(data_mem_read_address),
        .mem_read_ready(data_mem_read_ready),
        .mem_read_data(data_mem_read_data),
        .mem_write_valid(data_mem_write_valid),
        .mem_write_address(data_mem_write_address),
        .mem_write_data(data_mem_write_data),
        .mem_write_ready(data_mem_write_ready)
    );

    // Program Memory Controller
    controller #(
        .ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_FETCHERS),
        .NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS),
        .WRITE_ENABLE(0)
    ) program_memory_controller (
        .clk(clk),
        .reset(reset),
        .consumer_read_valid(fetcher_read_valid),
        .consumer_read_address(fetcher_read_address),
        .consumer_read_ready(fetcher_read_ready),
        .consumer_read_data(fetcher_read_data),
        .consumer_write_valid('0), 
        .consumer_write_address('{NUM_FETCHERS{{PROGRAM_MEM_ADDR_BITS{1'b0}}}}),
        .consumer_write_data('{NUM_FETCHERS{{PROGRAM_MEM_DATA_BITS{1'b0}}}}),
        .consumer_write_ready(), 
        .mem_read_valid(program_mem_read_valid),
        .mem_read_address(program_mem_read_address),
        .mem_read_ready(program_mem_read_ready),
        .mem_read_data(program_mem_read_data),
        .mem_write_valid(), 
        .mem_write_address(),
        .mem_write_data(), 
        .mem_write_ready('0)
    );

    // Dispatcher
    dispatch #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dispatch_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_start(core_start),
        .core_reset(core_reset),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .done(done)
    );

    // Compute Cores - inst 
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : cores
            // Separate signals for each core's LSUs due
            logic [THREADS_PER_BLOCK-1:0] core_lsu_read_valid;
            logic [DATA_MEM_ADDR_BITS-1:0] core_lsu_read_address [THREADS_PER_BLOCK-1:0];
            logic [THREADS_PER_BLOCK-1:0] core_lsu_read_ready;
            logic [DATA_MEM_DATA_BITS-1:0] core_lsu_read_data [THREADS_PER_BLOCK-1:0];
            logic [THREADS_PER_BLOCK-1:0] core_lsu_write_valid;
            logic [DATA_MEM_ADDR_BITS-1:0] core_lsu_write_address [THREADS_PER_BLOCK-1:0];
            logic [DATA_MEM_DATA_BITS-1:0] core_lsu_write_data [THREADS_PER_BLOCK-1:0];
            logic [THREADS_PER_BLOCK-1:0] core_lsu_write_ready;

            // Connect core's LSUs to global LSU signals
            genvar j;
            for (j = 0; j < THREADS_PER_BLOCK; j = j + 1) begin
                localparam lsu_index = i * THREADS_PER_BLOCK + j;
                always @(posedge clk) begin 
                    lsu_read_valid[lsu_index] <= core_lsu_read_valid[j];
                    lsu_read_address[lsu_index] <= core_lsu_read_address[j];
                    lsu_write_valid[lsu_index] <= core_lsu_write_valid[j];
                    lsu_write_address[lsu_index] <= core_lsu_write_address[j];
                    lsu_write_data[lsu_index] <= core_lsu_write_data[j];
                    core_lsu_read_ready[j] <= lsu_read_ready[lsu_index];
                    core_lsu_read_data[j] <= lsu_read_data[lsu_index];
                    core_lsu_write_ready[j] <= lsu_write_ready[lsu_index];
                end
            end

            // Instantiate compute core
            compute_core #(
                .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
                .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
                .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
                .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
            ) core_instance (
                .clk(clk),
                .reset(core_reset[i]),
                .start(core_start[i]),
                .done(core_done[i]),
                .block_id(core_block_id[i]),
                .thread_count(core_thread_count[i]),
                .program_mem_read_valid(fetcher_read_valid[i]),
                .program_mem_read_address(fetcher_read_address[i]),
                .program_mem_read_ready(fetcher_read_ready[i]),
                .program_mem_read_data(fetcher_read_data[i]),
                .data_mem_read_valid(core_lsu_read_valid),
                .data_mem_read_address(core_lsu_read_address),
                .data_mem_read_ready(core_lsu_read_ready),
                .data_mem_read_data(core_lsu_read_data),
                .data_mem_write_valid(core_lsu_write_valid),
                .data_mem_write_address(core_lsu_write_address),
                .data_mem_write_data(core_lsu_write_data),
                .data_mem_write_ready(core_lsu_write_ready)
            );
        end
    endgenerate
endmodule : gpu
