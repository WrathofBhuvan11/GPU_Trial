`timescale 1ns/1ns

// Decoder module: Decodes the 16-bit instruction into control signals for the compute core
module decoder (
    input logic clk,                  // Clock for registering outputs
    input logic reset,                // Active-low reset to clear outputs
    input logic [15:0] instruction,   // 16-bit instruction from fetch unit
    output logic [3:0] opcode,        // 4-bit opcode
    output logic [3:0] Rd,            // Destination register
    output logic [3:0] Rs,            // Source register 1
    output logic [3:0] Rt,            // Source register 2
    output logic [7:0] IMM8,          // 8-bit immediate value
    output logic [3:0] condition,     // Condition codes for BRNzp
    output logic is_nop,              // Indicates NOP instruction
    output logic is_branch,           // Indicates BRNzp instruction
    output logic is_cmp,              // Indicates CMP instruction
    output logic is_add,              // Indicates ADD instruction
    output logic is_sub,              // Indicates SUB instruction
    output logic is_mul,              // Indicates MUL instruction
    output logic is_div,              // Indicates DIV instruction
    output logic is_ldr,              // Indicates LDR instruction
    output logic is_str,              // Indicates STR instruction
    output logic is_const,            // Indicates CONST instruction
    output logic is_halt              // Indicates HALT instruction
);

    // always_ff 
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            opcode <= 4'b0;
            Rd <= 4'b0;
            Rs <= 4'b0;
            Rt <= 4'b0;
            IMM8 <= 8'b0;
            condition <= 4'b0;
            is_nop <= 1'b0;
            is_branch <= 1'b0;
            is_cmp <= 1'b0;
            is_add <= 1'b0;
            is_sub <= 1'b0;
            is_mul <= 1'b0;
            is_div <= 1'b0;
            is_ldr <= 1'b0;
            is_str <= 1'b0;
            is_const <= 1'b0;
            is_halt <= 1'b0;
        end else begin
            // Extract opcode
            opcode <= instruction[15:12];
            // Full assignments per case
            case (instruction[15:12])
                4'b0000: begin  // NOP
                    Rd <= 4'b0;
                    Rs <= 4'b0;
                    Rt <= 4'b0;
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b1;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0001: begin  // BRNzp
                    Rd <= 4'b0;
                    Rs <= 4'b0;
                    Rt <= 4'b0;
                    IMM8 <= instruction[7:0];
                    condition <= instruction[11:8];
                    is_nop <= 1'b0;
                    is_branch <= 1'b1;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0010: begin  // CMP
                    Rd <= 4'b0;
                    Rs <= instruction[7:4];
                    Rt <= instruction[3:0];
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b1;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0011: begin  // ADD
                    Rd <= instruction[11:8];
                    Rs <= instruction[7:4];
                    Rt <= instruction[3:0];
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b1;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0100: begin  // SUB
                    Rd <= instruction[11:8];
                    Rs <= instruction[7:4];
                    Rt <= instruction[3:0];
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b1;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0101: begin  // MUL
                    Rd <= instruction[11:8];
                    Rs <= instruction[7:4];
                    Rt <= instruction[3:0];
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b1;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0110: begin  // DIV
                    Rd <= instruction[11:8];
                    Rs <= instruction[7:4];
                    Rt <= instruction[3:0];
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b1;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b0111: begin  // LDR
                    Rd <= instruction[11:8];
                    Rs <= instruction[7:4];
                    Rt <= 4'b0;
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b1;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b1000: begin  // STR
                    Rd <= 4'b0;
                    Rs <= instruction[7:4];
                    Rt <= instruction[3:0];
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b1;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
                4'b1001: begin  // CONST
                    Rd <= instruction[11:8];
                    Rs <= 4'b0;
                    Rt <= 4'b0;
                    IMM8 <= instruction[7:0];
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b1;
                    is_halt <= 1'b0;
                end
                4'b1111: begin  // HALT
                    Rd <= 4'b0;
                    Rs <= 4'b0;
                    Rt <= 4'b0;
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b0;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b1;
                end
                default: begin  // Invalid: Treat as NOP (full clear + is_nop)
                    Rd <= 4'b0;
                    Rs <= 4'b0;
                    Rt <= 4'b0;
                    IMM8 <= 8'b0;
                    condition <= 4'b0;
                    is_nop <= 1'b1;
                    is_branch <= 1'b0;
                    is_cmp <= 1'b0;
                    is_add <= 1'b0;
                    is_sub <= 1'b0;
                    is_mul <= 1'b0;
                    is_div <= 1'b0;
                    is_ldr <= 1'b0;
                    is_str <= 1'b0;
                    is_const <= 1'b0;
                    is_halt <= 1'b0;
                end
            endcase
        end
    end

endmodule
