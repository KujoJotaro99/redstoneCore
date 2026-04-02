import random
from itertools import count
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

CLOCK_PERIOD_NS = 10


class ModelManager:
    def __init__(self, dut):
        self.width = int(dut.WIDTH_P.value)
        self.depth = int(dut.DEPTH_P.value)
        self.word_mod = 1 << self.width
        self.regs = [0 for _ in range(self.depth)]
        self.index = self.depth + 300

    def get_index(self):
        return self.index

    def reset(self):
        self.regs = [0 for _ in range(self.depth)]

    def unsigned_word(self, value):
        return int(value) % self.word_mod

    def run(self, input_data):
        rs1_addr, rs2_addr, rd_addr, rd_data, rd_we = input_data
        rd_hit_rs1 = rd_we and rd_addr != 0 and rd_addr == rs1_addr
        rd_hit_rs2 = rd_we and rd_addr != 0 and rd_addr == rs2_addr

        rs1_data = 0 if rs1_addr == 0 else self.regs[rs1_addr]
        rs2_data = 0 if rs2_addr == 0 else self.regs[rs2_addr]

        if rd_hit_rs1:
            rs1_data = self.unsigned_word(rd_data)
        if rd_hit_rs2:
            rs2_data = self.unsigned_word(rd_data)

        if rd_we and rd_addr != 0:
            self.regs[rd_addr] = self.unsigned_word(rd_data)

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
                await RisingEdge(self.dut.clk_i)
                await Timer(1, unit="ns")
                if self.handshake.input_accepted():
                    self.scoreboard.update_expected()
                self.scoreboard.check_output()
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
async def test_regfile_x0_reads_zero(dut):
    """read x0 on both ports and verify it always returns zero."""
    await clock_test(dut)
    await reset_test(dut)

    dut.rs1_addr_i.value = 0
    dut.rs2_addr_i.value = 0
    dut.rd_addr_i.value = 1
    dut.rd_data_i.value = 0x12345678
    dut.rd_we_i.value = 1
    await Timer(1, unit="ns")

    assert int(dut.rs1_data_o.value) == 0
    assert int(dut.rs2_data_o.value) == 0


@cocotb.test(skip=False)
async def test_regfile_write_x0_ignored(dut):
    """try to write x0, then read x0 back and verify the write was ignored."""
    await clock_test(dut)
    await reset_test(dut)

    dut.rs1_addr_i.value = 0
    dut.rs2_addr_i.value = 0
    dut.rd_addr_i.value = 0
    dut.rd_data_i.value = 0xffffffff
    dut.rd_we_i.value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ns")

    assert int(dut.rs1_data_o.value) == 0
    assert int(dut.rs2_data_o.value) == 0


@cocotb.test(skip=False)
async def test_regfile_write_read_next_cycle(dut):
    """write one normal register, then read it on both ports after the clock edge."""
    await clock_test(dut)
    await reset_test(dut)

    dut.rs1_addr_i.value = 0
    dut.rs2_addr_i.value = 0
    dut.rd_addr_i.value = 7
    dut.rd_data_i.value = 0x13572468
    dut.rd_we_i.value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ns")

    dut.rs1_addr_i.value = 7
    dut.rs2_addr_i.value = 7
    dut.rd_we_i.value = 0
    await Timer(1, unit="ns")

    assert int(dut.rs1_data_o.value) == 0x13572468
    assert int(dut.rs2_data_o.value) == 0x13572468


@cocotb.test(skip=False)
async def test_regfile_independent_registers(dut):
    """write two different registers and verify one write does not change the other register."""
    await clock_test(dut)
    await reset_test(dut)

    dut.rd_addr_i.value = 1
    dut.rd_data_i.value = 0x11111111
    dut.rd_we_i.value = 1
    await RisingEdge(dut.clk_i)

    dut.rd_addr_i.value = 2
    dut.rd_data_i.value = 0x22222222
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ns")

    dut.rs1_addr_i.value = 1
    dut.rs2_addr_i.value = 2
    dut.rd_we_i.value = 0
    await Timer(1, unit="ns")

    assert int(dut.rs1_data_o.value) == 0x11111111
    assert int(dut.rs2_data_o.value) == 0x22222222


@cocotb.test(skip=False)
async def test_regfile_write_first(dut):
    """write and read the same register in the same cycle and verify read data uses the new write value."""
    await clock_test(dut)
    await reset_test(dut)

    dut.rs1_addr_i.value = 5
    dut.rs2_addr_i.value = 6
    dut.rd_addr_i.value = 5
    dut.rd_data_i.value = 0x12345678
    dut.rd_we_i.value = 1
    await Timer(1, unit="ns")

    assert int(dut.rs1_data_o.value) == 0x12345678

    dut.rs1_addr_i.value = 5
    dut.rs2_addr_i.value = 6
    dut.rd_addr_i.value = 6
    dut.rd_data_i.value = 0x87654321
    dut.rd_we_i.value = 1
    await Timer(1, unit="ns")

    assert int(dut.rs2_data_o.value) == 0x87654321

    dut.rs1_addr_i.value = 0
    dut.rs2_addr_i.value = 0
    dut.rd_addr_i.value = 0
    dut.rd_data_i.value = 0xffffffff
    dut.rd_we_i.value = 1
    await Timer(1, unit="ns")

    assert int(dut.rs1_data_o.value) == 0
    assert int(dut.rs2_data_o.value) == 0


@cocotb.test(skip=False)
async def test_regfile_sequential_sweep(dut):
    """write a unique value to every nonzero register, then read each value back."""
    await clock_test(dut)
    await reset_test(dut)

    depth = int(dut.DEPTH_P.value)

    for rd_addr in range(1, depth):
        dut.rd_addr_i.value = rd_addr
        dut.rd_data_i.value = 0x10000000 + rd_addr
        dut.rd_we_i.value = 1
        await RisingEdge(dut.clk_i)

    dut.rd_we_i.value = 0
    for rs_addr in range(1, depth):
        dut.rs1_addr_i.value = rs_addr
        dut.rs2_addr_i.value = rs_addr
        await Timer(1, unit="ns")
        assert int(dut.rs1_data_o.value) == 0x10000000 + rs_addr
        assert int(dut.rs2_data_o.value) == 0x10000000 + rs_addr


@cocotb.test(skip=False)
async def test_regfile_random_stream(dut):
    """run random reads and writes, then compare both read ports against the python register model."""
    await clock_test(dut)
    await reset_test(dut)

    random.seed(42)
    word_mod = 1 << int(dut.WIDTH_P.value)
    depth = int(dut.DEPTH_P.value)

    stream = (
        (0, 0, (index % depth), random.randrange(0, word_mod), 1)
        if index < depth else
        (
            random.randint(0, depth - 1),
            random.randint(0, depth - 1),
            random.randint(0, depth - 1),
            random.randrange(0, word_mod),
            random.randint(0, 1)
        )
        for index in count(1)
    )

    manager = TestManager(dut, stream)
    await manager.run()
