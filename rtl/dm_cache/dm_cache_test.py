import random
from itertools import count
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

CLOCK_PERIOD_NS = 10


class ModelManager:
    def __init__(self, dut):
        self.width = int(dut.WIDTH_P.value)
        self.lines = int(dut.LINES_P.value)
        self.mask = (1 << self.width) - 1
        self.index_width = (self.lines - 1).bit_length()
        self.valid = [0 for _ in range(self.lines)]
        self.tag = [0 for _ in range(self.lines)]
        self.data = [0 for _ in range(self.lines)]
        self.memory = {}
        self.index = 128

    def get_index(self):
        return self.index

    def reset(self):
        self.valid = [0 for _ in range(self.lines)]
        self.tag = [0 for _ in range(self.lines)]
        self.data = [0 for _ in range(self.lines)]

    def read_memory(self, addr):
        addr = int(addr) & self.mask
        if addr not in self.memory:
            self.memory[addr] = addr # mem at addr A returns A, for simplicity
        return self.memory[addr]

    def run(self, input_data):
        addr = int(input_data) & self.mask
        index = (addr >> 2) & (self.lines - 1)
        tag = addr >> (self.index_width + 2)

        if not (self.valid[index] and self.tag[index] == tag):
            self.valid[index] = 1
            self.tag[index] = tag
            self.data[index] = self.read_memory(addr)

        return self.data[index]


class InputManager:
    def __init__(self, handshake, stream):
        self.handshake = handshake
        self.stream = stream

    def drive(self):
        self.handshake.drive(next(self.stream))


class ScoreManager:
    def __init__(self, model, handshake):
        self.model = model
        self.handshake = handshake
        self.pending = []
        self.index = 0

    def get_index(self):
        return self.index

    def update_expected(self):
        self.pending.append(self.model.run(self.handshake.input_value()))

    def check_output(self):
        if not self.pending:
            return False

        output = self.handshake.output_value()
        if output is None:
            return False

        instr_exp = self.pending.pop(0)

        assert output == int(instr_exp), \
            f"instr mismatch: got {output} expected {int(instr_exp)} at transaction {self.index + 1}"

        self.index += 1
        return True


class HandshakeManager:
    def __init__(self, dut, model):
        self.dut = dut
        self.model = model
        self.last_valid = False
        self.current = 0

    def drive(self, addr):
        self.current = addr
        self.last_valid = bool(int(self.dut.cache_if_req_ready_o.value))

        self.dut.if_cache_req_valid_i.value = 1
        self.dut.if_cache_req_addr_i.value = addr
        self.dut.if_cache_rsp_ready_i.value = 1
        self.dut.axi_arready_i.value = 1
        self.dut.axi_rresp_i.value = 0
        self.dut.axi_rvalid_i.value = 1
        self.dut.axi_rdata_i.value = self.model.read_memory(int(self.dut.axi_araddr_o.value))

    def input_accepted(self):
        return self.last_valid

    def input_value(self):
        return self.current

    def output_value(self):
        if not int(self.dut.cache_if_rsp_valid_o.value):
            return None

        value = self.dut.cache_if_rsp_instr_o.value
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

    async def run(self):
        try:
            while self.scoreboard.get_index() < self.model.get_index():
                self.input.drive()
                if self.handshake.input_accepted():
                    self.scoreboard.update_expected()
                self.scoreboard.check_output()
                await FallingEdge(self.dut.clk_i)
        finally:
            self.dut.if_cache_req_valid_i.value = 0
            self.dut.if_cache_req_addr_i.value = 0
            self.dut.if_cache_rsp_ready_i.value = 0
            self.dut.axi_arready_i.value = 0
            self.dut.axi_rdata_i.value = 0
            self.dut.axi_rresp_i.value = 0
            self.dut.axi_rvalid_i.value = 0


async def clock_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await Timer(1, unit="ns")


async def reset_test(dut):
    dut.rstn_i.value = 0
    dut.if_cache_req_valid_i.value = 0
    dut.if_cache_req_addr_i.value = 0
    dut.if_cache_rsp_ready_i.value = 0
    dut.axi_arready_i.value = 0
    dut.axi_rdata_i.value = 0
    dut.axi_rresp_i.value = 0
    dut.axi_rvalid_i.value = 0

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)

    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)


@cocotb.test(skip=False)
async def test_dm_cache_random(dut):
    await clock_test(dut)
    await reset_test(dut)

    random.seed(42)
    mask = (1 << int(dut.WIDTH_P.value)) - 1
    addresses = [((random.randint(0, mask) >> 2) << 2) for _ in range(int(dut.LINES_P.value))]
    manager = TestManager(dut, (random.choice(addresses) for _ in count()))
    await manager.run()
