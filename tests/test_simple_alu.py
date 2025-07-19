# tests/test_simple_alu.py
# Cocotb test for simple_alu.sv: Verifies ALU operations with random A/B.

import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue
import random
from cocotb_config import *  # Import global config

# Number of test iterations
NUM_TESTS = 1000

# Golden model for ALU
def golden_alu(a, b, op):
    result = 0
    nzp = 0
    if op == 0x3:  # ADD
        result = (a + b) & 0xFF  # 8-bit wrap
    elif op == 0x4:  # SUB
        result = (a - b) & 0xFF
    elif op == 0x5:  # MUL
        result = (a * b) & 0xFF
    elif op == 0x6:  # DIV
        result = (a // b) & 0xFF if b != 0 else 0
    elif op == 0x2:  # CMP
        a_signed = a if a < 128 else a - 256  # 8-bit signed
        b_signed = b if b < 128 else b - 256
        if a_signed < b_signed:
            nzp = 0b100
        elif a == b:
            nzp = 0b010
        else:
            nzp = 0b001
    # Defaults: result=0, nzp=0 for invalid
    return {'result': result, 'nzp': nzp}

@cocotb.test()
async def test_simple_alu(dut):
    """Test ALU with random ops/A/B."""
    # Access submodule (pick core 0, thread 0; 2nd-order: ALU per-thread, sample one)
    alu_dut = gpu_dut.cores[0].core_instance.threads[0].alu_inst  # TO edit

    random.seed(42)  # Reproducible

    for _ in range(NUM_TESTS):
        a_val = random.randint(0, 0xFF)
        b_val = random.randint(0, 0xFF)
        op_val = random.choice([0x2, 0x3, 0x4, 0x5, 0x6, 0xF])  # CMP/arith/invalid

        alu_dut.A.value = BinaryValue(a_val, n_bits=8)
        alu_dut.B.value = BinaryValue(b_val, n_bits=8)
        alu_dut.operation.value = BinaryValue(op_val, n_bits=4)

        await Timer(1, units='ns')

        dut_out = {
            'result': int(alu_dut.result.value),
            'nzp': int(alu_dut.NZP.value)
        }

        golden = golden_alu(a_val, b_val, op_val)

        assert dut_out == golden, f"Mismatch for op={hex(op_val)}, A={hex(a_val)}, B={hex(b_val)}: DUT {dut_out} vs Golden {golden}"

    dut._log.info(f"Passed {NUM_TESTS} random tests.")
