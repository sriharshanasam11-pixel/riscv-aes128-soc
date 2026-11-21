# RISC-V System-on-Chip (SoC) with Configurable AES-128 Accelerator

## Project Overview
This repository contains the complete RTL design, software stack, testbenches, simulation models, and architecture documentation for a 32-bit RISC-V (RV32I) System-on-Chip (SoC). The SoC integrates mandatory computing and peripheral resources alongside three custom/integrated IP blocks:
1. **AES-128 Encryption/Decryption Accelerator (Custom IP)**: 10-round iterative pipeline implementing NIST FIPS-197 symmetric cipher acceleration.
2. **Pseudo-Random Number Generator (PRNG, Custom IP)**: 32-bit Galois LFSR and Marsaglia Xorshift32 generator for session keys, salts, and dynamic initialization vectors.
3. **SPI Master Controller (Integrated IP)**: High-speed serial master for streaming ciphertexts off-chip to external flash or host radios.

---

## Directory Structure
```
riscv_aes_soc/
├── docs/
│   ├── ABSTRACT.md                     # 2-Page Abstract matching faculty guidelines
│   └── ARCHITECTURE_SPECIFICATION.md   # Complete Architecture Document (Block diagram, memory map, register interface, bus protocol)
├── rtl/
│   ├── core/                           # RV32I Processor Core (ALU, RegFile, Control, Core Top)
│   ├── bus/                            # Wishbone B4 Crossbar Interconnect & Address Decoder
│   ├── memory/                         # 16 KB Instruction ROM & 16 KB Data SRAM
│   ├── peripherals/                    # UART, 32-bit Timer, 32-bit GPIO, PRNG, SPI Controller
│   ├── accelerator/                    # AES-128 S-Boxes, Key Expander, Round Datapath, Memory-Mapped Core
│   └── soc_top.v                       # Full SoC Top-Level Module
├── tb/
│   ├── tb_aes_accelerator.v            # AES-128 Accelerator NIST KAT Unit Testbench
│   ├── tb_prng.v                       # PRNG Unit Testbench
│   ├── tb_spi_controller.v             # SPI Controller Unit Testbench
│   ├── tb_uart.v                       # UART Unit Testbench
│   ├── tb_soc_top.v                    # Full-Chip SoC Integration Testbench
│   └── assertions.sv                   # SystemVerilog Assertions (SVA) Protocol Checkers
├── sw/
│   ├── include/                        # soc_regs.h and peripheral driver headers
│   ├── src/                            # C driver implementations & main.c application
│   ├── crt0.s                          # RISC-V startup assembly & vector table
│   ├── linker.ld                       # Memory map linker script
│   ├── app_asm.s                       # Standalone RV32I assembly application
│   └── build_app.py                    # Tool to compile application into rom.hex
└── sim/
    ├── rom.hex                         # Assembled 32-bit machine code
    └── sim_soc.py                      # Cycle-accurate SoC Python simulator & test runner
```

---

## Quickstart & Simulation Verification
To run the automated simulation out of the box:
```powershell
python sim/sim_soc.py
```
This executes the firmware binary on the RV32I core, accesses all memory-mapped peripherals over the bus interconnect, runs hardware AES-128 encryption and decryption against NIST FIPS-197 golden test vectors, streams bytes over SPI, and confirms 100% test pass via GPIO status indicators.
