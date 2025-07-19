# tests/test_decoder.py
# Cocotb test for decoder.sv: Verifies instruction decoding.
import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue
import random
from cocotb_config import *  # Import global config

# Number of test iterations (Enough for coverage; adjustable for speed)
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


@cocotb.test()
async def test_decoder(dut):
    """Test decoder module with random instructions."""
    # Seed for reproducibility (3rd-order: Allows debugging failures)
    decoder_dut = gpu_dut.cores[0].core_instance.decoder_inst  #gpu -> generate cores[0] -> compute_core -> decoder_inst
    random.seed(42)

    for _ in range(NUM_TESTS):
        # Generate random 16-bit instruction
        instr_val = random.randint(0, 0xFFFF)
        decoder_dut.instruction.value = BinaryValue(instr_val, n_bits=16)

        # Wait for comb logic to settle (minimal delay)
        await Timer(1, units='ns')

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
