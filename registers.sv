`timescale 1ns/1ns

// Registers module: Per-thread register file with read-only registers R13-R15
module registers (
    input wire clk,
    input wire reset,
    input wire [3:0] read_addr1, // Address for first read port
    input wire [3:0] read_addr2, // Address for second read port
    output reg [7:0] read_data1, // Data from first read port
    output reg [7:0] read_data2, // Data from second read port
    input wire [3:0] write_addr, // Write address
    input wire [7:0] write_data, // Data to write
    input wire write_enable, // Enable write operation
    input wire [7:0] block_id, // Block ID for R13
    input wire [7:0] thread_id, // Thread ID for R15
    input wire [7:0] threads_per_block // Threads per block for R14
);

    reg [7:0] regs [0:12]; // General-purpose registers R0-R12

    // Read logic: Handle reads from R0-R15, with R13-R15 being read-only
    always_comb begin
        if (read_addr1 >= 13) begin
            case (read_addr1)
                4'd13: read_data1 = block_id;
                4'd14: read_data1 = threads_per_block;
                4'd15: read_data1 = thread_id;
                default: read_data1 = 0;
            endcase
        end else begin
            read_data1 = regs[read_addr1];
        end
        
        if (read_addr2 >= 13) begin
            case (read_addr2)
                4'd13: read_data2 = block_id;
                4'd14: read_data2 = threads_per_block;
                4'd15: read_data2 = thread_id;
                default: read_data2 = 0;
            endcase
        end else begin
            read_data2 = regs[read_addr2];
        end
    end

    // Write logic: Only write to R0-R12
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 13; i++) begin
                regs[i] <= 0; // Reset general-purpose registers
            end
        end else if (write_enable && write_addr < 13) begin
            regs[write_addr] <= write_data; // Write to specified register
        end
    end
endmodule
