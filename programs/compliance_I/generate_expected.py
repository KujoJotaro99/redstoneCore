#!/usr/bin/env python3
import argparse
from pathlib import Path

MASK32 = 0xffffffff
TEXT_BASE = 0x00000000
DATA_BASE = 0x10000000

def u32(value):
    return value & MASK32

def s32(value):
    value &= MASK32
    return value - 0x100000000 if value & 0x80000000 else value

def sign_extend(value, bits):
    mask = 1 << (bits - 1)
    return (value & (mask - 1)) - (value & mask)

def load_words(path, base_addr, memory):
    if not path.exists():
        return
    addr = base_addr
    for line in path.read_text().splitlines():
        word = line.strip()
        if not word:
            continue
        value = int(word, 16)
        for i in range(4):
            memory[addr + i] = (value >> (8 * i)) & 0xff
        addr += 4

def load_u8(memory, addr):
    return memory.get(addr, 0)

def load_u16(memory, addr):
    return load_u8(memory, addr) | (load_u8(memory, addr + 1) << 8)

def load_u32(memory, addr):
    return load_u16(memory, addr) | (load_u16(memory, addr + 2) << 16)

def store_u8(memory, addr, value):
    memory[addr] = value & 0xff

def store_u16(memory, addr, value):
    store_u8(memory, addr, value)
    store_u8(memory, addr + 1, value >> 8)

def store_u32(memory, addr, value):
    store_u16(memory, addr, value)
    store_u16(memory, addr + 2, value >> 16)

def parse_symbols(path):
    symbols = {}
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("0x"):
            symbols[parts[-1]] = int(parts[0], 16)
    return symbols

def imm_i(instr):
    return sign_extend(instr >> 20, 12)

def imm_s(instr):
    return sign_extend(((instr >> 7) & 0x1f) | (((instr >> 25) & 0x7f) << 5), 12)

def imm_b(instr):
    return sign_extend(
        (((instr >> 8) & 0xf) << 1) |
        (((instr >> 25) & 0x3f) << 5) |
        (((instr >> 7) & 0x1) << 11) |
        (((instr >> 31) & 0x1) << 12),
        13
    )

def imm_u(instr):
    return instr & 0xfffff000

def imm_j(instr):
    return sign_extend(
        (((instr >> 21) & 0x3ff) << 1) |
        (((instr >> 20) & 0x1) << 11) |
        (((instr >> 12) & 0xff) << 12) |
        (((instr >> 31) & 0x1) << 20),
        21
    )

