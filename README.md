# GPU_Trial
SIMD Based basic GPU Implementation  (Work in progress)

(openLANE RTL-GDSII steps) & cocoTB verification
openlane2 nixx setup
```
gpu.sv
├── dcr.sv
├── controller.sv (for data memory inst- data_mem_controller)
├── controller.sv (for program memory inst - prog_mem_controller)
├── dispatch.sv
└── compute_core.sv (multiple instances)
    ├── fetch.sv
    ├── decoder.sv
    ├── scheduler.sv
    ├── simple_alu.sv (per thread)
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
### ==========================================================

### 1. gpu.sv
Functionality: Acts as the top-level module that integrates all components of the tiny GPU.
Responsibilities:
Instantiates submodules such as dcr.sv, controller.sv (for data and program memory), dispatch.sv, and multiple compute_core.sv instances.
Manages the overall control flow, including starting/resetting the GPU and signaling kernel execution completion.
Connects submodules to external memory interfaces for program and data memory.

### 2. dcr.sv
Functionality: Implements the Device Control Register.
Responsibilities:
Stores the total number of threads (thread_count) to be executed for the kernel.
Updates thread_count when the device control write enable signal is asserted.

### 3. controller.sv (Data Memory)
Functionality: Serves as the memory controller for data memory.
Responsibilities:
Manages read and write requests from load-store units (LSUs) in compute cores to external data memory.
Arbitrates between multiple LSUs using a round-robin scheme.
Interfaces with external data memory using valid/ready handshakes.

### 4. controller.sv (Program Memory)
Functionality: Serves as the memory controller for program memory.
Responsibilities:
Manages read requests from fetch units in compute cores to external program memory.
Arbitrates between multiple fetch units using a round-robin scheme.
Interfaces with external program memory using valid/ready handshakes (write operations are disabled as it’s read-only).

### 5. dispatch.sv
Functionality: Handles the dispatching of thread blocks to compute cores.
Responsibilities:
Organizes threads into blocks, each with up to THREADS_PER_BLOCK threads.
Assigns thread blocks to compute cores, providing each with a block_id and thread count.
Monitors compute core completion and signals when all blocks are processed.

### 6. compute_core.sv
Functionality: Processes one block of threads as a compute core.
Responsibilities:
Instantiates submodules like fetch.sv, decoder.sv, scheduler.sv, alu.sv, load_store_unit.sv, program_counter.sv, and registers.sv.
Manages the fetch-decode-execute cycle for the thread block using a state machine.
Executes instructions in a SIMD manner across active threads.

### 7. fetch.sv
Functionality: Fetches instructions from program memory within a compute core.
Responsibilities:
Retrieves instructions based on the current program counter (PC).
Uses valid/ready handshakes with the program memory controller.
Forwards fetched instructions to the decoder.

### 8. decoder.sv
Functionality: Decodes instructions within a compute core.
Responsibilities:
Interprets the 16-bit instruction, extracting opcode, register addresses, immediate values, and condition codes.
Generates control signals (e.g., is_add, is_ldr) for instruction execution.

### 9. scheduler.sv
Functionality: Schedules threads within a compute core.
Responsibilities:
Determines active threads based on the block’s thread_count.
Generates an active_threads mask to indicate which threads execute instructions.

### 10. alu.sv
Functionality: Performs arithmetic and logic operations, instantiated per thread.
Responsibilities:
Executes operations like ADD, SUB, MUL, DIV, and CMP based on the opcode.
Sets condition codes (NZP) for comparison operations.

### 11. load_store_unit.sv
Functionality: Manages memory operations, instantiated per thread.
Responsibilities:
Handles load (LDR) and store (STR) instructions.
Interfaces with the data memory controller using valid/ready handshakes.
Ensures memory operation completion.

### 12. program_counter.sv
Functionality: Maintains the program counter within a compute core.
Responsibilities:
Tracks and updates the shared PC for the thread block.
Adjusts the PC for sequential execution or branches.

### 13. registers.sv
Functionality: Provides a register file, instantiated per thread.
Responsibilities:
Maintains 16 registers (R0–R15), with R13–R15 as read-only metadata (e.g., block_id, thread_id).
Supports reading from two registers and writing to one per cycle.


### ================================================================================================================
## Verifcation plans using cocotb python
tests/                        
├── __init__.py                # Makes tests a package
├── test_decoder.py            # functions: Random instructions, assert decoded signals
├── test_simple_alu.py         # functions: Ops w/ random A/B
├── test_fetch.py              # functions: Handshake w/ backpressure
├── test_load_store_unit.py    # functions: Load/store w/ mem emulation
├── test_scheduler.py          # functions: Active masks, branch logic (divergence edges)
├── test_dcr.py                # functions: Simple reg writes
├── test_controller.py         # functions: Arbitration (round-robin, contention)
├── test_program_counter.py    # functions: Inc/branch/reset
├── test_registers.py          # functions: Read/write, specials protection
├── test_dispatch.py           # functions: Block assignment, partials, multi-wave
├── test_compute_core.py       # Integration: Full core flow (program exec, SIMD)
└── test_gpu.py                # System: Multi-core kernel, dispatch + mem contention
