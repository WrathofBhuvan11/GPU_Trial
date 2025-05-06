`timescale 1ns/1ns

// ALU module: Performs arithmetic and comparison operations
module simple_alu (
    input wire [7:0] A, // First operand
    input wire [7:0] B, // Second operand
    input wire [3:0] operation, // Operation code (from opcode)
    output reg [7:0] result, // Computation result
    output reg [2:0] NZP // Condition codes: {Negative, Zero, Positive}
);

    // Combinational logic for operations
    always_comb begin
        case (operation)
            4'b0011: begin // ADD
                result = A + B;
                NZP = 3'b000;
            end
            4'b0100: begin // SUB
                result = A - B;
                NZP = 3'b000;
            end
            4'b0101: begin // MUL
                result = A * B;
                NZP = 3'b000;
            end
            4'b0110: begin // DIV
                if (B != 0) result = A / B;
                else result = 0; // Handle division by zero
                NZP = 3'b000;
            end
            4'b0010: begin // CMP
                result = 0;
                if ($signed(A) < $signed(B)) NZP = 3'b100; // Negative
                else if (A == B) NZP = 3'b010; // Zero
                else NZP = 3'b001; // Positive
            end
            default: begin
                result = 0;
                NZP = 3'b000;
            end
        endcase
    end
endmodule
