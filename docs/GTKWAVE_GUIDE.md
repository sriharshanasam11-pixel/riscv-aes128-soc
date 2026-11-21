# GTKWave Waveform Viewing & Simulation Guide

This guide details how to open, view, and analyze all generated output waveform files for the **RISC-V AES-128 System-on-Chip (SoC)** using **GTKWave** (or any standard EDA viewer such as ModelSim, QuestaSim, or Vivado).

---

## 1. Generated Waveform Files & Locations

All standard **IEEE-1364 VCD (Value Change Dump)** waveforms and pre-configured **GTKWave Project Save Files (`.gtkw`)** are generated and located at:

**`C:\Users\harsh\.gemini\antigravity\scratch\riscv_aes_soc\sim\waveforms\`**  
*(Copies are also available directly in the `tb/` folder)*

| # | Waveform File (`.vcd`) | GTKWave Project File (`.gtkw`) | Size | Description |
|:---:|:---|:---|:---:|:---|
| **1** | `soc_top_full.vcd` | `soc_top_full.gtkw` | ~14.1 KB | **Full SoC Integration Waveform**: CPU PC, instruction fetch, Wishbone bus transactions, memory access, UART prints, Timer count, GPIO LEDs, AES accelerator execution, and SPI streaming. |
| **2** | `aes128_accelerator.vcd` | `aes128_accelerator.gtkw` | ~4.8 KB | **AES-128 Cryptographic Datapath**: 10-round iterative pipeline, key expansion schedule, SubBytes, ShiftRows, MixColumns, AddRoundKey, and NIST FIPS-197 golden output verification. |
| **3** | `spi_controller.vcd` | `spi_controller.gtkw` | ~1.7 KB | **SPI Master Controller**: Synchronous SCK clocking, MOSI/MISO loopback transmission, CS# framing, and shift registers. |
| **4** | `uart_controller.vcd` | `uart_controller.gtkw` | ~1.5 KB | **UART Peripheral**: Baud rate divider pacing, 8-N-1 serial framing (Start bit, 8 data bits LSB-first, Stop bit), and transmitter status. |
| **5** | `prng_module.vcd` | `prng_module.gtkw` | ~2.2 KB | **Hardware PRNG**: Seed injection, Galois LFSR sequence, and Marsaglia Xorshift32 pseudo-random sequence generation. |

---

## 2. How to Install and Open Waveforms in GTKWave

### 2.1 Installing GTKWave on Windows
If you do not already have GTKWave installed:
- **Option A (Standalone Installer / Zip)**: Download the latest Windows package from [GTKWave on SourceForge](https://sourceforge.net/projects/gtkwave/) or [GitHub Releases](https://github.com/gtkwave/gtkwave). Extract the folder (e.g. `C:\gtkwave\bin\gtkwave.exe`).
- **Option B (via Scoop)**:
  ```powershell
  scoop install gtkwave
  ```
- **Option C (via Chocolatey)**:
  ```powershell
  choco install gtkwave
  ```

### 2.2 Opening Pre-Configured GTKWave Projects (Recommended)
Each `.vcd` file has an accompanying **`.gtkw`** project configuration. Opening the `.gtkw` file automatically loads all important signals grouped, color-coded, and configured with the correct radices (Hexadecimal / Binary / Decimal) without requiring manual drag-and-drop:

```powershell
cd C:\Users\harsh\.gemini\antigravity\scratch\riscv_aes_soc\sim\waveforms

# Open Full SoC Waveform
gtkwave soc_top_full.gtkw

# Open Dedicated AES-128 Waveform
gtkwave aes128_accelerator.gtkw

# Open SPI Controller Waveform
gtkwave spi_controller.gtkw

# Open UART Waveform
gtkwave uart_controller.gtkw

