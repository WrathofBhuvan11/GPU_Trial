`default_nettype none
`timescale 1ns/1ns

// Decoder module: Decodes the 16-bit instruction into control signals for the compute core
module decoder (
    input logic [15:0] instruction, // 16-bit instruction from fetch unit
    output logic [3:0] opcode, // 4-bit opcode
    output logic [3:0] Rd, // Destination register
    output logic [3:0] Rs, // Source register 1
    output logic [3:0] Rt, // Source register 2
    output logic [7:0] IMM8, // 8-bit immediate value
    output logic [3:0] condition, // Condition codes for BRNzp
    output logic is_nop, // Indicates NOP instruction
    output logic is_branch, // Indicates BRNzp instruction
    output logic is_cmp, // Indicates CMP instruction
    output logic is_add, // Indicates ADD instruction
    output logic is_sub, // Indicates SUB instruction
    output logic is_mul, // Indicates MUL instruction
    output logic is_div, // Indicates DIV instruction
    output logic is_ldr, // Indicates LDR instruction
    output logic is_str, // Indicates STR instruction
    output logic is_const, // Indicates CONST instruction
    output logic is_halt // Indicates HALT instruction
);

    // Combinational decoding logic
    always_comb begin
        // Extract opcode from instruction
        opcode = instruction[15:12];
        
        // Initialize outputs to default values
        Rd = 0;
        Rs = 0;
        Rt = 0;
        IMM8 = 0;
        condition = 0;
        is_nop = 0;
        is_branch = 0;
        is_cmp = 0;
        is_add = 0;
        is_sub = 0;
        is_mul = 0;
        is_div = 0;
        is_ldr = 0;
        is_str = 0;
        is_const = 0;
        is_halt = 0;
        
        // Decode based on opcode
        case (opcode)
            4'b0000: begin // NOP
                is_nop = 1;
            end
            4'b0001: begin // BRNzp
                is_branch = 1;
                condition = instruction[11:8]; // nzzpx condition codes
                IMM8 = instruction[7:0]; // Branch target address
            end
            4'b0010: begin // CMP
                is_cmp = 1;
                Rs = instruction[7:4]; // Source register 1
                Rt = instruction[3:0]; // Source register 2
            end
            4'b0011: begin // ADD
                is_add = 1;
                Rd = instruction[11:8]; // Destination register
                Rs = instruction[7:4]; // Source register 1
                Rt = instruction[3:0]; // Source register 2
            end
            4'b0100: begin // SUB
                is_sub = 1;
                Rd = instruction[11:8];
                Rs = instruction[7:4];
                Rt = instruction[3:0];
            end
            4'b0101: begin // MUL
                is_mul = 1;
                Rd = instruction[11:8];
                Rs = instruction[7:4];
                Rt = instruction[3:0];
            end
            4'b0110: begin // DIV
                is_div = 1;
                Rd = instruction[11:8];
                Rs = instruction[7:4];
                Rt = instruction[3:0];
            end
            4'b0111: begin // LDR
                is_ldr = 1;
                Rd = instruction[11:8];
                Rs = instruction[7:4];
            end
            4'b1000: begin // STR
                is_str = 1;
                Rs = instruction[7:4];
                Rt = instruction[3:0];
            end
            4'b1001: begin // CONST
                is_const = 1;
                Rd = instruction[11:8];
                IMM8 = instruction[7:0];
            end
            4'b1111: begin // HALT
                is_halt = 1;
            end
            default: begin
                is_nop = 1;
            end
        endcase
    end
endmodule
