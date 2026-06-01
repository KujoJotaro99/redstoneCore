import random

import cocotb

from cocotb.triggers import Timer

CLOCK_PERIOD_NS = 10

ALU_ADD = 0
ALU_SUB = 1
ALU_SLL = 2
ALU_SLT = 3
ALU_SLTU = 4
ALU_XOR = 5
ALU_SRL = 6
ALU_SRA = 7
ALU_OR = 8
ALU_AND = 9
ALU_PASS = 10


class ModelManager:
    def __init__(self, dut):
        self.width = int(dut.WIDTH_P.value)
        self.word_mod = 1 << self.width
        self.shift_width = (self.width - 1).bit_length()

    def unsigned_word(self, value):
        return int(value) % self.word_mod

    def signed_word(self, value):
        value = self.unsigned_word(value)
        sign_bit = 1 << (self.width - 1)
        return value - self.word_mod if value & sign_bit else value

    def shift_amount(self, value):
        bits = f"{self.unsigned_word(value):0{self.width}b}"
        return int(bits[-self.shift_width:], 2)

    def run(self, input_data):
        alu_src_a, alu_src_b, alu_op = input_data
        alu_src_a = self.unsigned_word(alu_src_a)
        alu_src_b = self.unsigned_word(alu_src_b)
        alu_src_a_signed = self.signed_word(alu_src_a)
        alu_src_b_signed = self.signed_word(alu_src_b)
        shift_amount = self.shift_amount(alu_src_b)

        if alu_op == ALU_ADD:
            alu_result = self.unsigned_word(alu_src_a + alu_src_b)
        elif alu_op == ALU_SUB:
            alu_result = self.unsigned_word(alu_src_a - alu_src_b)
        elif alu_op == ALU_SLL:
            alu_result = self.unsigned_word(alu_src_a << shift_amount)
        elif alu_op == ALU_SLT:
            alu_result = 1 if alu_src_a_signed < alu_src_b_signed else 0
        elif alu_op == ALU_SLTU:
            alu_result = 1 if alu_src_a < alu_src_b else 0
        elif alu_op == ALU_XOR:
            alu_result = alu_src_a ^ alu_src_b
        elif alu_op == ALU_SRL:
            alu_result = alu_src_a >> shift_amount
        elif alu_op == ALU_SRA:
            alu_result = self.unsigned_word(alu_src_a_signed >> shift_amount)
        elif alu_op == ALU_OR:
            alu_result = alu_src_a | alu_src_b
        elif alu_op == ALU_AND:
            alu_result = alu_src_a & alu_src_b
        elif alu_op == ALU_PASS:
            alu_result = alu_src_b
        else:
            alu_result = 0

        alu_zero = 1 if alu_result == 0 else 0
        alu_neg = (alu_result >> (self.width - 1)) & 1
        alu_borrow = int(alu_src_a < alu_src_b) if alu_op == ALU_SUB else int((alu_src_a + alu_src_b) >= self.word_mod)
        alu_overflow = 1 if (
            (alu_op == ALU_ADD and ((alu_src_a >> (self.width - 1)) == (alu_src_b >> (self.width - 1))) and ((alu_result >> (self.width - 1)) != (alu_src_a >> (self.width - 1)))) or
            (alu_op == ALU_SUB and ((alu_src_a >> (self.width - 1)) != (alu_src_b >> (self.width - 1))) and ((alu_result >> (self.width - 1)) != (alu_src_a >> (self.width - 1))))
        ) else 0

        return alu_result, alu_zero, alu_neg, alu_borrow, alu_overflow


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
        handshake.drive(self.valid, self.current if self.valid else (0, 0, 0))

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

        result_exp, zero_exp, neg_exp, carry_exp, overflow_exp = self.pending.pop(0)
        result_out, zero_out, neg_out, carry_out, overflow_out = output

        assert int(result_out) == int(result_exp), \
            f"result mismatch: got {int(result_out)} expected {int(result_exp)}"
        assert int(zero_out) == int(zero_exp), \
            f"zero mismatch: got {int(zero_out)} expected {int(zero_exp)}"
        assert int(neg_out) == int(neg_exp), \
            f"neg mismatch: got {int(neg_out)} expected {int(neg_exp)}"
        assert int(carry_out) == int(carry_exp), \
            f"carry mismatch: got {int(carry_out)} expected {int(carry_exp)}"
        assert int(overflow_out) == int(overflow_exp), \
            f"overflow mismatch: got {int(overflow_out)} expected {int(overflow_exp)}"
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
                await Timer(CLOCK_PERIOD_NS, unit='ns')
                cycle += 1

                if (cycle % self.burst_rate) == 0:
                    if self.handshake.input_accepted():
                        input_data = self.input.accept()
                        if input_data is not None:
                            self.scoreboard.update_expected(input_data)
                    self.input.drive(self.handshake)
                else:
                    self.handshake.drive(False, (0, 0, 0))

                if (cycle % self.absorb_rate) == 0:
                    if self.scoreboard.pending:
                        if self.scoreboard.check_output(self.handshake.output_value()):
                            self.checked += 1

        finally:
            self.handshake.dut.alu_src_a_i.value = 0
            self.handshake.dut.alu_src_b_i.value = 0
            self.handshake.dut.alu_op_i.value = 0