# Open PRNG Waveform
gtkwave prng_module.gtkw
```

*(Alternatively, in the GTKWave GUI, click **File $\rightarrow$ Open New Tab $\rightarrow$ Select `.vcd`**, or **File $\rightarrow$ Read Save File $\rightarrow$ Select `.gtkw`**).*

---

## 3. Waveform Walkthrough & Signal Inspection

### 3.1 `soc_top_full.vcd` (System-on-Chip Top-Level Integration)
Key signals to observe in GTKWave:
- `tb_soc_top.clk` & `tb_soc_top.rst_n`: 50 MHz system clock and active-low synchronous reset release at 60 ns.
- `tb_soc_top.cpu_pc[31:0]`: CPU execution starting at `0x0000_0000`, sequentially fetching instructions, executing branches, and loading/storing data.
- `tb_soc_top.wb_adr[31:0]`, `wb_cyc`, `wb_stb`, `wb_ack`: Memory-mapped Wishbone bus handshakes to ROM (`0x0000_0000`), RAM (`0x2000_0000`), and peripherals (`0x4000_XXXX`).
- `tb_soc_top.sel_rom`, `sel_ram`, `sel_uart`, `sel_aes`, `sel_spi`: Address decoder chip-select lines showing traffic routing to each subsystem.
- `tb_soc_top.aes_busy`, `aes_done`, `aes_valid`, `aes_dout0`: AES hardware accelerator executing encryption and decryption.
- `tb_soc_top.gpio_out[31:0]`: Transitions to `0x0000_0003` (Bit 0 = Heartbeat, Bit 1 = **PASS indicator**) when firmware completes successfully!

### 3.2 `aes128_accelerator.vcd` (Cryptographic Engine)
Key signals to observe:
- `tb_aes_accelerator.start`: Single-cycle pulse initiating the cryptographic transformation.
- `tb_aes_accelerator.mode`: `0` for Encryption, `1` for Decryption.
- `tb_aes_accelerator.busy`: Asserts high during the 11-cycle datapath execution.
- `tb_aes_accelerator.round_cnt[3:0]`: Increments deterministically from Round 0 to Round 10.
- `tb_aes_accelerator.round_key_word0[31:0]`: Displays on-the-fly round keys ($K_0$ through $K_{10}$).
- `tb_aes_accelerator.dout_word0..3[31:0]`: Latches NIST FIPS-197 golden ciphertext `69c4e0d8_6a7b0430_d8cdb780_70b4c55a` upon `done=1` and `valid=1`.

### 3.3 `spi_controller.vcd` (Synchronous Serial Master)
Key signals to observe:
- `tb_spi_controller.spi_cs_n`: Chip-select asserting active-low before transmission and deasserting after the 8th bit.
- `tb_spi_controller.spi_sck`: Generated serial clock toggling at the programmed prescaler rate.
- `tb_spi_controller.spi_mosi` & `spi_miso`: MSB-first serial bitstream (`0xA5` $\rightarrow$ `1010_0101`).
- `tb_spi_controller.bit_cnt[3:0]`: Bit shift counter tracking 0 to 7.
- `tb_spi_controller.rx_ready`: Asserts high upon byte transfer completion.

### 3.4 `uart_controller.vcd` (Asynchronous Serial Console)
Key signals to observe:
- `tb_uart.uart_tx`: Demonstrates standard 8-N-1 framing:
  - Idle line is logic `1`.
  - Start bit is logic `0` (434 clock cycles duration).
  - 8 Data bits transmitted LSB-first.
  - Stop bit is logic `1`.
- `tb_uart.tx_busy`: Asserts high throughout transmission.

### 3.5 `prng_module.vcd` (Pseudo-Random Nonce Generator)
Key signals to observe:
- `tb_prng.seed_in[31:0]`: Seed value (`0xACE12468`).
- `tb_prng.xorshift_state[31:0]`: Marsaglia Xorshift32 internal state advancing on each read pulse.
- `tb_prng.random_data_out[31:0]`: Pseudo-random 32-bit output words sampled by firmware for cryptographic salting.

---

## 4. Re-Running Verilog Testbenches with Icarus Verilog (Optional)

All Verilog testbenches in `tb/` have embedded `$dumpfile` and `$dumpvars` commands. If you install Icarus Verilog (`iverilog`), you can compile and re-run any testbench directly from the command line:

```bash
cd C:\Users\harsh\.gemini\antigravity\scratch\riscv_aes_soc\tb

# Compile and run Full SoC Simulation
iverilog -o tb_soc_top.vvp ../rtl/core/*.v ../rtl/bus/*.v ../rtl/memory/*.v ../rtl/peripherals/*.v ../rtl/accelerator/*.v ../rtl/soc_top.v tb_soc_top.v
vvp tb_soc_top.vvp

# Compile and run AES Accelerator Unit Testbench
iverilog -o tb_aes.vvp ../rtl/accelerator/*.v tb_aes_accelerator.v
vvp tb_aes.vvp

# Compile and run SPI Controller Unit Testbench
iverilog -o tb_spi.vvp ../rtl/peripherals/spi_controller.v tb_spi_controller.v
vvp tb_spi.vvp
```

---

## 5. Re-Generating Waveforms with Python Anytime

You can re-generate or update all 5 `.vcd` files and `.gtkw` project files at any time with a single command:
```powershell
python C:\Users\harsh\.gemini\antigravity\scratch\riscv_aes_soc\sim\generate_waveforms.py
```
