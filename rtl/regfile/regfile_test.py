import random
from itertools import count
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

CLOCK_PERIOD_NS = 10


class ModelManager:
    def __init__(self, dut):
        self.width = int(dut.WIDTH_P.value)
        self.depth = int(dut.DEPTH_P.value)
        self.mask = (1 << self.width) - 1
        self.regs = [0 for _ in range(self.depth)]
        self.index = self.depth + 300

    def get_index(self):
        return self.index

    def reset(self):
        self.regs = [0 for _ in range(self.depth)]

    def run(self, input_data):
        rs1_addr, rs2_addr, rd_addr, rd_data, rd_we = input_data
        rs1_data = 0 if rs1_addr == 0 else self.regs[rs1_addr]
        rs2_data = 0 if rs2_addr == 0 else self.regs[rs2_addr]

        if rd_we and rd_addr != 0:
            self.regs[rd_addr] = int(rd_data) & self.mask

        return rs1_data, rs2_data


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

        rs1_exp, rs2_exp = self.pending.pop(0)
        rs1_out, rs2_out = output

        assert rs1_out == int(rs1_exp), \
            f"rs1 mismatch: got {rs1_out} expected {int(rs1_exp)} at transaction {self.index + 1}"
        assert rs2_out == int(rs2_exp), \
            f"rs2 mismatch: got {rs2_out} expected {int(rs2_exp)} at transaction {self.index + 1}"

        self.index += 1
        return True


class HandshakeManager:
    def __init__(self, dut):
        self.dut = dut
        self.last_valid = False
        self.current = (0, 0, 0, 0, 0)

    def drive(self, data):
        rs1_addr, rs2_addr, rd_addr, rd_data, rd_we = data
        self.last_valid = True
        self.current = data

        self.dut.rs1_addr_i.value = rs1_addr
        self.dut.rs2_addr_i.value = rs2_addr
        self.dut.rd_addr_i.value = rd_addr
        self.dut.rd_data_i.value = rd_data
        self.dut.rd_we_i.value = rd_we

    def input_accepted(self):
        return self.last_valid

    def input_value(self):
        return self.current

    def output_value(self):
        signals = [self.dut.rs1_data_o.value, self.dut.rs2_data_o.value]
        if any(not signal.is_resolvable for signal in signals):
            return None
        return tuple(int(signal) for signal in signals)


class TestManager:
    def __init__(self, dut, stream):
        self.dut = dut
        self.handshake = HandshakeManager(dut)
        self.input = InputManager(self.handshake, stream)
        self.model = ModelManager(dut)
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
            self.dut.rs1_addr_i.value = 0
            self.dut.rs2_addr_i.value = 0
            self.dut.rd_addr_i.value = 0
            self.dut.rd_data_i.value = 0
            self.dut.rd_we_i.value = 0


async def clock_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await Timer(1, unit="ns")


async def reset_test(dut):
    dut.rstn_i.value = 0
    dut.rs1_addr_i.value = 0
    dut.rs2_addr_i.value = 0
    dut.rd_addr_i.value = 0
    dut.rd_data_i.value = 0
    dut.rd_we_i.value = 0

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)

    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)


@cocotb.test(skip=False)
async def test_regfile_random(dut):
    await clock_test(dut)
    await reset_test(dut)

    random.seed(42)
    mask = (1 << int(dut.WIDTH_P.value)) - 1
    depth = int(dut.DEPTH_P.value)

    stream = (
        (0, 0, (index % depth), random.randint(0, mask), 1)
        if index < depth else
        (
            random.randint(0, depth - 1),
            random.randint(0, depth - 1),
            random.randint(0, depth - 1),
            random.randint(0, mask),
            random.randint(0, 1)
        )
        for index in count(1)
    )

    manager = TestManager(dut, stream)
    await manager.run()