class HandshakeManager:
    def __init__(self, dut):
        self.dut = dut
        self.last_valid = False

    def drive(self, valid, data):
        alu_src_a, alu_src_b, alu_op = data
        self.last_valid = bool(valid)

        self.dut.alu_src_a_i.value = alu_src_a
        self.dut.alu_src_b_i.value = alu_src_b
        self.dut.alu_op_i.value = alu_op

    def input_accepted(self):
        return self.last_valid

    def output_accepted(self):
        return self.last_valid

    def output_value(self):
        signals = [
            self.dut.alu_result_o.value,
            self.dut.alu_zero_o.value,
            self.dut.alu_neg_o.value,
            self.dut.alu_borrow_o.value,
            self.dut.alu_overflow_o.value
        ]
        if any(not signal.is_resolvable for signal in signals):
            return None
        return tuple(int(signal) for signal in signals)


async def init_test(dut):
    dut.alu_src_a_i.value = 0
    dut.alu_src_b_i.value = 0
    dut.alu_op_i.value = 0
    await Timer(CLOCK_PERIOD_NS, unit='ns')


def random_stream(width, count):
    mask = (1 << width) - 1
    stream = []
    ops = [
        ALU_ADD,
        ALU_SUB,
        ALU_SLL,
        ALU_SLT,
        ALU_SLTU,
        ALU_XOR,
        ALU_SRL,
        ALU_SRA,
        ALU_OR,
        ALU_AND,
        ALU_PASS
    ]
    for _ in range(count):
        alu_src_a = random.randint(0, mask)
        alu_src_b = random.randint(0, mask)
        alu_op = random.choice(ops)
        stream.append((alu_src_a, alu_src_b, alu_op))
    return stream


