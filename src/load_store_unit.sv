`timescale 1ns/1ns

// Load-Store Unit module: Handles memory load and store operations for a single thread
module load_store_unit #(
    parameter DATA_MEM_ADDR_BITS = 8,
    parameter DATA_MEM_DATA_BITS = 8
) (
    input clk,
    input reset,
    input logic load_enable, // Enable load operation (LDR)
    input logic store_enable, // Enable store operation (STR)
    input logic [DATA_MEM_ADDR_BITS-1:0] address, // Memory address from Rs
    input logic [DATA_MEM_DATA_BITS-1:0] store_data, // Data to store from Rt
    output logic [DATA_MEM_DATA_BITS-1:0] load_data, // Loaded data for Rd
    output logic data_mem_read_valid, // Read request to memory controller
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address,
    input logic data_mem_read_ready, // Memory read ready signal
    input logic [DATA_MEM_DATA_BITS-1:0] data_mem_read_data,
    output logic data_mem_write_valid, // Write request to memory controller
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address,
    output logic [DATA_MEM_DATA_BITS-1:0] data_mem_write_data,
    input logic data_mem_write_ready, // Memory write ready signal
    output logic lsu_done // Indicates operation completion
);

    // State machine states for managing load/store operations
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        STORE
    } state_t;

    state_t state;

    // State machine to handle memory operations
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            state <= IDLE;
            data_mem_read_valid <= 0;
            data_mem_write_valid <= 0;
            lsu_done <= 0;
            load_data <= 0;
            data_mem_read_address <= 0;
            data_mem_write_address <= 0;
            data_mem_write_data <= 0;
        end else begin
            case (state)
                IDLE: begin
                    lsu_done <= 0;
                    if (load_enable) begin
                        state <= LOAD;
                        data_mem_read_valid <= 1;
                        data_mem_read_address <= address;
                    end else if (store_enable) begin
                        state <= STORE;
                        data_mem_write_valid <= 1;
                        data_mem_write_address <= address;
                        data_mem_write_data <= store_data;
                    end
                end
                LOAD: begin
                    if (data_mem_read_ready) begin
                        load_data <= data_mem_read_data;
                        data_mem_read_valid <= 0;
                        lsu_done <= 1;
                        state <= IDLE;
                    end
                end
                STORE: begin
                    if (data_mem_write_ready) begin
                        data_mem_write_valid <= 0;
                        lsu_done <= 1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
