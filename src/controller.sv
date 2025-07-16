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
    input logic [ADDR_BITS-1:0][NUM_CONSUMERS-1:0] consumer_read_address, // Read addresses
    output logic [NUM_CONSUMERS-1:0] consumer_read_ready, // Read ready signals
    output logic [DATA_BITS-1:0][NUM_CONSUMERS-1:0] consumer_read_data, // Read data
    input logic [NUM_CONSUMERS-1:0] consumer_write_valid, // Write request valid signals
    input logic [ADDR_BITS-1:0][NUM_CONSUMERS-1:0] consumer_write_address, // Write addresses
    input logic [DATA_BITS-1:0][NUM_CONSUMERS-1:0] consumer_write_data, // Write data
    output logic [NUM_CONSUMERS-1:0] consumer_write_ready, // Write ready signals
    // Memory Interface
    output logic [NUM_CHANNELS-1:0] mem_read_valid, // Memory read request valid signals
    output logic [ADDR_BITS-1:0][NUM_CHANNELS-1:0] mem_read_address, // Memory read addresses
    input logic [NUM_CHANNELS-1:0] mem_read_ready, // Memory read ready signals
    input logic [DATA_BITS-1:0][NUM_CHANNELS-1:0] mem_read_data, // Memory read data
    output logic [NUM_CHANNELS-1:0] mem_write_valid, // Memory write request valid signals
    output logic [ADDR_BITS-1:0][NUM_CHANNELS-1:0] mem_write_address, // Memory write addresses
    output logic [DATA_BITS-1:0][NUM_CHANNELS-1:0] mem_write_data, // Memory write data
    input logic [NUM_CHANNELS-1:0] mem_write_ready // Memory write ready signals
);

    // Compute the number of bits needed for consumer and channel indices
    localparam CONSUMER_BITS = (NUM_CONSUMERS > 1) ? $clog2(NUM_CONSUMERS) : 1;
    localparam CHANNEL_BITS = (NUM_CHANNELS > 1) ? $clog2(NUM_CONSUMERS) : 1;
    // Temp loop variables (module level- Yosys issues)
    logic [CHANNEL_BITS-1:0] chan_idx;
    logic [CONSUMER_BITS-1:0] cons_idx;
    // Assigned flags per channel for read and write (separate to avoid overlap)
    logic [NUM_CHANNELS-1:0] read_assigned;
    logic [NUM_CHANNELS-1:0] write_assigned;
    // Temp for modulo calculation (wider to handle sum overflow)
    localparam CONS_W = CONSUMER_BITS + 1;
    logic [CONS_W-1:0] temp_sum;
    logic [CONSUMER_BITS-1:0] consumer_idx;
    logic [CONSUMER_BITS-1:0] next_consumer_idx; // Round-robin arbitration index to track the last assigned consumer
    logic [CONSUMER_BITS-1:0] current_consumer;
    // Next consumer index for arbitration
    logic [CONSUMER_BITS-1:0] next_consumer;

    // Arbitration logic
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            current_consumer <= 0;
            next_consumer <= 0;
            consumer_read_ready <= 0;
            consumer_write_ready <= 0;
            mem_read_valid <= 0;
            mem_write_valid <= 0;
            // Initialize read data and memory addresses to zero
            for (cons_idx = 0; cons_idx < NUM_CONSUMERS; cons_idx = cons_idx + 1) begin
                consumer_read_data[cons_idx] <= 0;
            end
            for (chan_idx = 0; chan_idx < NUM_CHANNELS; chan_idx = chan_idx + 1) begin
                mem_read_address [chan_idx] <= 0;
                mem_write_address [chan_idx] <= 0;
                mem_write_data[chan_idx] <= 0;
            end
        end else begin
            // Initialize outputs for the current cycle
            consumer_read_ready <= 0;
            mem_read_valid <= 0;
            if (WRITE_ENABLE) consumer_write_ready <= 0;
            if (WRITE_ENABLE) mem_write_valid <= 0;

            // Initialize next consumer index for round-robin arbitration
            next_consumer <= current_consumer;

            // Handle read requests
            for (chan_idx = 0; chan_idx < NUM_CHANNELS; chan_idx = chan_idx + 1) begin
                read_assigned[chan_idx] = 0;
                // Iterate through consumers to find the first valid read request
                for (cons_idx = 0; cons_idx < NUM_CONSUMERS; cons_idx = cons_idx + 1) begin
                    // Compute consumer_idx = (next_consumer + cons_idx) % NUM_CONSUMERS
                    temp_sum = {1'b0, next_consumer} + {1'b0, cons_idx};
                    consumer_idx = (temp_sum >= NUM_CONSUMERS) ? (temp_sum - NUM_CONSUMERS) : temp_sum[CONSUMER_BITS-1:0];
                    if (!read_assigned[chan_idx] && consumer_read_valid[consumer_idx] && mem_read_ready[chan_idx]) begin
                        mem_read_valid[chan_idx] <= 1;
                        mem_read_address[chan_idx] <= consumer_read_address[consumer_idx];
                        consumer_read_ready[consumer_idx] <= 1;
                        consumer_read_data[consumer_idx] <= mem_read_data[chan_idx];
                        read_assigned[chan_idx] = 1;
                        /// Update next_consumer = (consumer_idx + 1) % NUM_CONSUMERS
                        temp_sum = {1'b0, consumer_idx} + 1;
                        next_consumer <= (temp_sum >= NUM_CONSUMERS) ? (temp_sum - NUM_CONSUMERS) : temp_sum[CONSUMER_BITS-1:0];
                    end
                end
                // Clear valid signal if no consumer was assigned
                if (!read_assigned[chan_idx]) begin
                    mem_read_valid[chan_idx] <= 0;
                end
            end

            // Handle write requests if enabled
            if (WRITE_ENABLE) begin
                for (chan_idx = 0; chan_idx < NUM_CHANNELS; chan_idx = chan_idx + 1) begin
                    write_assigned[chan_idx] = 0;
                    // Iterate through consumers to find the first valid write request
                    for (cons_idx = 0; cons_idx < NUM_CONSUMERS; cons_idx = cons_idx + 1) begin
                        // Compute consumer_idx = (next_consumer + cons_idx) % NUM_CONSUMERS
                        temp_sum = {1'b0, next_consumer} + {1'b0, cons_idx};
                        consumer_idx = (temp_sum >= NUM_CONSUMERS) ? (temp_sum - NUM_CONSUMERS) : temp_sum[CONSUMER_BITS-1:0];
                        if (!write_assigned[chan_idx] && consumer_write_valid[consumer_idx] && mem_write_ready[chan_idx]) begin
                            mem_write_valid[chan_idx] <= 1;
                            mem_write_address[chan_idx] <= consumer_write_address[consumer_idx];
                            mem_write_data[chan_idx] <= consumer_write_data[consumer_idx];
                            consumer_write_ready[consumer_idx] <= 1;
                            write_assigned[chan_idx] = 1;
                            // Update next_consumer = (consumer_idx + 1) % NUM_CONSUMERS
                            temp_sum = {1'b0, consumer_idx} + 1;
                            next_consumer <= (temp_sum >= NUM_CONSUMERS) ? (temp_sum - NUM_CONSUMERS) : temp_sum[CONSUMER_BITS-1:0];
                        end
                    end
                    // Clear valid signal if no consumer was assigned
                    if (!write_assigned[chan_idx]) begin
                        mem_write_valid[chan_idx] <= 0;
                    end
                end
            end

            // Update current_consumer for the next cycle
            current_consumer <= next_consumer;
        end
    end
endmodule
