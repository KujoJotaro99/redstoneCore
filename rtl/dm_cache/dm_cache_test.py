import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

CLOCK_PERIOD_NS = 10


class ModelManager:
    def __init__(self, dut):
        self.width = int(dut.WIDTH_P.value)
        self.byte_count = self.width // 8
        self.word_mod = 1 << self.width
        self.memory_bytes = {}

    def unsigned_word(self, value):
        return int(value) % self.word_mod

    def read_memory(self, addr):
        addr = int(addr)
        if addr not in self.memory_bytes:
            self.memory_bytes[addr] = list(self.unsigned_word(addr).to_bytes(self.byte_count, byteorder="little"))
        return int.from_bytes(self.memory_bytes[addr], byteorder="little")

    def write_memory(self, addr, data, wstrb):
        addr = int(addr)
        self.read_memory(addr)
        data_bytes = self.unsigned_word(data).to_bytes(self.byte_count, byteorder="little")
        strobe_lanes = set()
        for byte_idx, lane_enabled in enumerate(f"{int(wstrb):0{self.byte_count}b}"[::-1]):
            if lane_enabled == "1":
                strobe_lanes.add(byte_idx)

        for byte_idx in strobe_lanes:
            self.memory_bytes[addr][byte_idx] = data_bytes[byte_idx]

    def run(self, input_data):
        write, addr, wdata, wstrb = input_data
        if write:
            self.write_memory(addr, wdata, wstrb)
            return 0
        return self.read_memory(addr)


class InputManager:
    def __init__(self, handshake, stream):
        self.handshake = handshake
        self.stream = list(stream)
        self.index = 0
        self.valid = False
        self.current = (0, 0, 0, 0)

    def drive(self):
        if not self.valid and self.index < len(self.stream):
            self.current = self.stream[self.index]
            self.valid = True
        self.handshake.drive(self.valid, self.current)

    def accept(self):
        if self.valid:
            self.index += 1
            self.valid = False
            return self.current
        return None


class ScoreManager:
    def __init__(self, model, handshake):
        self.model = model
        self.handshake = handshake
        self.pending = []
        self.index = 0

    def update_expected(self, input_data):
        self.pending.append(self.model.run(input_data))

    def check_output(self):
        if not self.pending:
            return False

        output = self.handshake.output_value()
        if output is None:
            return False

        data_exp = self.pending.pop(0)

        assert output == int(data_exp), \
            f"data mismatch: got {output:#010x} expected {int(data_exp):#010x} at transaction {self.index + 1}"

        self.index += 1
        return True


class HandshakeManager:
    def __init__(self, dut, model):
        self.dut = dut
        self.model = model
        self.last_valid = False
        self.last_ready = False
        self.current = (0, 0, 0, 0)
        self.mem_valid = False
        self.mem_clear = False
        self.mem_data = 0

    def drive(self, valid, data):
        write, addr, wdata, wstrb = data
        self.last_valid = bool(valid)
        self.last_ready = bool(int(self.dut.cache_module_req_ready_o.value))
        self.current = data

        self.dut.module_cache_req_valid_i.value = 1 if valid else 0
        self.dut.module_cache_req_write_i.value = int(write)
        self.dut.module_cache_req_addr_i.value = int(addr)
        self.dut.module_cache_req_wdata_i.value = int(wdata)
        self.dut.module_cache_req_wstrb_i.value = int(wstrb)
        self.dut.module_cache_rsp_ready_i.value = 1
        self.dut.mem_cache_req_ready_i.value = 1
        self.dut.mem_cache_rsp_valid_i.value = 1 if self.mem_valid else 0
        self.dut.mem_cache_rsp_rdata_i.value = self.mem_data
        self.dut.mem_cache_rsp_resp_i.value = 0

    def update_bus(self):
        if self.mem_clear:
            self.mem_valid = False
            self.mem_clear = False
        elif self.mem_valid and int(self.dut.cache_mem_rsp_ready_o.value):
            self.mem_clear = True

        if (not self.mem_valid and not self.mem_clear and int(self.dut.cache_mem_req_valid_o.value) and int(self.dut.mem_cache_req_ready_i.value)):
            addr = int(self.dut.cache_mem_req_addr_o.value)
            wdata = int(self.dut.cache_mem_req_wdata_o.value)
            wstrb = int(self.dut.cache_mem_req_wstrb_o.value)

            if int(self.dut.cache_mem_req_write_o.value):
                self.model.write_memory(addr, wdata, wstrb)
                self.mem_data = 0
            else:
                self.mem_data = self.model.read_memory(addr)
            self.mem_valid = True

        self.dut.mem_cache_rsp_valid_i.value = 1 if self.mem_valid else 0
        self.dut.mem_cache_rsp_rdata_i.value = self.mem_data
        self.dut.mem_cache_rsp_resp_i.value = 0

    def input_accepted(self):
        return self.last_valid and self.last_ready

    def input_value(self):
        return self.current

    def output_value(self):
        if not int(self.dut.cache_module_rsp_valid_o.value):
            return None

        value = self.dut.cache_module_rsp_rdata_o.value
        if not value.is_resolvable:
            return None
        return int(value)


