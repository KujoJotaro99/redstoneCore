import random
from itertools import count
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

CLOCK_PERIOD_NS = 10


class ModelManager:
    def __init__(self, dut):
        self.width = int(dut.WIDTH_P.value)
        self.entries = int(dut.ENTRIES_P.value)
        self.index_width = (self.entries - 1).bit_length()
        self.mask = (1 << self.width) - 1
        self.valid = [0 for _ in range(self.entries)]
        self.tag = [0 for _ in range(self.entries)]
        self.taken = [0 for _ in range(self.entries)]
        self.target = [0 for _ in range(self.entries)]
        self.index = 256

    def get_index(self):
        return self.index

    def reset(self):
        self.valid = [0 for _ in range(self.entries)]
        self.tag = [0 for _ in range(self.entries)]
        self.taken = [0 for _ in range(self.entries)]
        self.target = [0 for _ in range(self.entries)]

    def run(self, input_data):
        lookup_pc, update_valid, update_pc, update_taken, update_target = input_data
        lookup_index = (lookup_pc >> 2) & (self.entries - 1)
        lookup_tag = lookup_pc >> (self.index_width + 2)
        pred_valid = self.valid[lookup_index] & (self.tag[lookup_index] == lookup_tag)
        pred_taken = pred_valid & self.taken[lookup_index]
        pred_target = self.target[lookup_index]

        if update_valid:
            update_index = (update_pc >> 2) & (self.entries - 1)
            update_tag = update_pc >> (self.index_width + 2)
            self.valid[update_index] = 1
            self.tag[update_index] = update_tag
            self.taken[update_index] = int(bool(update_taken))
            self.target[update_index] = int(update_target) & self.mask

        return pred_valid, pred_taken, pred_target


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

        pred_valid_exp, pred_taken_exp, pred_target_exp = self.pending.pop(0)
        pred_valid_out, pred_taken_out, pred_target_out = output

        assert pred_valid_out == int(pred_valid_exp), \
            f"pred valid mismatch: got {pred_valid_out} expected {int(pred_valid_exp)} at transaction {self.index + 1}"
        assert pred_taken_out == int(pred_taken_exp), \
            f"pred taken mismatch: got {pred_taken_out} expected {int(pred_taken_exp)} at transaction {self.index + 1}"
        assert pred_target_out == int(pred_target_exp), \
            f"pred target mismatch: got {pred_target_out} expected {int(pred_target_exp)} at transaction {self.index + 1}"

        self.index += 1
        return True


class HandshakeManager:
    def __init__(self, dut):
        self.dut = dut
        self.last_valid = False
        self.current = (0, 0, 0, 0, 0)

    def drive(self, data):
        lookup_pc, update_valid, update_pc, update_taken, update_target = data
        self.last_valid = True
        self.current = data

        self.dut.lookup_pc_i.value = lookup_pc
        self.dut.update_valid_i.value = update_valid
        self.dut.update_pc_i.value = update_pc
        self.dut.update_taken_i.value = update_taken
        self.dut.update_target_i.value = update_target

    def input_accepted(self):
        return self.last_valid

    def input_value(self):
        return self.current

    def output_value(self):
        signals = [self.dut.pred_valid_o.value, self.dut.pred_taken_o.value, self.dut.pred_target_o.value]
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
            self.dut.lookup_pc_i.value = 0
            self.dut.update_valid_i.value = 0
            self.dut.update_pc_i.value = 0
            self.dut.update_taken_i.value = 0
            self.dut.update_target_i.value = 0


async def clock_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await Timer(1, unit="ns")


async def reset_test(dut):
    dut.rstn_i.value = 0
    dut.lookup_pc_i.value = 0
    dut.update_valid_i.value = 0
    dut.update_pc_i.value = 0
    dut.update_taken_i.value = 0
    dut.update_target_i.value = 0

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)

    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)


@cocotb.test(skip=False)
async def test_branch_target_buffer_random(dut):
    await clock_test(dut)
    await reset_test(dut)

    random.seed(42)
    mask = (1 << int(dut.WIDTH_P.value)) - 1
    entries = int(dut.ENTRIES_P.value)
    pc_list = [((random.randint(0, mask) >> 2) << 2) for _ in range(entries)]

    stream = (
        (
            random.choice(pc_list),
            random.getrandbits(1),
            random.choice(pc_list),
            random.getrandbits(1),
            ((random.randint(0, mask) >> 2) << 2)
        )
        for _ in count()
    )

    manager = TestManager(dut, stream)
    await manager.run()
