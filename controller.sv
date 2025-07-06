`timescale 1ns/1ns

// Controller module: Manages memory access arbitration for program and data memories
// Arbitrates read and write requests from multiple consumers to memory channels
// Uses round-robin arbitration to ensure fair access
// WRITE_ENABLE parameter toggles write functionality (1 for data memory, 0 for program memory)
module controller #(
    parameter ADDR_BITS = 8,          // Address width (e.g., 8 bits for 256 rows)
    parameter DATA_BITS = 8,          // Data width (e.g., 8 bits for data, 16 for instructions)
    parameter NUM_CONSUMERS = 4,      // Number of consumers (e.g., LSUs or fetchers)
    parameter NUM_CHANNELS = 4,       // Number of memory channels
    parameter WRITE_ENABLE = 1        // Enable write operations (1 for data memory, 0 for program memory)
) (
    input clk,                   // Clock signal
    input reset,                 // Reset signal
    // Consumer Interface
    input logic [NUM_CONSUMERS-1:0] consumer_read_valid, // Read request valid signals
    input logic [ADDR_BITS-1:0] consumer_read_address [NUM_CONSUMERS-1:0], // Read addresses
    output logic [NUM_CONSUMERS-1:0] consumer_read_ready, // Read ready signals
    output logic [DATA_BITS-1:0] consumer_read_data [NUM_CONSUMERS-1:0], // Read data
    input logic [NUM_CONSUMERS-1:0] consumer_write_valid, // Write request valid signals
    input logic [ADDR_BITS-1:0] consumer_write_address [NUM_CONSUMERS-1:0], // Write addresses
    input logic [DATA_BITS-1:0] consumer_write_data [NUM_CONSUMERS-1:0], // Write data
    output logic [NUM_CONSUMERS-1:0] consumer_write_ready, // Write ready signals
    // Memory Interface
    output logic [NUM_CHANNELS-1:0] mem_read_valid, // Memory read request valid signals
    output logic [ADDR_BITS-1:0] mem_read_address [NUM_CHANNELS-1:0], // Memory read addresses
    input logic [NUM_CHANNELS-1:0] mem_read_ready, // Memory read ready signals
    input logic [DATA_BITS-1:0] mem_read_data [NUM_CHANNELS-1:0], // Memory read data
    output logic [NUM_CHANNELS-1:0] mem_write_valid, // Memory write request valid signals
    output logic [ADDR_BITS-1:0] mem_write_address [NUM_CHANNELS-1:0], // Memory write addresses
    output logic [DATA_BITS-1:0] mem_write_data [NUM_CHANNELS-1:0], // Memory write data
    input logic [NUM_CHANNELS-1:0] mem_write_ready // Memory write ready signals
);

    // Round-robin arbitration index to track the last assigned consumer
    logic [$clog2(NUM_CONSUMERS)-1:0] current_consumer;

    // Arbitration logic
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            // Initialize signals on reset
            current_consumer <= 0;
            consumer_read_ready <= '0;
            consumer_write_ready <= '0;
            mem_read_valid <= '0;
            mem_write_valid <= '0;
            // Initialize read data and memory addresses to zero
            for (int i = 0; i < NUM_CONSUMERS; i++) begin
                consumer_read_data[i] <= '0;
            end
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                mem_read_address[i] <= '0;
                mem_write_address[i] <= '0;
                mem_write_data[i] <= '0;
            end
        end else begin
            // Temporary consumer index for round-robin arbitration
            logic [$clog2(NUM_CONSUMERS)-1:0] temp_consumer;
            temp_consumer = current_consumer;
            // Flags to track channel assignments for reads and writes
            logic [NUM_CHANNELS-1:0] read_assigned;
            logic [NUM_CHANNELS-1:0] write_assigned;
            read_assigned = '0;
            write_assigned = '0;

            // Initialize outputs
            consumer_read_ready <= '0;
            mem_read_valid <= '0;
            if (WRITE_ENABLE) consumer_write_ready <= '0;
            if (WRITE_ENABLE) mem_write_valid <= '0;

            // Handle read requests
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                // Iterate through consumers to find the first valid request
                for (int j = 0; j < NUM_CONSUMERS; j++) begin
                    int consumer_idx = (temp_consumer + j) % NUM_CONSUMERS;
                    // Assign channel if not already assigned and conditions are met
                    if (!read_assigned[i] && consumer_read_valid[consumer_idx] && mem_read_ready[i]) begin
                        mem_read_valid[i] <= 1; // Set memory read request
                        mem_read_address[i] <= consumer_read_address[consumer_idx]; // Set address
                        consumer_read_ready[consumer_idx] <= 1; // Signal consumer ready
                        consumer_read_data[consumer_idx] <= mem_read_data[i]; // Pass data
                        read_assigned[i] <= 1; // Mark channel as assigned
                        temp_consumer <= (consumer_idx + 1) % NUM_CONSUMERS; // Update consumer index
                    end
                end
                // Clear valid signal if no consumer was assigned
                if (!read_assigned[i]) begin
                    mem_read_valid[i] <= 0;
                end
            end

            // Handle write requests if enabled
            if (WRITE_ENABLE) begin
                for (int i = 0; i < NUM_CHANNELS; i++) begin
                    // Iterate through consumers to find the first valid write request
                    for (int j = 0; j < NUM_CONSUMERS; j++) begin
                        int consumer_idx = (temp_consumer + j) % NUM_CONSUMERS;
                        // Assign channel if not already assigned and conditions are met
                        if (!write_assigned[i] && consumer_write_valid[consumer_idx] && mem_write_ready[i]) 
                        begin
                            mem_write_valid[i] <= 1; // Set memory write request
                            mem_write_address[i] <= consumer_write_address[consumer_idx]; // Set address
                            mem_write_data[i] <= consumer_write_data[consumer_idx]; // Set data
                            consumer_write_ready[consumer_idx] <= 1; // Signal consumer ready
                            write_assigned[i] <= 1; // Mark channel as assigned
                            temp_consumer <= (consumer_idx + 1) % NUM_CONSUMERS; // Update consumer index
                        end
                    end
                    // Clear valid signal if no consumer was assigned
                    if (!write_assigned[i]) begin
                        mem_write_valid[i] <= 0;
                    end
                end
            end
            
            // Update current_consumer for the next cycle
            current_consumer <= temp_consumer;
        end
    end
endmodule