def run(memory, code_end, max_cycles):
    regs = [0] * 32
    pc = 0
    for _ in range(max_cycles):
        if pc == code_end:
            return
        instr = load_u32(memory, pc)
        opcode = instr & 0x7f
        rd = (instr >> 7) & 0x1f
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1f
        rs2 = (instr >> 20) & 0x1f
        funct7 = (instr >> 25) & 0x7f
        next_pc = u32(pc + 4)

        if opcode == 0x37:
            regs[rd] = imm_u(instr)
        elif opcode == 0x17:
            regs[rd] = u32(pc + imm_u(instr))
        elif opcode == 0x6f:
            regs[rd] = next_pc
            next_pc = u32(pc + imm_j(instr))
        elif opcode == 0x67:
            target = u32((regs[rs1] + imm_i(instr)) & ~1)
            regs[rd] = next_pc
            next_pc = target
        elif opcode == 0x63:
            a = regs[rs1]
            b = regs[rs2]
            taken = (
                (funct3 == 0x0 and a == b) or
                (funct3 == 0x1 and a != b) or
                (funct3 == 0x4 and s32(a) < s32(b)) or
                (funct3 == 0x5 and s32(a) >= s32(b)) or
                (funct3 == 0x6 and a < b) or
                (funct3 == 0x7 and a >= b)
            )
            if taken:
                next_pc = u32(pc + imm_b(instr))
        elif opcode == 0x03:
            addr = u32(regs[rs1] + imm_i(instr))
            if funct3 == 0x0:
                regs[rd] = u32(sign_extend(load_u8(memory, addr), 8))
            elif funct3 == 0x1:
                regs[rd] = u32(sign_extend(load_u16(memory, addr), 16))
            elif funct3 == 0x2:
                regs[rd] = load_u32(memory, addr)
            elif funct3 == 0x4:
                regs[rd] = load_u8(memory, addr)
            elif funct3 == 0x5:
                regs[rd] = load_u16(memory, addr)
            else:
                raise RuntimeError(f"unsupported load funct3={funct3}")
        elif opcode == 0x23:
            addr = u32(regs[rs1] + imm_s(instr))
            if funct3 == 0x0:
                store_u8(memory, addr, regs[rs2])
            elif funct3 == 0x1:
                store_u16(memory, addr, regs[rs2])
            elif funct3 == 0x2:
                store_u32(memory, addr, regs[rs2])
            else:
                raise RuntimeError(f"unsupported store funct3={funct3}")
        elif opcode == 0x13:
            imm = imm_i(instr)
            shamt = (instr >> 20) & 0x1f
            if funct3 == 0x0:
                regs[rd] = u32(regs[rs1] + imm)
            elif funct3 == 0x2:
                regs[rd] = 1 if s32(regs[rs1]) < imm else 0
            elif funct3 == 0x3:
                regs[rd] = 1 if regs[rs1] < u32(imm) else 0
            elif funct3 == 0x4:
                regs[rd] = u32(regs[rs1] ^ imm)
            elif funct3 == 0x6:
                regs[rd] = u32(regs[rs1] | imm)
            elif funct3 == 0x7:
                regs[rd] = u32(regs[rs1] & imm)
            elif funct3 == 0x1 and funct7 == 0x00:
                regs[rd] = u32(regs[rs1] << shamt)
            elif funct3 == 0x5 and funct7 == 0x00:
                regs[rd] = regs[rs1] >> shamt
            elif funct3 == 0x5 and funct7 == 0x20:
                regs[rd] = u32(s32(regs[rs1]) >> shamt)
            else:
                raise RuntimeError(f"unsupported op-imm instr=0x{instr:08x}")
        elif opcode == 0x33:
            if funct3 == 0x0 and funct7 == 0x00:
                regs[rd] = u32(regs[rs1] + regs[rs2])
            elif funct3 == 0x0 and funct7 == 0x20:
                regs[rd] = u32(regs[rs1] - regs[rs2])
            elif funct3 == 0x1 and funct7 == 0x00:
                regs[rd] = u32(regs[rs1] << (regs[rs2] & 0x1f))
            elif funct3 == 0x2 and funct7 == 0x00:
                regs[rd] = 1 if s32(regs[rs1]) < s32(regs[rs2]) else 0
            elif funct3 == 0x3 and funct7 == 0x00:
                regs[rd] = 1 if regs[rs1] < regs[rs2] else 0
            elif funct3 == 0x4 and funct7 == 0x00:
                regs[rd] = u32(regs[rs1] ^ regs[rs2])
            elif funct3 == 0x5 and funct7 == 0x00:
                regs[rd] = regs[rs1] >> (regs[rs2] & 0x1f)
            elif funct3 == 0x5 and funct7 == 0x20:
                regs[rd] = u32(s32(regs[rs1]) >> (regs[rs2] & 0x1f))
            elif funct3 == 0x6 and funct7 == 0x00:
                regs[rd] = u32(regs[rs1] | regs[rs2])
            elif funct3 == 0x7 and funct7 == 0x00:
                regs[rd] = u32(regs[rs1] & regs[rs2])
            else:
                raise RuntimeError(f"unsupported op instr=0x{instr:08x}")
        elif opcode == 0x0f:
            pass
        else:
            raise RuntimeError(f"unsupported opcode=0x{opcode:02x} pc=0x{pc:08x} instr=0x{instr:08x}")

        regs[0] = 0
        pc = next_pc
    raise RuntimeError("reference run did not reach rvtest_code_end")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("test_dir", type=Path)
    parser.add_argument("--max-cycles", type=int, default=1000000)
    args = parser.parse_args()

    memory = {}
    load_words(args.test_dir / "program_imem.mem", TEXT_BASE, memory)
    load_words(args.test_dir / "program_dmem.mem", DATA_BASE, memory)
    symbols = parse_symbols(args.test_dir / "program.map")
    run(memory, symbols["rvtest_code_end"], args.max_cycles)

    begin = symbols["begin_signature"]
    end = symbols["end_signature"]
    with (args.test_dir / "expected_signature.mem").open("w") as out:
        for addr in range(begin, end, 4):
            out.write(f"{load_u32(memory, addr):08x}\n")

if __name__ == "__main__":
    main()
