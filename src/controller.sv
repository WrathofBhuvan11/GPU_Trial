`timescale 1ns/1ns

// Controller module: Manages memory access arbitration for program and data memories
// Arbitrates read and write requests from multiple consumers to memory channels
// Uses FSM-based round-robin arbitration to ensure fair access
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
    input logic [NUM_CONSUMERS-1:0][ADDR_BITS-1:0] consumer_read_address, // Read addresses
    output logic [NUM_CONSUMERS-1:0] consumer_read_ready, // Read ready signals
    output logic [NUM_CONSUMERS-1:0][DATA_BITS-1:0] consumer_read_data, // Read data
    input logic [NUM_CONSUMERS-1:0] consumer_write_valid, // Write request valid signals
    input logic [NUM_CONSUMERS-1:0][ADDR_BITS-1:0] consumer_write_address, // Write addresses
    input logic [NUM_CONSUMERS-1:0][DATA_BITS-1:0] consumer_write_data, // Write data
    output logic [NUM_CONSUMERS-1:0] consumer_write_ready, // Write ready signals
    // Memory Interface
    output logic [NUM_CHANNELS-1:0] mem_read_valid, // Memory read request valid signals
    output logic [NUM_CHANNELS-1:0][ADDR_BITS-1:0] mem_read_address, // Memory read addresses
    input logic [NUM_CHANNELS-1:0] mem_read_ready, // Memory read ready signals
    input logic [NUM_CHANNELS-1:0][DATA_BITS-1:0] mem_read_data, // Memory read data
    output logic [NUM_CHANNELS-1:0] mem_write_valid, // Memory write request valid signals
    output logic [NUM_CHANNELS-1:0][ADDR_BITS-1:0] mem_write_address, // Memory write addresses
    output logic [NUM_CHANNELS-1:0][DATA_BITS-1:0] mem_write_data, // Memory write data
    input logic [NUM_CHANNELS-1:0] mem_write_ready // Memory write ready signals
);

    // Define local parameters for FSM states and bit widths
    localparam CONSUMER_BITS = (NUM_CONSUMERS > 1) ? $clog2(NUM_CONSUMERS) : 1;
    localparam CONS_W = CONSUMER_BITS + 1;

    //will add to enums.svh
    localparam CONTRLR_IDLE = 3'b000,
               READ_WAITING = 3'b001,
               WRITE_WAITING = 3'b010,
               READ_RELAYING = 3'b011,
               WRITE_RELAYING = 3'b100;

    // State and control registers
    reg [NUM_CHANNELS-1:0][2:0] controller_state; // FSM state per channel
    reg [NUM_CHANNELS-1:0][CONSUMER_BITS-1:0] current_consumer; // Tracks consumer per channel
    reg [NUM_CHANNELS-1:0][CONSUMER_BITS-1:0] rr_ptr; // Round-robin pointer per channel
    reg [NUM_CONSUMERS-1:0] channel_serving_consumer; // Tracks which consumers are served

    // Temporary signals for arbitration
    logic [NUM_CONSUMERS-1:0] temp_serving; // Temp storage for serving status
    logic [NUM_CHANNELS-1:0] assigned; // Tracks channel assignments

    // Main FSM arbitration logic
    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            // Reset
            mem_read_valid <= 0;
            consumer_read_ready <= 0;
            consumer_write_ready <= 0;
            mem_write_valid <= 0;
            channel_serving_consumer <= 0;
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                mem_read_address[i] <= 0;
                mem_write_address[i] <= 0;
                mem_write_data[i] <= 0;
                controller_state[i] <= CONTRLR_IDLE;
                current_consumer[i] <= 0;
                rr_ptr[i] <= 0;
            end
            for (int j = 0; j < NUM_CONSUMERS; j++) begin
                consumer_read_data[j] <= 0;
            end
        end else begin
            temp_serving = channel_serving_consumer;
            assigned = 0;
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                case (controller_state[i])
                    CONTRLR_IDLE: begin
                        // Check for read requests in round-robin order
                        for (int k = 0; k < NUM_CONSUMERS; k++) begin
                            logic [CONS_W-1:0] temp_sum;
                            logic [CONSUMER_BITS-1:0] jj;
                            temp_sum = {1'b0, rr_ptr[i]} + {1'b0, k[CONSUMER_BITS-1:0]};
                            jj = (temp_sum >= NUM_CONSUMERS) ? temp_sum[CONSUMER_BITS-1:0] - NUM_CONSUMERS[CONSUMER_BITS-1:0] : temp_sum[CONSUMER_BITS-1:0];
                            if (!assigned[i] && consumer_read_valid[jj] && !temp_serving[jj]) begin
                                assigned[i] = 1;
                                temp_serving[jj] = 1;
                                current_consumer[i] <= jj;
                                mem_read_valid[i] <= 1;
                                mem_read_address[i] <= consumer_read_address[jj];
                                controller_state[i] <= READ_WAITING;
                                rr_ptr[i] <= (jj + 1) % NUM_CONSUMERS;
                            end
                        end
                        if (WRITE_ENABLE) begin
                            // Check for write requests if enabled
                            for (int k = 0; k < NUM_CONSUMERS; k++) begin
                                logic [CONS_W-1:0] temp_sum;
                                logic [CONSUMER_BITS-1:0] jj;
                                temp_sum = {1'b0, rr_ptr[i]} + {1'b0, k[CONSUMER_BITS-1:0]};
                                jj = (temp_sum >= NUM_CONSUMERS) ? temp_sum[CONSUMER_BITS-1:0] - NUM_CONSUMERS[CONSUMER_BITS-1:0] : temp_sum[CONSUMER_BITS-1:0];
                                if (!assigned[i] && consumer_write_valid[jj] && !temp_serving[jj]) begin
                                    assigned[i] = 1;
                                    temp_serving[jj] = 1;
                                    current_consumer[i] <= jj;
                                    mem_write_valid[i] <= 1;
                                    mem_write_address[i] <= consumer_write_address[jj];
                                    mem_write_data[i] <= consumer_write_data[jj];
                                    controller_state[i] <= WRITE_WAITING;
                                    rr_ptr[i] <= (jj + 1) % NUM_CONSUMERS;
                                end
                            end
                        end
                    end
                    READ_WAITING: begin
                        // Wait for memory read response
                        if (mem_read_ready[i]) begin
                            mem_read_valid[i] <= 0;
                            consumer_read_ready[current_consumer[i]] <= 1;
                            consumer_read_data[current_consumer[i]] <= mem_read_data[i];
                            controller_state[i] <= READ_RELAYING;
                        end
                    end
                    WRITE_WAITING: begin
                        // Wait for memory write response
                        if (mem_write_ready[i]) begin
                            mem_write_valid[i] <= 0;
                            consumer_write_ready[current_consumer[i]] <= 1;
                            controller_state[i] <= WRITE_RELAYING;
                        end
                    end
                    READ_RELAYING: begin
                        // Wait for consumer to acknowledge read completion
                        if (!consumer_read_valid[current_consumer[i]]) begin
                            consumer_read_ready[current_consumer[i]] <= 0;
                            temp_serving[current_consumer[i]] = 0;
                            controller_state[i] <= CONTRLR_IDLE;
                        end
                    end
                    WRITE_RELAYING: begin
                        // Wait for consumer to acknowledge write completion
                        if (!consumer_write_valid[current_consumer[i]]) begin
                            consumer_write_ready[current_consumer[i]] <= 0;
                            temp_serving[current_consumer[i]] = 0;
                            controller_state[i] <= CONTRLR_IDLE;
                        end
                    end
                    default: begin
                        // Default to CONTRLR_IDLE state
                        controller_state[i] <= CONTRLR_IDLE;
                    end
                endcase
            end
            channel_serving_consumer <= temp_serving;
        end
    end
endmodule
