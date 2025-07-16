`timescale 1ns/1ns

// Program Counter module: Manages the shared program counter for the block
module program_counter #(
    parameter PROGRAM_MEM_ADDR_BITS = 8
) (
    input clk,
    input reset,
    input logic load, // Load next_pc into PC (for branches)
    input logic [PROGRAM_MEM_ADDR_BITS-1:0] next_pc, // Branch target or PC+1
    output logic [PROGRAM_MEM_ADDR_BITS-1:0] PC // Current program counter
);

    // Update PC on clock edge
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            PC <= 0; // Reset PC to start of program memory
        end else if (load) begin
            PC <= next_pc; // Load branch target for BRNzp
        end else begin
            PC <= PC + 1; // Increment PC for sequential execution
        end
    end
endmodule
