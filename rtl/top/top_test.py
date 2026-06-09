import cocotb
import os
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ValueChange
from cocotb.types import Logic

CLOCK_PERIOD_NS = 10
DEFAULT_TEST = os.getenv("TEST_NAME", "add_two")
TEST_COMPLIANCE = int(os.getenv("TEST_COMPLIANCE", "0"))
DEFAULT_IMEM = Path(f"../../programs/compliance_I/{DEFAULT_TEST}/program_imem.mem") if TEST_COMPLIANCE else Path(f"../../programs/rv32i/{DEFAULT_TEST}/program_imem.mem")
DEFAULT_DMEM = Path(f"../../programs/compliance_I/{DEFAULT_TEST}/program_dmem.mem") if TEST_COMPLIANCE else Path(f"../../programs/rv32i/{DEFAULT_TEST}/program_dmem.mem")
DEFAULT_MAP = Path(f"../../programs/compliance_I/{DEFAULT_TEST}/program.map")
DEFAULT_SIGNATURE = Path(f"../../programs/compliance_I/{DEFAULT_TEST}/expected_signature.mem")
DEFAULT_EXPECTED = Path(f"../../programs/rv32i/{DEFAULT_TEST}/expected.txt")
DEFAULT_IMEM_BASE = 0x0000
DEFAULT_DMEM_BASE = 0x1000
DEFAULT_DMEM_LOGICAL_BASE = 0x10000000
DEFAULT_RUN_CYCLES = 100000

def int_or_zero(value):
    return int(value) if value.is_resolvable else 0

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

def read_ram_word(dut, addr):
    return int(dut.u_axil_dp_ram.mem[addr >> 2].value) & 0xffffffff

def read_dcache_word(dut, addr, ram_addr=None):
    if ram_addr is None:
        ram_addr = addr

    width = int(dut.WIDTH_P.value)
    byte_lanes = width // 8
    cache_size_bytes = int(dut.CACHE_SIZE_BYTES_P.value)
    line_size_bytes = int(dut.CACHE_LINE_SIZE_BYTES_P.value)
    ways = int(dut.CACHE_WAYS_P.value)
    words_per_line = line_size_bytes // byte_lanes
    sets = cache_size_bytes // line_size_bytes // ways
    byte_offset_bits = byte_lanes.bit_length() - 1
    word_offset_bits = words_per_line.bit_length() - 1
    set_bits = sets.bit_length() - 1

    word = (addr >> byte_offset_bits) & ((1 << word_offset_bits) - 1)
    cache_set = (addr >> (byte_offset_bits + word_offset_bits)) & ((1 << set_bits) - 1)
    tag = addr >> (byte_offset_bits + word_offset_bits + set_bits)

    for line in range(ways):
        valid = int(dut.u_dcache.valid_q[cache_set][line].value)
        cached_tag = int(dut.u_dcache.tag_q[cache_set][line].value)
        if valid and cached_tag == tag:
            return int(dut.u_dcache.data_q[cache_set][line][word].value) & 0xffffffff

    return read_ram_word(dut, ram_addr)

def read_result(dut):
    ram_addr = int(os.getenv("DMEM_BASE", str(DEFAULT_DMEM_BASE)), 0)
    logical_addr = int(os.getenv("DMEM_LOGICAL_BASE", str(DEFAULT_DMEM_LOGICAL_BASE)), 0)
    return read_dcache_word(dut, logical_addr, ram_addr)

def read_symbol(path, symbol):
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[-1] == symbol and fields[0].startswith("0x"):
            return int(fields[0], 16)
    raise RuntimeError(f"symbol missing from map: {symbol}")

def expected_signature_words():
    path = Path(os.getenv("SIGNATURE_HEX", str(DEFAULT_SIGNATURE)))
    return [int(line.strip(), 16) for line in path.read_text().splitlines() if line.strip()]

def read_signature_words(dut):
    map_path = Path(os.getenv("PROGRAM_MAP", str(DEFAULT_MAP)))
    dmem_base = int(os.getenv("DMEM_BASE", str(DEFAULT_DMEM_BASE)), 0)
    ram_addr_width = int(os.getenv("RAM_ADDR_WIDTH_P", "20"), 0)
    ram_addr_mask = (1 << ram_addr_width) - 1
    signature_addr = read_symbol(map_path, "begin_signature")
    ram_addr = dmem_base + (signature_addr & ram_addr_mask)
    return [read_dcache_word(dut, signature_addr + i*4, ram_addr + i*4) for i in range(len(expected_signature_words()))]

@cocotb.test()
async def top_test(dut):
    dut.stall_i.value = 1
    dut.flush_i.value = 0
    await clock_test(dut)
    await reset_test(dut)
    load_instructions(dut)
    load_data(dut)
    dut.stall_i.value = 0
    fault_seen = False
    for i in range(int(os.getenv("RUN_CYCLES", str(DEFAULT_RUN_CYCLES)))):
        # stupid makeshift edge check because cocotb doesn't let you check triggers for non scalar values for some dumb fucking reason
        await ValueChange(dut.clk_i)
        if dut.clk_i.value[0] == 0:
            await ValueChange(dut.clk_i)
        instr_illegal = dut.debug_instr_illegal_o.value.is_resolvable and bool(dut.debug_instr_illegal_o.value)
        instr_access_fault = dut.instr_access_fault_o.value.is_resolvable and bool(dut.instr_access_fault_o.value)
        mem_access_fault = dut.mem_access_fault_o.value.is_resolvable and bool(dut.mem_access_fault_o.value)
        if not fault_seen and (instr_illegal or instr_access_fault or mem_access_fault):
            dut._log.warning(
                "%s fault cycle=%0d pc=0x%08x instr=0x%08x illegal=%0d instr_access_fault=%0d mem_access_fault=%0d",
                DEFAULT_TEST,
                i,
                int_or_zero(dut.debug_pc_o.value),
                int_or_zero(dut.ex_mem_instr_w.value),
                int(instr_illegal),
                int(instr_access_fault),
                int(mem_access_fault),
            )
            fault_seen = True

    if TEST_COMPLIANCE:
        actual_signature = read_signature_words(dut)
        expected_signature = expected_signature_words()
        for i, (actual, expected) in enumerate(zip(actual_signature, expected_signature)):
            assert actual == expected, f"{DEFAULT_TEST}: signature[{i}]=0x{actual:08x}, expected=0x{expected:08x}"
        assert not fault_seen, f"{DEFAULT_TEST}: compliance run hit illegal instruction or access fault"
        return

    actual = read_result(dut)
    expected = expected_result()
    assert actual == expected, f"{DEFAULT_TEST}: result=0x{actual:08x}, expected=0x{expected:08x}"
