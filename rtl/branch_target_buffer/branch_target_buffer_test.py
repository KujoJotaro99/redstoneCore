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
        self.index_width = (self.depth - 1).bit_length()
        self.word_mod = 1 << self.width
        self.entries = {}
        self.index = 256

    def get_index(self):
        return self.index

    def reset(self):
        self.entries = {}

    def decode_pc(self, pc):
        bits = f"{int(pc) % self.word_mod:0{self.width}b}"
        index_bits = bits[-(self.index_width + 2):-2]
        tag_bits = bits[:-(self.index_width + 2)]
        return int(index_bits, 2), int(tag_bits or "0", 2)

    def run(self, input_data):
        lookup_pc, update_valid, update_pc, update_taken, update_target = input_data
        lookup_index, lookup_tag = self.decode_pc(lookup_pc)
        entry = self.entries.get(lookup_index)
        pred_valid = int(entry is not None and entry["tag"] == lookup_tag)
        pred_taken = pred_valid & (entry["taken"] if entry else 0)
        pred_target = entry["target"] if entry else 0

        if update_valid:
            update_index, update_tag = self.decode_pc(update_pc)
            self.entries[update_index] = {
                "tag": update_tag,
                "taken": int(bool(update_taken)),
                "target": int(update_target) % self.word_mod,
            }

        return pred_valid, pred_taken, pred_target


class InputManager:
    def __init__(self, handshake, stream):
        self.handshake = handshake
        self.stream = iter(stream)

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
    def __init__(self, dut, stream, count=256):
        self.dut = dut
        self.handshake = HandshakeManager(dut)
        self.input = InputManager(self.handshake, stream)
        self.model = ModelManager(dut)
        self.model.index = count
        self.scoreboard = ScoreManager(self.model, self.handshake)

    async def run(self):
        try:
            while self.scoreboard.get_index() < self.model.get_index():
                self.input.drive()
                await Timer(1, unit="ns") # output is combo
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
async def test_branch_target_buffer_reset_miss(dut):
    """after reset, no pc has been learned yet, so every lookup should miss."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0x00000000, 0, 0x00000000, 0, 0x00000000),
        (0x00000040, 0, 0x00000000, 0, 0x00000000),
    ]

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_update_lookup_hit(dut):
    """teach the buffer one taken branch, then look up the same pc and expect the saved target."""
    await clock_test(dut)
    await reset_test(dut)

    stream = [
        (0x00000020, 1, 0x00000020, 1, 0x00000100),
        (0x00000020, 0, 0x00000000, 0, 0x00000000),
    ]

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_index_alias(dut):
    """write two pcs that share one slot, proving the newer tag replaces the older tag."""
    await clock_test(dut)
    await reset_test(dut)

    depth = int(dut.DEPTH_P.value)
    pc_a = 0x00000000
    pc_b = depth * 4

    stream = [
        (pc_a, 1, pc_a, 1, 0x00000100),
        (pc_a, 0, 0x00000000, 0, 0x00000000),
        (pc_b, 1, pc_b, 1, 0x00000200),
        (pc_a, 0, 0x00000000, 0, 0x00000000),
        (pc_b, 0, 0x00000000, 0, 0x00000000),
    ]

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_overwrite(dut):
    """update the same pc twice and verify the second target overwrites the first target."""
    await clock_test(dut)
    await reset_test(dut)

    pc = 0x00000010
    stream = [
        (pc, 1, pc, 1, 0x00000100),
        (pc, 0, 0x00000000, 0, 0x00000000),
        (pc, 1, pc, 1, 0x00000200),
        (pc, 0, 0x00000000, 0, 0x00000000),
    ]

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_not_taken_entry(dut):
    """save a branch as not taken and verify lookup is valid but prediction says not taken."""
    await clock_test(dut)
    await reset_test(dut)

    pc = 0x00000030
    stream = [
        (pc, 1, pc, 0, 0x00000100),
        (pc, 0, 0x00000000, 0, 0x00000000),
    ]

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_update_valid_ignore(dut):
    """drive update fields while update_valid is low and verify nothing is written."""
    await clock_test(dut)
    await reset_test(dut)

    pc = 0x00000024
    stream = [
        (pc, 0, pc, 1, 0x00000100),
        (pc, 0, 0x00000000, 0, 0x00000000),
    ]

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_full_table_fill(dut):
    """fill every buffer slot with a different pc and verify each slot can be read back."""
    await clock_test(dut)
    await reset_test(dut)

    depth = int(dut.DEPTH_P.value)
    stream = []
    for index in range(depth):
        pc = index * 4
        target = 0x00000100 + (index * 4)
        stream.append((pc, 1, pc, index & 1, target))
    for index in range(depth):
        pc = index * 4
        stream.append((pc, 0, 0x00000000, 0, 0x00000000))

    manager = TestManager(dut, stream, len(stream))
    await manager.run()


@cocotb.test(skip=False)
async def test_branch_target_buffer_random(dut):
    """run random lookups and updates, then compare every prediction against the python model."""
    await clock_test(dut)
    await reset_test(dut)

    random.seed(42)
    pc_count = 1 << (int(dut.WIDTH_P.value) - 2)
    depth = int(dut.DEPTH_P.value)
    pc_list = [random.randrange(0, pc_count) * 4 for _ in range(depth)]

    stream = (
        (
            random.choice(pc_list),
            random.getrandbits(1),
            random.choice(pc_list),
            random.getrandbits(1),
            random.randrange(0, pc_count) * 4
        )
        for _ in count()
    )

    manager = TestManager(dut, stream)
    await manager.run()
