# RedstoneCore

<p align="center">
  <img src="./docs/logo_dark.png" alt="RedstoneCore logo" width="720">
</p>

RedstoneCore is a 5-stage, in-order RV32I core written in SystemVerilog.

This checkpoint is the base integer core: fetch, decode, execute, memory, writeback, hazard handling, branch prediction, split instruction/data caches, AXI-Lite memory access, and a top-level simulation wrapper with unified RAM.

## Current ISA

Supported now:

- `RV32I`
- 32-bit aligned instruction fetch
- byte, halfword, and word load/store data paths
- branch and jump control flow

Future target:

- `Zicsr` for CSR instructions and machine trap groundwork
- `M` for multiply/divide
- `C` for compressed instructions
- `A` for atomics if shared memory, locks, or OS-style software are needed
- `B` for bitmanip performance and compiler codegen support
- `Zifencei` if instruction memory can be modified and re-fetched

For an integer embedded core, `RV32IMC_Zicsr_Zifencei` is a strong next target. Add `A` for atomics. Add `B` for useful optimization, not strict necessity. `F/D` only needed for hardware floating point.

## Architecture

<p align="center">
  <img src="./docs/diagram.svg" alt="RedstoneCore pipeline block diagram" width="720">
</p>

Pipeline:

- IF: PC generation, BTB prediction, instruction cache request, prefetch FIFO
- ID: decode, register file read, hazard detection, load-use scoreboard
- EX: ALU, branch/jump resolution, forwarding
- MEM: load/store formatting, data cache access, writeback source selection
- WB: register file writeback

Memory system:

- split instruction and data `dm_cache` instances
- two `axil_master` instances
- shared imported `axil_dp_ram`
- `fifo_sync` prefetch buffering in IF

## Verification

Unit and top-level tests use cocotb + Verilator.

Run top regression:

```sh
cd rtl/top
make python
```

Build RV32I programs first if `.mem` files are missing:

```sh
cd programs/rv32i
make
```

Run lint:

```sh
cd rtl/top
make lint
```

Current program tests cover arithmetic, immediates, bitwise ops, shifts, branches, loads/stores, signed loads, store masks, dependency chains, loops, function calls, bubble sort, binary search, and prefix sum.

## Project Structure

```text
redstoneCore/
|-- docs/
|   |-- diagram.drawio
|   |-- diagram.svg
|   |-- logo_dark.png
|   |-- logo_light.png
|   |-- VERIFICATION.md
|-- programs/
|   |-- rv32i/
|       |-- Makefile
|       |-- link.ld
|       |-- add_two/
|       |-- add_loop/
|       |-- branch_matrix/
|       |-- bubble_sort/
|       |-- binary_search/
|       |-- prefix_sum/
|-- rtl/
|   |-- alu/
|   |-- axil_master/
|   |-- branch_target_buffer/
|   |-- decode/
|   |-- dm_cache/
|   |-- ex_stage/
|   |-- hazard_unit/
|   |-- id_stage/
|   |-- if_stage/
|   |-- mem_stage/
|   |-- regfile/
|   |-- top/
|   |-- pkg.sv
|-- submodules/
|   |-- imports/
|       |-- axil_dp_ram.v
|       |-- fifo_sync.sv
|       |-- sync_ram_block.sv
|-- syn/
```
