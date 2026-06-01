import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer
from cocotbext.axi import (
    AxiLiteBus,
    AxiLiteRam,
)

CLOCK_PERIOD_NS = 10


class ModelManager:
    def run(self, input_data):
        if input_data["write"]:
            return 0, 0
        return int(input_data["rdata"]), 0


class InputManager:
    def __init__(self, handshake, stream):
        self.handshake = handshake
        self.stream = list(stream)
        self.index = 0
        self.valid = False
        self.current = None

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
        self.pending.append((input_data, self.model.run(input_data)))

    def check_output(self):
        output = self.handshake.output_value()
        if output is None:
            return False

        input_data, expected = self.pending.pop(0)
        data_exp, resp_exp = expected
        data_out, resp_out = output

        assert data_out == int(data_exp), \
            f"data mismatch: got {data_out:#010x} expected {int(data_exp):#010x} at transaction {self.index + 1}"
        assert resp_out == int(resp_exp), \
            f"resp mismatch: got {resp_out:#03b} expected {int(resp_exp):#03b} at transaction {self.index + 1}"

        if input_data["write"]:
            ram_data = self.handshake.axil_ram.read_dword(int(input_data["addr"]))
            assert ram_data == int(input_data["expected_mem"]), \
                f"ram mismatch: got {ram_data:#010x} expected {int(input_data['expected_mem']):#010x}"

        self.index += 1
        return True


class HandshakeManager:
    def __init__(self, dut):
        self.dut = dut
        self.current = None
        self.last_valid = False
        self.last_ready = False
        self.active = None
        self.response_wait = 0
        self.last_response = None

        self.axil_ram = AxiLiteRam(
            AxiLiteBus.from_prefix(dut, "m_axil"),
            dut.clk_i,
            dut.rstn_i,
            reset_active_level=False,
            size=4096,
        )

    def drive(self, valid, data):
        self.current = data
        self.last_valid = bool(valid)
        self.last_ready = bool(int(self.dut.mem_cache_req_ready_o.value))

        self.dut.cache_mem_req_valid_i.value = 1 if valid else 0
        self.dut.cache_mem_req_write_i.value = int(data["write"]) if valid else 0
        self.dut.cache_mem_req_addr_i.value = int(data["addr"]) if valid else 0
        self.dut.cache_mem_req_wdata_i.value = int(data["wdata"]) if valid and data["write"] else 0
        self.dut.cache_mem_req_wstrb_i.value = int(data["wstrb"]) if valid and data["write"] else 0

    def input_accepted(self):
        return self.last_valid and self.last_ready

    def start_transaction(self, data):
        self.active = data
        self.response_wait = 0
        self.last_response = None

        if not data["write"]:
            self.axil_ram.write_dword(int(data["addr"]), int(data["rdata"]))
        elif "initial_mem" in data:
            self.axil_ram.write_dword(int(data["addr"]), int(data["initial_mem"]))

    def update_response_ready(self):
        if self.active is None:
            self.dut.cache_mem_rsp_ready_i.value = 0
            return

        if int(self.dut.mem_cache_rsp_valid_o.value):
            if self.last_response is None:
                self.last_response = (
                    int(self.dut.mem_cache_rsp_rdata_o.value),
                    int(self.dut.mem_cache_rsp_resp_o.value)
                )
            else:
                data_out, resp_out = self.last_response
                assert int(self.dut.mem_cache_rsp_rdata_o.value) == data_out
                assert int(self.dut.mem_cache_rsp_resp_o.value) == resp_out

            if self.response_wait < int(self.active["rsp_ready_delay"]):
                self.dut.cache_mem_rsp_ready_i.value = 0
                self.response_wait += 1
            else:
                self.dut.cache_mem_rsp_ready_i.value = 1
        else:
            self.dut.cache_mem_rsp_ready_i.value = 0

    def output_value(self):
        if not int(self.dut.mem_cache_rsp_valid_o.value):
            return None
        if not int(self.dut.cache_mem_rsp_ready_i.value):
            return None

        data = self.dut.mem_cache_rsp_rdata_o.value
        resp = self.dut.mem_cache_rsp_resp_o.value
        if not data.is_resolvable or not resp.is_resolvable:
            return None

        self.active = None
        return int(data), int(resp)


class TestManager:
    def __init__(self, dut, stream):
        self.dut = dut
        self.handshake = HandshakeManager(dut)
        self.input = InputManager(self.handshake, stream)
        self.model = ModelManager()
        self.scoreboard = ScoreManager(self.model, self.handshake)
        self.expected = len(stream)
        self.checked = 0

    async def run(self):
        try:
            self.input.drive()
            cycles = 0
            while self.checked < self.expected:
                await FallingEdge(self.dut.clk_i)
                await Timer(1, unit="ns")

                if self.handshake.input_accepted():
                    input_data = self.input.accept()
                    if input_data is not None:
                        self.scoreboard.update_expected(input_data)
                        self.handshake.start_transaction(input_data)

                self.handshake.update_response_ready()
                await Timer(1, unit="ns")

                if self.scoreboard.check_output():
                    self.checked += 1

                self.input.drive()
                cycles += 1
                assert cycles < (self.expected * 40 + 40), "axil_master test timeout"
        finally:
            self.dut.cache_mem_req_valid_i.value = 0
            self.dut.cache_mem_req_write_i.value = 0
            self.dut.cache_mem_req_addr_i.value = 0
            self.dut.cache_mem_req_wdata_i.value = 0
            self.dut.cache_mem_req_wstrb_i.value = 0
            self.dut.cache_mem_rsp_ready_i.value = 0