@cocotb.test(skip=False)
async def test_alu_add(dut):
    """add two numbers and check normal result, wraparound carry, signed overflow, negative output, and zero output."""
    await init_test(dut)
    env = TestManager(dut, [
        (0x00000001, 0x00000002, ALU_ADD),
        (0xffffffff, 0x00000001, ALU_ADD),
        (0x7fffffff, 0x00000001, ALU_ADD),
        (0x80000000, 0x80000000, ALU_ADD),
        (0x00000000, 0x00000000, ALU_ADD),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_sub(dut):
    """subtract two numbers and check normal result, borrow, signed overflow, negative output, and zero output."""
    await init_test(dut)
    env = TestManager(dut, [
        (0x00000003, 0x00000001, ALU_SUB),
        (0x00000000, 0x00000001, ALU_SUB),
        (0x80000000, 0x00000001, ALU_SUB),
        (0x7fffffff, 0xffffffff, ALU_SUB),
        (0x12345678, 0x12345678, ALU_SUB),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_sll(dut):
    """shift left by common amounts and confirm only low shift bits are used when source b is 32."""
    await init_test(dut)
    env = TestManager(dut, [
        (0x00000001, 0x00000000, ALU_SLL),
        (0x00000001, 0x00000001, ALU_SLL),
        (0x00000001, 0x0000001f, ALU_SLL),
        (0x00000001, 0x00000020, ALU_SLL),
        (0x80000001, 0x00000004, ALU_SLL),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_slt(dut):
    """compare values as signed numbers, including negative vs positive, equal values, and min vs max."""
    await init_test(dut)
    env = TestManager(dut, [
        (0xffffffff, 0x00000001, ALU_SLT),
        (0x00000001, 0xffffffff, ALU_SLT),
        (0xffffffff, 0xfffffffe, ALU_SLT),
        (0x00000005, 0x00000005, ALU_SLT),
        (0x80000000, 0x7fffffff, ALU_SLT),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_sltu(dut):
    """compare values as unsigned numbers, where high-bit values are large instead of negative."""
    await init_test(dut)
    env = TestManager(dut, [
        (0xffffffff, 0x00000001, ALU_SLTU),
        (0x00000001, 0xffffffff, ALU_SLTU),
        (0x00000005, 0x00000005, ALU_SLTU),
        (0x00000000, 0x00000001, ALU_SLTU),
        (0x80000000, 0x7fffffff, ALU_SLTU),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_xor(dut):
    """xor bit patterns and verify matching bits become 0 while different bits become 1."""
    await init_test(dut)
    env = TestManager(dut, [
        (0xaaaaaaaa, 0x55555555, ALU_XOR),
        (0xffffffff, 0xffffffff, ALU_XOR),
        (0x00000000, 0xffffffff, ALU_XOR),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_srl(dut):
    """shift right logically and verify zeros enter from the left, even when input sign bit is 1."""
    await init_test(dut)
    env = TestManager(dut, [
        (0x80000000, 0x00000000, ALU_SRL),
        (0x80000000, 0x00000001, ALU_SRL),
        (0x80000000, 0x0000001f, ALU_SRL),
        (0x80000000, 0x00000020, ALU_SRL),
        (0xffffffff, 0x00000004, ALU_SRL),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_sra(dut):
    """shift right arithmetically and verify negative values keep filling with 1s from the left."""
    await init_test(dut)
    env = TestManager(dut, [
        (0x80000000, 0x00000000, ALU_SRA),
        (0x80000000, 0x00000001, ALU_SRA),
        (0x80000000, 0x0000001f, ALU_SRA),
        (0x80000000, 0x00000020, ALU_SRA),
        (0x7fffffff, 0x00000004, ALU_SRA),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_or(dut):
    """or bit patterns and verify each output bit is 1 when either input bit is 1."""
    await init_test(dut)
    env = TestManager(dut, [
        (0xaaaaaaaa, 0x55555555, ALU_OR),
        (0x00000000, 0x00000000, ALU_OR),
        (0x12345678, 0x0000ffff, ALU_OR),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_and(dut):
    """and bit patterns and verify each output bit is 1 only when both input bits are 1."""
    await init_test(dut)
    env = TestManager(dut, [
        (0xaaaaaaaa, 0x55555555, ALU_AND),
        (0xffffffff, 0x00000000, ALU_AND),
        (0x12345678, 0x0000ffff, ALU_AND),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_pass(dut):
    """pass source b through unchanged, proving source a does not affect this operation."""
    await init_test(dut)
    env = TestManager(dut, [
        (0x00000000, 0x12345678, ALU_PASS),
        (0xffffffff, 0x00000000, ALU_PASS),
        (0x55555555, 0x80000000, ALU_PASS),
    ])
    await env.run()


@cocotb.test(skip=False)
async def test_alu_random_stream(dut):
    """run many random alu operations and compare every output against the python model."""
    await init_test(dut)
    random.seed(42)
    env = TestManager(dut, random_stream(int(dut.WIDTH_P.value), 400))
    await env.run()