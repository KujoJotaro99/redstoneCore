import random

import cocotb

from cocotb.clock import Clock

from cocotb.triggers import FallingEdge, Timer

CLOCK_PERIOD_NS = 10


class ModelManager:
    def __init__(self):

    def run(self):
        

class InputManager:
    def __init__(self):

    def drive(self):

    def accept(self):


class ScoreManager:
    def __init__(self):

    def update_expected(self):

    def check_output(self):

    def drain(self):


class TestManager:
    def __init__(self):

    async def run(self):


class HandshakeManager:
    def __init__(self):

    def drive(self):

    def output(self):


async def clock_test(dut):
    await Timer(100, unit='ns')
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit='ns').start())
    await Timer(10, unit='ns')


async def reset_test(dut):
    dut.rstn_i.value = 0
    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await FallingEdge(dut.clk_i)
