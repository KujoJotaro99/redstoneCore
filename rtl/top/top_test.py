import cocotb
import os
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ValueChange
from cocotb.types import Logic

CLOCK_PERIOD_NS = 10
DEFAULT_TEST = os.getenv("TEST_NAME", "add_two")
DEFAULT_IMEM = Path(f"../../programs/rv32i/{DEFAULT_TEST}/program_imem.mem")
DEFAULT_DMEM = Path(f"../../programs/rv32i/{DEFAULT_TEST}/program_dmem.mem")
DEFAULT_EXPECTED = Path(f"../../programs/rv32i/{DEFAULT_TEST}/expected.txt")
DEFAULT_IMEM_BASE = 0x0000
DEFAULT_DMEM_BASE = 0x1000
DEFAULT_RUN_CYCLES = 100000

async def clock_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, "ns").start(start_high=False))
    await Timer(1, "ns")

async def reset_test(dut):
    await Timer(CLOCK_PERIOD_NS*10, "ns")
    dut.rstn_i.value = 1
    await Timer(CLOCK_PERIOD_NS*10, "ns")

def _load_mem_words(dut, path, base_addr):
    path = Path(path)
    if not path.exists():
        dut._log.warning("memory file missing: %s", path)
        return

    word_index = base_addr >> 2
    for line in path.read_text().splitlines():
        word = line.strip()
        if not word or word.startswith("#"):
            continue
        dut.u_axil_dp_ram.mem[word_index].value = int(word, 16)
        word_index += 1

def load_instructions(dut):
    path = os.getenv("IMEM_HEX", str(DEFAULT_IMEM))
    base_addr = int(os.getenv("IMEM_BASE", str(DEFAULT_IMEM_BASE)), 0)
    _load_mem_words(dut, path, base_addr)

def load_data(dut):
    path = os.getenv("DMEM_HEX", str(DEFAULT_DMEM))
    base_addr = int(os.getenv("DMEM_BASE", str(DEFAULT_DMEM_BASE)), 0)
    _load_mem_words(dut, path, base_addr)

def expected_result():
    path = Path(os.getenv("EXPECTED_HEX", str(DEFAULT_EXPECTED)))
    return int(path.read_text().strip(), 16)

def read_result(dut):
    base_addr = int(os.getenv("DMEM_BASE", str(DEFAULT_DMEM_BASE)), 0)
    return int(dut.u_axil_dp_ram.mem[base_addr >> 2].value) & 0xffffffff

@cocotb.test()
async def top_test(dut):
    dut.stall_i.value = 1
    dut.flush_i.value = 0
    await clock_test(dut)
    await reset_test(dut)
    load_instructions(dut)
    load_data(dut)
    dut.stall_i.value = 0
    for i in range(int(os.getenv("RUN_CYCLES", str(DEFAULT_RUN_CYCLES)))):
        # stupid makeshift edge check because cocotb doesn't let you check triggers for non scalar values for some dumb fucking reason
        await ValueChange(dut.clk_i)
        if dut.clk_i.value[0] == 0:
            await ValueChange(dut.clk_i)

    actual = read_result(dut)
    expected = expected_result()
    assert actual == expected, f"{DEFAULT_TEST}: result=0x{actual:08x}, expected=0x{expected:08x}"
