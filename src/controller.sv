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

    // Compute the number of bits needed for consumer indices
    localparam CONSUMER_BITS = (NUM_CONSUMERS > 1) ? $clog2(NUM_CONSUMERS) : 1;

    // Round-robin arbitration index to track the last assigned consumer
    logic [CONSUMER_BITS-1:0] current_consumer;

    // Next consumer index for arbitration
    logic [CONSUMER_BITS-1:0] next_consumer;

    // Arbitration logic
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            // Initialize module-level registers on reset
            current_consumer <= 0; // Start arbitration from consumer 0
            next_consumer <= 0; // Initialize next consumer index
            consumer_read_ready <= '0; // Clear all read ready signals
            consumer_write_ready <= '0; // Clear all write ready signals
            mem_read_valid <= '0; // Clear all memory read valid signals
            mem_write_valid <= '0; // Clear all memory write valid signals
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
            // Initialize outputs for the current cycle
            consumer_read_ready <= '0;
            mem_read_valid <= '0;
            if (WRITE_ENABLE) consumer_write_ready <= '0;
            if (WRITE_ENABLE) mem_write_valid <= '0;

            // Initialize next consumer index for round-robin arbitration
            next_consumer <= current_consumer;

            // Handle read requests
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                logic assigned = 0; // Local flag to track if channel is assigned
                // Iterate through consumers to find the first valid read request
                for (int j = 0; j < NUM_CONSUMERS; j++) begin
                    int consumer_idx = (int'(next_consumer) + j) % NUM_CONSUMERS; // Cast to int
                    if (!assigned && consumer_read_valid[consumer_idx] && mem_read_ready[i]) begin
                        mem_read_valid[i] <= 1; // Set memory read request
                        mem_read_address[i] <= consumer_read_address[consumer_idx]; // Set address
                        consumer_read_ready[consumer_idx] <= 1; // Signal consumer ready
                        consumer_read_data[consumer_idx] <= mem_read_data[i]; // Pass data
                        assigned = 1; // Mark channel as assigned
                        next_consumer <= CONSUMER_BITS'(((consumer_idx + 1) % NUM_CONSUMERS));
                    end
                end
                // Clear valid signal if no consumer was assigned
                if (!assigned) begin
                    mem_read_valid[i] <= 0;
                end
            end

            // Handle write requests if enabled
            if (WRITE_ENABLE) begin
                for (int i = 0; i < NUM_CHANNELS; i++) begin
                    logic assigned = 0; // Local flag to track if channel is assigned
                    // Iterate through consumers to find the first valid write request
                    for (int j = 0; j < NUM_CONSUMERS; j++) 
                    begin
                        int consumer_idx = (int'(next_consumer) + j) % NUM_CONSUMERS;
                        if (!assigned && consumer_write_valid[consumer_idx] && mem_write_ready[i]) 
                        begin
                            mem_write_valid[i] <= 1; // Set memory write request
                            mem_write_address[i] <= consumer_write_address[consumer_idx]; // Set address
                            mem_write_data[i] <= consumer_write_data[consumer_idx]; // Set data
                            consumer_write_ready[consumer_idx] <= 1; // Signal consumer ready
                            assigned = 1; // Mark channel as assigned
                            next_consumer <= CONSUMER_BITS'(((consumer_idx + 1) % NUM_CONSUMERS));
                        end
                    end
                    // Clear valid signal if no consumer was assigned
                    if (!assigned) begin
                        mem_write_valid[i] <= 0;
                    end
                end
            end

            // Update current_consumer for the next cycle
            current_consumer <= next_consumer;
        end
    end
endmodule
