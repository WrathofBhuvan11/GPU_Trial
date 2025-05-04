# New_GPU
SIMD Based basic GPU Implementation 
```
gpu.sv
├── dcr.sv
├── controller.sv (for data memory)
├── controller.sv (for program memory)
├── dispatch.sv
└── compute_core.sv (multiple instances)
    ├── fetch.sv
    ├── decoder.sv
    ├── scheduler.sv
    ├── alu.sv (per thread)
    ├── load_store_unit.sv (per thread)
    ├── program_counter.sv
    └── registers.sv (per thread)
```

ISA Details
| Instruction | Opcode              | Semantics              | Description                                      |
|-------------|---------------------|------------------------|--------------------------------------------------|
| NOP         | 0000 xxxx xxxx xxxx | PC = PC + 1           | Advances to the next instruction without operation. |
| BRNZP       | 0001 nzzp xIII IIII | NZP ? PC = IMM8       | Branches to IMM8 if NZP condition codes match; takes branch if any thread meets per-thread NZP based on signed difference of Rs and Rt. |
| CMP         | 0010 xxxx sss ttt   | NZP = sign(Rs - Rt)   | Sets per-thread NZP based on signed difference of Rs and Rt. |
| ADD         | 0011 ddddd sss ttt  | Rd = Rs + Rt          | Adds Rs and Rt, stores in Rd (if Rd < 13).       |
| SUB         | 0100 ddddd sss ttt  | Rd = Rs - Rt          | Subtracts Rt from Rs, stores in Rd (if Rd < 13). |
| MUL         | 0101 ddddd sss ttt  | Rd = Rs * Rt          | Multiplies Rs and Rt, stores in Rd (if Rd < 13). |
| DIV         | 0110 ddddd sss ttt  | Rd = Rs / Rt          | Divides Rs by Rt, stores in Rd (if Rd < 13, Rt ≠ 0). |
| LDR         | 0111 ddddd sss xxxx | Rd = global_data_mem[Rs] | Loads value from data memory address Rs to Rd (if Rd < 13). |
| STR         | 1000 xxxx sss ttt   | global_data_mem[Rs] = Rt | Stores Rt to data memory address Rs.            |
| CONST       | 1001 ddddd IIII IIII | Rd = IMM8            | Loads 8-bit immediate into Rd (if Rd < 13).     |
| HALT        | 1111 xxxx xxxx xxxx | done                  | Halts execution, signaling core completion.     |

Register File
Each thread has 16 registers (8-bit each):

R0 to R12: General-purpose, read/write.

R13: Read-only, stores block_id.

R14: Read-only, stores THREADS_PER_BLOCK.

R15: Read-only, stores local thread index (0 to THREADS_PER_BLOCK-1). Writes to R13–R15 are ignored, enabling kernels to access block and thread metadata for SIMD execution