class TestManager:
    def __init__(self, dut, stream):
        self.dut = dut
        self.model = ModelManager(dut)
        self.handshake = HandshakeManager(dut, self.model)
        self.input = InputManager(self.handshake, stream)
        self.scoreboard = ScoreManager(self.model, self.handshake)
        self.expected = len(stream)
        self.checked = 0

    async def run(self):
        try:
            self.input.drive()
            cycles = 0
            while self.checked < self.expected:
                await FallingEdge(self.dut.clk_i)
                self.handshake.update_bus()

                if self.handshake.input_accepted():
                    input_data = self.input.accept()
                    if input_data is not None:
                        self.scoreboard.update_expected(input_data)

                if self.scoreboard.check_output():
                    self.checked += 1

                self.input.drive()
                cycles += 1
                assert cycles < (self.expected * 30 + 30), "dm_cache test timeout"
        finally:
            self.dut.module_cache_req_valid_i.value = 0
            self.dut.module_cache_req_write_i.value = 0
            self.dut.module_cache_req_addr_i.value = 0
            self.dut.module_cache_req_wdata_i.value = 0
            self.dut.module_cache_req_wstrb_i.value = 0
            self.dut.module_cache_rsp_ready_i.value = 0
            self.dut.mem_cache_req_ready_i.value = 0
            self.dut.mem_cache_rsp_valid_i.value = 0
            self.dut.mem_cache_rsp_rdata_i.value = 0
            self.dut.mem_cache_rsp_resp_i.value = 0


async def clock_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await Timer(1, unit="ns")


async def reset_test(dut):
    dut.rstn_i.value = 0
    dut.module_cache_req_valid_i.value = 0
    dut.module_cache_req_write_i.value = 0
    dut.module_cache_req_addr_i.value = 0
    dut.module_cache_req_wdata_i.value = 0
    dut.module_cache_req_wstrb_i.value = 0
    dut.module_cache_rsp_ready_i.value = 0
    dut.mem_cache_req_ready_i.value = 0
    dut.mem_cache_rsp_valid_i.value = 0
    dut.mem_cache_rsp_rdata_i.value = 0
    dut.mem_cache_rsp_resp_i.value = 0

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)

    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)


@cocotb.test(skip=False)
async def test_dm_cache_cold_read_miss(dut):
    """read an address that is not cached yet, so the cache must fetch it from backing memory."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x20, 0, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_read_hit_after_fill(dut):
    """read the same address twice, where the first read fills the cache and the second read should hit."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x24, 0, 0b0000),
        (0, 0x24, 0, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_write_hit_merge(dut):
    """read a word into the cache, write one byte of that cached word, then read back the merged word."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x30, 0x00000000, 0b0000),
        (1, 0x30, 0x000000aa, 0b0001),
        (0, 0x30, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_write_miss_no_allocate(dut):
    """write an address that is not cached yet, then read it back and expect backing memory to hold the write."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (1, 0x34, 0x12345678, 0b1111),
        (0, 0x34, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_store_byte_strobes(dut):
    """write one byte lane at a time and verify only that byte changes while other bytes stay saved."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x40, 0x00000000, 0b0000),
        (1, 0x40, 0x000000aa, 0b0001),
        (0, 0x40, 0x00000000, 0b0000),
        (1, 0x40, 0x0000bb00, 0b0010),
        (0, 0x40, 0x00000000, 0b0000),
        (1, 0x40, 0x00cc0000, 0b0100),
        (0, 0x40, 0x00000000, 0b0000),
        (1, 0x40, 0xdd000000, 0b1000),
        (0, 0x40, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_store_halfword_strobes(dut):
    """write the low halfword and high halfword separately and verify only those two bytes change each time."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x44, 0x00000000, 0b0000),
        (1, 0x44, 0x0000abcd, 0b0011),
        (0, 0x44, 0x00000000, 0b0000),
        (1, 0x44, 0xef010000, 0b1100),
        (0, 0x44, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_store_word_strobe(dut):
    """write all four byte lanes at once and verify the whole cached word is replaced."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x48, 0x00000000, 0b0000),
        (1, 0x48, 0xdeadbeef, 0b1111),
        (0, 0x48, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_index_alias_eviction(dut):
    """read two addresses that map to the same cache slot and verify the newer tag evicts the older one."""
    await clock_test(dut)
    await reset_test(dut)

    line_count = int(dut.LINES_P.value)
    addr_a = 0x00
    addr_b = line_count * 4
    stream = [
        (0, addr_a, 0x00000000, 0b0000),
        (0, addr_b, 0x00000000, 0b0000),
        (0, addr_a, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_back_to_back_requests(dut):
    """send requests one after another and verify the cache accepts the next request after each response."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0, 0x00, 0x00000000, 0b0000),
        (0, 0x04, 0x00000000, 0b0000),
        (1, 0x08, 0x11112222, 0b1111),
        (0, 0x08, 0x00000000, 0b0000),
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_read_only(dut):
    """run random reads only, covering a mix of first-time misses and repeated-address hits."""
    await clock_test(dut)
    await reset_test(dut)

    random.seed(1)
    stream = []
    for _ in range(64):
        addr = random.randrange(0, 0x100, 4)
        stream.append((0, addr, 0, 0b0000))

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_write_only(dut):
    """run random writes only, covering write-through behavior and random byte-lane strobes."""
    await clock_test(dut)
    await reset_test(dut)

    random.seed(2)
    word_mod = 1 << int(dut.WIDTH_P.value)
    stream = []
    for _ in range(64):
        addr = random.randrange(0, 0x100, 4)
        wdata = random.randrange(0, word_mod)
        wstrb = random.randint(1, 0b1111)
        stream.append((1, addr, wdata, wstrb))

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_dm_cache_read_write_mix(dut):
    """run random reads and writes together and compare every response against byte-backed memory."""
    await clock_test(dut)
    await reset_test(dut)

    random.seed(3)
    word_mod = 1 << int(dut.WIDTH_P.value)
    stream = []
    for _ in range(128):
        write = random.randint(0, 1)
        addr = random.randrange(0, 0x100, 4)
        wdata = random.randrange(0, word_mod) if write else 0
        wstrb = random.randint(1, 0b1111) if write else 0
        stream.append((write, addr, wdata, wstrb))

    manager = TestManager(dut, stream)
    await manager.run()