@cocotb.test(skip=False)
async def test_axil_master_write_word(dut):
    """send one full-word cache write and verify cocotbext axi ram receives the word."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    dut.rstn_i.value = 0
    dut.cache_mem_req_valid_i.value = 0
    dut.cache_mem_req_write_i.value = 0
    dut.cache_mem_req_addr_i.value = 0
    dut.cache_mem_req_wdata_i.value = 0
    dut.cache_mem_req_wstrb_i.value = 0
    dut.cache_mem_rsp_ready_i.value = 0
    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)

    stream = [
        {
            "write": 1,
            "addr": 0x20,
            "wdata": 0x11223344,
            "wstrb": 0b1111,
            "expected_mem": 0x11223344,
            "rsp_ready_delay": 0,
        },
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_axil_master_write_byte_strobes(dut):
    """write selected byte lanes and verify cocotbext axi ram preserves untouched bytes."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    dut.rstn_i.value = 0
    dut.cache_mem_req_valid_i.value = 0
    dut.cache_mem_req_write_i.value = 0
    dut.cache_mem_req_addr_i.value = 0
    dut.cache_mem_req_wdata_i.value = 0
    dut.cache_mem_req_wstrb_i.value = 0
    dut.cache_mem_rsp_ready_i.value = 0
    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)

    stream = [
        {
            "write": 1,
            "addr": 0x24,
            "initial_mem": 0xaabbccdd,
            "wdata": 0x00110022,
            "wstrb": 0b0101,
            "expected_mem": 0xaa11cc22,
            "rsp_ready_delay": 0,
        },
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_axil_master_read_word(dut):
    """preload cocotbext axi ram and verify one cache read returns that word."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    dut.rstn_i.value = 0
    dut.cache_mem_req_valid_i.value = 0
    dut.cache_mem_req_write_i.value = 0
    dut.cache_mem_req_addr_i.value = 0
    dut.cache_mem_req_wdata_i.value = 0
    dut.cache_mem_req_wstrb_i.value = 0
    dut.cache_mem_rsp_ready_i.value = 0
    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)

    stream = [
        {
            "write": 0,
            "addr": 0x80,
            "wdata": 0,
            "wstrb": 0,
            "rdata": 0xcafebabe,
            "rsp_ready_delay": 0,
        },
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_axil_master_response_backpressure(dut):
    """hold cache response ready low and verify response data stays stable until accepted."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    dut.rstn_i.value = 0
    dut.cache_mem_req_valid_i.value = 0
    dut.cache_mem_req_write_i.value = 0
    dut.cache_mem_req_addr_i.value = 0
    dut.cache_mem_req_wdata_i.value = 0
    dut.cache_mem_req_wstrb_i.value = 0
    dut.cache_mem_rsp_ready_i.value = 0
    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)

    stream = [
        {
            "write": 0,
            "addr": 0x84,
            "wdata": 0,
            "wstrb": 0,
            "rdata": 0x12345678,
            "rsp_ready_delay": 3,
        },
    ]

    manager = TestManager(dut, stream)
    await manager.run()


@cocotb.test(skip=False)
async def test_axil_master_read_write_random(dut):
    """randomly mix cache reads, full writes, and partial writes through cocotbext axi ram."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    dut.rstn_i.value = 0
    dut.cache_mem_req_valid_i.value = 0
    dut.cache_mem_req_write_i.value = 0
    dut.cache_mem_req_addr_i.value = 0
    dut.cache_mem_req_wdata_i.value = 0
    dut.cache_mem_req_wstrb_i.value = 0
    dut.cache_mem_rsp_ready_i.value = 0
    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)

    random.seed(42)
    stream = []
    for i in range(16):
        write = random.randint(0, 1)
        addr = 0x100 + (i * 4)

        if write:
            initial_mem = random.randrange(0, 2**32)
            wdata = random.randrange(0, 2**32)
            wstrb = random.randint(1, 0b1111)
            expected_mem = initial_mem

            if wstrb & 0b0001:
                expected_mem = (expected_mem & 0xffffff00) | (wdata & 0x000000ff)
            if wstrb & 0b0010:
                expected_mem = (expected_mem & 0xffff00ff) | (wdata & 0x0000ff00)
            if wstrb & 0b0100:
                expected_mem = (expected_mem & 0xff00ffff) | (wdata & 0x00ff0000)
            if wstrb & 0b1000:
                expected_mem = (expected_mem & 0x00ffffff) | (wdata & 0xff000000)

            stream.append({
                "write": 1,
                "addr": addr,
                "initial_mem": initial_mem,
                "wdata": wdata,
                "wstrb": wstrb,
                "expected_mem": expected_mem,
                "rsp_ready_delay": random.randint(0, 3),
            })
        else:
            stream.append({
                "write": 0,
                "addr": addr,
                "wdata": 0,
                "wstrb": 0,
                "rdata": random.randrange(0, 2**32),
                "rsp_ready_delay": random.randint(0, 3),
            })

    manager = TestManager(dut, stream)
    await manager.run()
