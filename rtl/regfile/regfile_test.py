import random

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

    def run(self, input_data):
        rs1_addr, rs2_addr, rd_addr, rd_data, rd_we = input_data

        if rd_we and rd_addr != 0:
            self.regs[rd_addr] = int(rd_data) & self.mask

        rs1_data = 0 if rs1_addr == 0 else self.regs[rs1_addr]
        rs2_data = 0 if rs2_addr == 0 else self.regs[rs2_addr]
        return rs1_data, rs2_data


class InputManager:
    def __init__(self, stream):
        self.data = list(stream)
        self.index = 0
        self.valid = False
        self.current = None

    def drive(self, handshake):
        if not self.valid and self.index < len(self.data):
            self.current = self.data[self.index]
            self.valid = True
        handshake.drive(self.valid, self.current if self.valid else (0, 0, 0, 0, 0))

    def accept(self):
        if self.valid:
            self.index += 1
            self.valid = False
            return self.current
        return None


class ScoreManager:
    def __init__(self, model):
        self.model = model
        self.pending = []
        self.outputs_received = 0
        self.pipeline_delay = 0

    def update_expected(self, input_data):
        self.pending.append(self.model.run(input_data))

    def check_output(self, output):
        if output is None:
            return False

        self.outputs_received += 1

        if self.outputs_received <= self.pipeline_delay:
            return False

        if not self.pending:
            return False

        rs1_exp, rs2_exp = self.pending.pop(0)
        rs1_out, rs2_out = output

        assert int(rs1_out) == int(rs1_exp), \
            f"rs1 mismatch: got {int(rs1_out)} expected {int(rs1_exp)}"
        assert int(rs2_out) == int(rs2_exp), \
            f"rs2 mismatch: got {int(rs2_out)} expected {int(rs2_exp)}"
        return True

    def drain(self):
        return False


class TestManager:
    def __init__(self, dut, stream):
        self.handshake = HandshakeManager(dut)
        self.input = InputManager(stream)
        self.model = ModelManager(dut)
        self.scoreboard = ScoreManager(self.model)
        self.expected_outputs = len(stream)
        self.checked = 0
        self.burst_rate = 1
        self.absorb_rate = 1

    async def run(self):
        try:
            self.input.drive(self.handshake)
            cycle = 0
            while self.checked < self.expected_outputs:
                await FallingEdge(self.handshake.dut.clk_i)
                cycle += 1

                if (cycle % self.burst_rate) == 0:
                    if self.handshake.input_accepted():
                        input_data = self.input.accept()
                        if input_data is not None:
                            self.scoreboard.update_expected(input_data)
                    self.input.drive(self.handshake)
                else:
                    self.handshake.drive(False, (0, 0, 0, 0, 0))

                if (cycle % self.absorb_rate) == 0:
                    if self.scoreboard.pending:
                        if self.scoreboard.check_output(self.handshake.output_value()):
                            self.checked += 1

        finally:
            self.handshake.dut.rs1_addr_i.value = 0
            self.handshake.dut.rs2_addr_i.value = 0
            self.handshake.dut.rd_addr_i.value = 0
            self.handshake.dut.rd_data_i.value = 0
            self.handshake.dut.rd_we_i.value = 0


class HandshakeManager:
    def __init__(self, dut):
        self.dut = dut
        self.last_valid = False

    def drive(self, valid, data):
        rs1_addr, rs2_addr, rd_addr, rd_data, rd_we = data
        self.last_valid = bool(valid)

        self.dut.rs1_addr_i.value = rs1_addr
        self.dut.rs2_addr_i.value = rs2_addr
        self.dut.rd_addr_i.value = rd_addr
        self.dut.rd_data_i.value = rd_data
        self.dut.rd_we_i.value = rd_we

    def input_accepted(self):
        return self.last_valid

    def output_accepted(self):
        return self.last_valid

    def output_value(self):
        signals = [self.dut.rs1_data_o.value, self.dut.rs2_data_o.value]
        if any(not signal.is_resolvable for signal in signals):
            return None
        return tuple(int(signal) for signal in signals)


async def clock_test(dut):
    await Timer(100, unit='ns')
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit='ns').start())
    await Timer(10, unit='ns')


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


def random_stream(depth, width, count):
    mask = (1 << width) - 1
    stream = []
    for rd_addr in range(1, depth):
        stream.append((0, 0, rd_addr, random.randint(0, mask), 1))
    for _ in range(count):
        rs1_addr = random.randint(0, depth - 1)
        rs2_addr = random.randint(0, depth - 1)
        rd_addr = random.randint(0, depth - 1)
        rd_data = random.randint(0, mask)
        rd_we = random.randint(0, 1)
        stream.append((rs1_addr, rs2_addr, rd_addr, rd_data, rd_we))
    return stream


@cocotb.test(skip=False)
async def test_regfile_random(dut):
    await clock_test(dut)
    await reset_test(dut)
    random.seed(42)
    env = TestManager(dut, random_stream(int(dut.DEPTH_P.value), int(dut.WIDTH_P.value), 300))
    await env.run()
