# tests/test_decoder.py
# Cocotb test for decoder.sv: Verifies instruction decoding.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue
import random

# Number of test iterations
NUM_TESTS = 1000

# Golden model: Python function to decode instruction (for scoreboard)
def golden_decoder(instr):
    opcode = (instr >> 12) & 0xF
    rd = rs = rt = imm8 = cond = 0
    is_nop = is_branch = is_cmp = is_add = is_sub = is_mul = is_div = is_ldr = is_str = is_const = is_halt = 0

    if opcode == 0x0:  # NOP
        is_nop = 1
    elif opcode == 0x1:  # BRNzp
        is_branch = 1
        cond = (instr >> 8) & 0xF
        imm8 = instr & 0xFF
    elif opcode == 0x2:  # CMP
        is_cmp = 1
        rs = (instr >> 4) & 0xF
        rt = instr & 0xF
    elif opcode == 0x3:  # ADD
        is_add = 1
        rd = (instr >> 8) & 0xF
        rs = (instr >> 4) & 0xF
        rt = instr & 0xF
    elif opcode == 0x4:  # SUB
        is_sub = 1
        rd = (instr >> 8) & 0xF
        rs = (instr >> 4) & 0xF
        rt = instr & 0xF
    elif opcode == 0x5:  # MUL
        is_mul = 1
        rd = (instr >> 8) & 0xF
        rs = (instr >> 4) & 0xF
        rt = instr & 0xF
    elif opcode == 0x6:  # DIV
        is_div = 1
        rd = (instr >> 8) & 0xF
        rs = (instr >> 4) & 0xF
        rt = instr & 0xF
    elif opcode == 0x7:  # LDR
        is_ldr = 1
        rd = (instr >> 8) & 0xF
        rs = (instr >> 4) & 0xF
    elif opcode == 0x8:  # STR
        is_str = 1
        rs = (instr >> 4) & 0xF
        rt = instr & 0xF
    elif opcode == 0x9:  # CONST
        is_const = 1
        rd = (instr >> 8) & 0xF
        imm8 = instr & 0xFF
    elif opcode == 0xF:  # HALT
        is_halt = 1
    else:  # Default: NOP
        is_nop = 1

    return {
        'opcode': opcode,
        'rd': rd, 'rs': rs, 'rt': rt,
        'imm8': imm8, 'cond': cond,
        'is_nop': is_nop, 'is_branch': is_branch, 'is_cmp': is_cmp,
        'is_add': is_add, 'is_sub': is_sub, 'is_mul': is_mul, 'is_div': is_div,
        'is_ldr': is_ldr, 'is_str': is_str, 'is_const': is_const, 'is_halt': is_halt
    }

# Reusable reset coroutine
async def reset_dut(dut):
    dut.reset.value = 0
    await Timer(10, units="ns")
    dut.reset.value = 1
    await Timer(10, units="ns")

@cocotb.test()
async def test_decoder_basic(dut):
    """Test basic decoding of instructions with random inputs."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Seed for reproducibility
    random.seed(42)
    
    for _ in range(NUM_TESTS):
        # Generate random 16-bit instruction
        instr_val = random.randint(0, 0xFFFF)
        dut.instruction.value = BinaryValue(instr_val, n_bits=16)
        
        # Wait for register update
        await RisingEdge(dut.clk)
        
        # Get DUT outputs
        dut_out = {
            'opcode': int(dut.opcode.value),
            'rd': int(dut.Rd.value),
            'rs': int(dut.Rs.value),
            'rt': int(dut.Rt.value),
            'imm8': int(dut.IMM8.value),
            'cond': int(dut.condition.value),
            'is_nop': int(dut.is_nop.value),
            'is_branch': int(dut.is_branch.value),
            'is_cmp': int(dut.is_cmp.value),
            'is_add': int(dut.is_add.value),
            'is_sub': int(dut.is_sub.value),
            'is_mul': int(dut.is_mul.value),
            'is_div': int(dut.is_div.value),
            'is_ldr': int(dut.is_ldr.value),
            'is_str': int(dut.is_str.value),
            'is_const': int(dut.is_const.value),
            'is_halt': int(dut.is_halt.value)
        }
        
        # Golden model prediction
        golden = golden_decoder(instr_val)
        
        # Assert equality
        assert dut_out == golden, f"Mismatch for instr {hex(instr_val)}: DUT {dut_out} vs Golden {golden}"
    
    dut._log.info(f"Passed {NUM_TESTS} random tests.")

@cocotb.test()
async def test_decoder_invalid(dut):
    """Test invalid opcodes default to NOP."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    invalid_opcodes = [0b1010, 0b1011, 0b1100, 0b1101, 0b1110]
    for op in invalid_opcodes:
        instr_val = (op << 12) | random.randint(0, 0xFFF)
        dut.instruction.value = BinaryValue(instr_val, n_bits=16)
        
        await RisingEdge(dut.clk)
        
        assert int(dut.is_nop.value) == 1, f"Invalid opcode {bin(op)} not treated as NOP"
        assert int(dut.opcode.value) == op, "Opcode mismatch"
        assert int(dut.Rd.value) == 0, "Rd not zero for invalid"
        assert int(dut.Rs.value) == 0, "Rs not zero for invalid"
        assert int(dut.Rt.value) == 0, "Rt not zero for invalid"
        assert int(dut.IMM8.value) == 0, "IMM8 not zero for invalid"
        assert int(dut.condition.value) == 0, "Condition not zero for invalid"
        
        # Ensure other is_ signals are 0
        other_is_signals = ['is_branch', 'is_cmp', 'is_add', 'is_sub', 'is_mul', 'is_div', 'is_ldr', 'is_str', 'is_const', 'is_halt']
        for sig in other_is_signals:
            assert int(dut.__getattr__(sig).value) == 0, f"Unexpected {sig} active on invalid instr {hex(instr_val)}"
    
    dut._log.info("Passed invalid opcode tests.")
