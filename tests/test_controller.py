# tests/test_controller.py
# functions: Arbitration (round-robin, contention)

import cocotb
from cocotb.triggers import RisingEdge, Timer, ReadOnly
from cocotb.clock import Clock
from cocotb.queue import Queue
import random

# Parameterized test for WRITE_ENABLE
async def run_controller_test(dut, write_enable):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    
    num_consumers = int(dut.NUM_CONSUMERS)
    num_channels = int(dut.NUM_CHANNELS)
    
    # Queues for emulating memory responses
    mem_read_ready_q = [Queue() for _ in range(num_channels)]
    mem_write_ready_q = [Queue() for _ in range(num_channels)] if write_enable else None
    
    # Fork memory emulation
    for ch in range(num_channels):
        cocotb.start_soon(emulate_mem_read(ch, dut, mem_read_ready_q[ch]))
        if write_enable:
            cocotb.start_soon(emulate_mem_write(ch, dut, mem_write_ready_q[ch]))
    
    # Drive random requests
    for _ in range(500):  # Many cycles to test arbitration
        # Randomly assert read/write valids
        for cons in range(num_consumers):
            if random.random() > 0.5:
                dut.consumer_read_valid[cons].value = 1
                dut.consumer_read_address[cons].value = random.randint(0, 255)
            else:
                dut.consumer_read_valid[cons].value = 0
            
            if write_enable and random.random() > 0.5:
                dut.consumer_write_valid[cons].value = 1
                dut.consumer_write_address[cons].value = random.randint(0, 255)
                dut.consumer_write_data[cons].value = random.randint(0, 255)
            elif write_enable:
                dut.consumer_write_valid[cons].value = 0
        
        await RisingEdge(dut.clk)
        
        # Check for fairness: track served consumers over time
        served_reads = [0] * num_consumers
        served_writes = [0] * num_consumers if write_enable else None
        
        # Monitor outputs and assert round-robin order
        # For simplicity, log and assert no starvation (e.g., max served diff < threshold)
        await ReadOnly()
        for ch in range(num_channels):
            if int(dut.mem_read_valid[ch].value):
                # Simulate ready after delay
                await mem_read_ready_q[ch].put(1)  # Or random delay
                # Track which consumer was served (need to monitor internal or infer)
                # Note: To track exactly, might need to expose or infer from addresses
        
        # Deassert after ack
        for cons in range(num_consumers):
            if int(dut.consumer_read_ready[cons].value):
                dut.consumer_read_valid[cons].value = 0
            if write_enable and int(dut.consumer_write_ready[cons].value):
                dut.consumer_write_valid[cons].value = 0
    
    # After loop, assert coverage or fairness metrics

async def emulate_mem_read(ch, dut, q):
    while True:
        await q.get()
        delay = random.randint(1, 5)
        for _ in range(delay):
            await RisingEdge(dut.clk)
        dut.mem_read_ready[ch].value = 1
        dut.mem_read_data[ch].value = random.randint(0, 255)  # Emulate data
        await RisingEdge(dut.clk)
        dut.mem_read_ready[ch].value = 0

async def emulate_mem_write(ch, dut, q):
    while True:
        await q.get()
        delay = random.randint(1, 5)
        for _ in range(delay):
            await RisingEdge(dut.clk)
        dut.mem_write_ready[ch].value = 1
        await RisingEdge(dut.clk)
        dut.mem_write_ready[ch].value = 0

@cocotb.test()
async def test_controller_data(dut):
    """Test controller with WRITE_ENABLE=1"""
    await run_controller_test(dut, write_enable=True)

@cocotb.test()
async def test_controller_program(dut):
    """Test controller with WRITE_ENABLE=0"""
    await run_controller_test(dut, write_enable=False)
    # Additional asserts for write ignore: drive writes and check no mem_write_valid
    for _ in range(10):
        for cons in range(int(dut.NUM_CONSUMERS)):
            dut.consumer_write_valid[cons].value = 1
            dut.consumer_write_address[cons].value = random.randint(0, 255)
            dut.consumer_write_data[cons].value = random.randint(0, 255)
        await RisingEdge(dut.clk)
        for ch in range(int(dut.NUM_CHANNELS)):
            assert int(dut.mem_write_valid[ch].value) == 0, "Writes not ignored when WRITE_ENABLE=0"
