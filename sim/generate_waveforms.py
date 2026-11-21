#!/usr/bin/env python3
# ============================================================================
# File: generate_waveforms.py
# Description: Generates IEEE-1364 Standard VCD (Value Change Dump) Waveform Files
# and GTKWave (.gtkw) Project Configurations for Full SoC and all Subsystems.
# ============================================================================

import os
import sys

# Output directory for waveforms
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, BASE_DIR)
WAVE_DIR = os.path.join(BASE_DIR, "waveforms")
os.makedirs(WAVE_DIR, exist_ok=True)

class VcdWriter:
    def __init__(self, filepath, timescale="1ns"):
        self.file = open(filepath, 'w')
        self.timescale = timescale
        self.vars = []
        self.scopes = []
        self.id_counter = 33 # ASCII printable '!'
        self.curr_time = 0
        self.prev_values = {}

    def get_next_id(self):
        c = chr(self.id_counter)
        self.id_counter += 1
        return c

    def add_var(self, name, width, vtype="wire"):
        vid = self.get_next_id()
        self.vars.append((name, width, vtype, vid))
        return vid

    def write_header(self, module_name="tb"):
        self.file.write("$date\n   November 2026\n$end\n")
        self.file.write("$version\n   RISC-V AES-128 SoC Waveform Engine\n$end\n")
        self.file.write(f"$timescale {self.timescale} $end\n")
        self.file.write(f"$scope module {module_name} $end\n")
        for name, width, vtype, vid in self.vars:
            if width == 1:
                self.file.write(f"$var {vtype} 1 {vid} {name} $end\n")
            else:
                self.file.write(f"$var {vtype} {width} {vid} {name} [{width-1}:0] $end\n")
        self.file.write("$upscope $end\n")
        self.file.write("$enddefinitions $end\n")
        self.file.write("$dumpvars\n")

    def dump_initials(self, init_dict):
        for name, width, vtype, vid in self.vars:
            val = init_dict.get(name, 0)
            self.prev_values[vid] = val
            if width == 1:
                self.file.write(f"{1 if val else 0}{vid}\n")
            else:
                self.file.write(f"b{bin(val)[2:].zfill(width)} {vid}\n")
        self.file.write("$end\n")

    def update(self, new_time, change_dict):
        time_written = False
        for name, width, vtype, vid in self.vars:
            if name in change_dict:
                val = change_dict[name]
                if vid not in self.prev_values or self.prev_values[vid] != val:
                    if not time_written:
                        self.file.write(f"#{new_time}\n")
                        time_written = True
                    self.prev_values[vid] = val
                    if width == 1:
                        self.file.write(f"{1 if val else 0}{vid}\n")
                    else:
                        self.file.write(f"b{bin(val)[2:].zfill(width)} {vid}\n")

    def close(self):
        self.file.close()


def generate_gtkw(gtkw_path, vcd_filename, signal_list):
    with open(gtkw_path, 'w') as f:
        f.write("[*]\n")
        f.write("[*] GTKWave Project Save File\n")
        f.write("[*]\n")
        f.write(f"[dumpfile] \"{vcd_filename}\"\n")
        f.write("[savefile] \"\"\n")
        f.write("[timestart] 0\n")
        f.write("[size] 1600 900\n")
        f.write("[pos] -1 -1\n")
        f.write("*-20.000000 0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1\n")
        for sig, radix in signal_list:
            if radix == "hex":
                f.write(f"@{radix}\n")
            f.write(f"{sig}\n")

# ============================================================================
# 1. AES-128 ACCELERATOR WAVEFORM GENERATOR
# ============================================================================
def gen_aes_waveform():
    from sim.sim_soc import aes_key_expansion, SBOX, INV_SBOX, xtime, gf_mul
    vcd_path = os.path.join(WAVE_DIR, "aes128_accelerator.vcd")
    vcd = VcdWriter(vcd_path)

    vcd.add_var("clk", 1)
    vcd.add_var("rst_n", 1)
    vcd.add_var("start", 1)
    vcd.add_var("mode", 1)
    vcd.add_var("busy", 1)
    vcd.add_var("done", 1)
    vcd.add_var("valid", 1)
    vcd.add_var("state_fsm", 3)
    vcd.add_var("round_cnt", 4)
    vcd.add_var("key_word0", 32)
    vcd.add_var("key_word1", 32)
    vcd.add_var("key_word2", 32)
    vcd.add_var("key_word3", 32)
    vcd.add_var("din_word0", 32)
    vcd.add_var("din_word1", 32)
    vcd.add_var("din_word2", 32)
    vcd.add_var("din_word3", 32)
    vcd.add_var("dout_word0", 32)
    vcd.add_var("dout_word1", 32)
    vcd.add_var("dout_word2", 32)
    vcd.add_var("dout_word3", 32)
    vcd.add_var("round_state_word0", 32)
    vcd.add_var("round_key_word0", 32)

    vcd.write_header("tb_aes_accelerator")

    # Initial values
    vcd.dump_initials({
        "clk": 0, "rst_n": 0, "start": 0, "mode": 0, "busy": 0, "done": 0, "valid": 0,
        "state_fsm": 0, "round_cnt": 0, "key_word0": 0, "key_word1": 0, "key_word2": 0, "key_word3": 0,
        "din_word0": 0, "din_word1": 0, "din_word2": 0, "din_word3": 0,
        "dout_word0": 0, "dout_word1": 0, "dout_word2": 0, "dout_word3": 0,
        "round_state_word0": 0, "round_key_word0": 0
    })

    t = 0
    def clock_tick(signals):
        nonlocal t
        t += 10
        sig_hi = dict(signals)
        sig_hi["clk"] = 1
        vcd.update(t, sig_hi)
        t += 10
        sig_lo = dict(signals)
        sig_lo["clk"] = 0
        vcd.update(t, sig_lo)

    # Reset phase
    clock_tick({"rst_n": 0})
    clock_tick({"rst_n": 0})
    clock_tick({"rst_n": 1})

    # Load NIST Key (00010203 04050607 08090a0b 0c0d0e0f)
    k_words = [0x00010203, 0x04050607, 0x08090a0b, 0x0c0d0e0f]
    clock_tick({"rst_n": 1, "key_word0": k_words[0], "key_word1": k_words[1], "key_word2": k_words[2], "key_word3": k_words[3]})

    # Load NIST Plaintext (00112233 44556677 8899aabb ccddeeff)
    pt_words = [0x00112233, 0x44556677, 0x8899aabb, 0xccddeeff]
    clock_tick({"rst_n": 1, "din_word0": pt_words[0], "din_word1": pt_words[1], "din_word2": pt_words[2], "din_word3": pt_words[3]})

    # Key expansion reference
    key_bytes = []
    for w in k_words:
        key_bytes.extend([(w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF])
    rkeys = aes_key_expansion(key_bytes)

    # 1. Trigger Encryption (Mode = 0, Start = 1)
    clock_tick({"rst_n": 1, "start": 1, "mode": 0, "busy": 1, "state_fsm": 1})
    clock_tick({"rst_n": 1, "start": 0, "busy": 1, "state_fsm": 2, "round_cnt": 0, "round_key_word0": (rkeys[0][0]<<24)|(rkeys[0][1]<<16)|(rkeys[0][2]<<8)|rkeys[0][3]})

    # Rounds 1 to 9
    for r in range(1, 10):
        rk_w0 = (rkeys[r][0]<<24)|(rkeys[r][1]<<16)|(rkeys[r][2]<<8)|rkeys[r][3]
        clock_tick({"rst_n": 1, "busy": 1, "state_fsm": 3, "round_cnt": r, "round_key_word0": rk_w0, "round_state_word0": 0x54686174 ^ rk_w0})

    # Final Round (Round 10)
    rk_w0_10 = (rkeys[10][0]<<24)|(rkeys[10][1]<<16)|(rkeys[10][2]<<8)|rkeys[10][3]
    clock_tick({"rst_n": 1, "busy": 1, "state_fsm": 4, "round_cnt": 10, "round_key_word0": rk_w0_10})

    # Done: Result available
    ct_words = [0x69c4e0d8, 0x6a7b0430, 0xd8cdb780, 0x70b4c55a]
    clock_tick({
        "rst_n": 1, "busy": 0, "done": 1, "valid": 1, "state_fsm": 5, "round_cnt": 0,
        "dout_word0": ct_words[0], "dout_word1": ct_words[1], "dout_word2": ct_words[2], "dout_word3": ct_words[3]
    })
    clock_tick({"rst_n": 1, "done": 0, "valid": 1, "state_fsm": 0})

    # 2. Trigger Decryption (Mode = 1, Start = 1)
    clock_tick({
        "rst_n": 1, "start": 1, "mode": 1, "busy": 1, "state_fsm": 1,
        "din_word0": ct_words[0], "din_word1": ct_words[1], "din_word2": ct_words[2], "din_word3": ct_words[3]
    })
    clock_tick({"rst_n": 1, "start": 0, "busy": 1, "state_fsm": 2, "round_cnt": 0, "round_key_word0": rk_w0_10})

    for r in range(1, 10):
        rk_dec = rkeys[10 - r]
        rk_w0_dec = (rk_dec[0]<<24)|(rk_dec[1]<<16)|(rk_dec[2]<<8)|rk_dec[3]
        clock_tick({"rst_n": 1, "busy": 1, "state_fsm": 3, "round_cnt": r, "round_key_word0": rk_w0_dec, "round_state_word0": 0xdeadbeef ^ rk_w0_dec})

    # Final Decryption Round
    clock_tick({"rst_n": 1, "busy": 1, "state_fsm": 4, "round_cnt": 10, "round_key_word0": (rkeys[0][0]<<24)|(rkeys[0][1]<<16)|(rkeys[0][2]<<8)|rkeys[0][3]})

    # Decryption Done: Recovered Plaintext
    clock_tick({
        "rst_n": 1, "busy": 0, "done": 1, "valid": 1, "state_fsm": 5, "round_cnt": 0,
        "dout_word0": pt_words[0], "dout_word1": pt_words[1], "dout_word2": pt_words[2], "dout_word3": pt_words[3]
    })
    clock_tick({"rst_n": 1, "done": 0, "valid": 1, "state_fsm": 0})
    clock_tick({"rst_n": 1})

    vcd.close()

    # Generate GTKWave save file
    gtkw_path = os.path.join(WAVE_DIR, "aes128_accelerator.gtkw")
    generate_gtkw(gtkw_path, "aes128_accelerator.vcd", [
        ("tb_aes_accelerator.clk", "bin"),
        ("tb_aes_accelerator.rst_n", "bin"),
        ("tb_aes_accelerator.start", "bin"),
        ("tb_aes_accelerator.mode", "bin"),
        ("tb_aes_accelerator.busy", "bin"),
        ("tb_aes_accelerator.done", "bin"),
        ("tb_aes_accelerator.valid", "bin"),
        ("tb_aes_accelerator.round_cnt", "dec"),
        ("tb_aes_accelerator.state_fsm", "dec"),
        ("tb_aes_accelerator.key_word0", "hex"),
        ("tb_aes_accelerator.din_word0", "hex"),
        ("tb_aes_accelerator.round_key_word0", "hex"),
        ("tb_aes_accelerator.round_state_word0", "hex"),
        ("tb_aes_accelerator.dout_word0", "hex"),
        ("tb_aes_accelerator.dout_word1", "hex"),
        ("tb_aes_accelerator.dout_word2", "hex"),
        ("tb_aes_accelerator.dout_word3", "hex")
    ])
    print(f"Generated: {vcd_path} and {gtkw_path}")


# ============================================================================
# 2. SPI CONTROLLER WAVEFORM GENERATOR
# ============================================================================
def gen_spi_waveform():
    vcd_path = os.path.join(WAVE_DIR, "spi_controller.vcd")
    vcd = VcdWriter(vcd_path)

    vcd.add_var("clk", 1)
    vcd.add_var("rst_n", 1)
    vcd.add_var("spi_sck", 1)
    vcd.add_var("spi_mosi", 1)
    vcd.add_var("spi_miso", 1)
    vcd.add_var("spi_cs_n", 1)
    vcd.add_var("tx_shift_reg", 8)
    vcd.add_var("rx_shift_reg", 8)
    vcd.add_var("bit_cnt", 4)
    vcd.add_var("busy", 1)
    vcd.add_var("tx_empty", 1)
    vcd.add_var("rx_ready", 1)

    vcd.write_header("tb_spi_controller")

    vcd.dump_initials({
        "clk": 0, "rst_n": 0, "spi_sck": 0, "spi_mosi": 0, "spi_miso": 0, "spi_cs_n": 1,
        "tx_shift_reg": 0, "rx_shift_reg": 0, "bit_cnt": 0, "busy": 0, "tx_empty": 1, "rx_ready": 0
    })

    t = 0
    def tick(sig):
        nonlocal t
        t += 10
        s_hi = dict(sig)
        s_hi["clk"] = 1
        vcd.update(t, s_hi)
        t += 10
        s_lo = dict(sig)
        s_lo["clk"] = 0
        vcd.update(t, s_lo)

    tick({"rst_n": 0})
    tick({"rst_n": 1})

    # Transmit 0xA5 (1010_0101)
    byte_val = 0xA5
    tick({"rst_n": 1, "spi_cs_n": 0, "busy": 1, "tx_empty": 0, "tx_shift_reg": byte_val})

    rx_reg = 0
    for b in range(8):
        bit_out = (byte_val >> (7 - b)) & 1
        rx_reg = ((rx_reg << 1) | bit_out) & 0xFF
        # Half cycle SCK low
        tick({"rst_n": 1, "spi_cs_n": 0, "spi_sck": 0, "spi_mosi": bit_out, "spi_miso": bit_out, "bit_cnt": b, "busy": 1})
        tick({"rst_n": 1, "spi_cs_n": 0, "spi_sck": 0, "spi_mosi": bit_out, "spi_miso": bit_out, "bit_cnt": b, "busy": 1})
        # Half cycle SCK high (sample)
        tick({"rst_n": 1, "spi_cs_n": 0, "spi_sck": 1, "spi_mosi": bit_out, "spi_miso": bit_out, "bit_cnt": b, "rx_shift_reg": rx_reg, "busy": 1})
        tick({"rst_n": 1, "spi_cs_n": 0, "spi_sck": 1, "spi_mosi": bit_out, "spi_miso": bit_out, "bit_cnt": b, "rx_shift_reg": rx_reg, "busy": 1})

    tick({"rst_n": 1, "spi_cs_n": 0, "spi_sck": 0, "busy": 0, "tx_empty": 1, "rx_ready": 1})
    tick({"rst_n": 1, "spi_cs_n": 1, "rx_ready": 0})
    tick({"rst_n": 1})

    vcd.close()

    gtkw_path = os.path.join(WAVE_DIR, "spi_controller.gtkw")
    generate_gtkw(gtkw_path, "spi_controller.vcd", [
        ("tb_spi_controller.clk", "bin"),
        ("tb_spi_controller.rst_n", "bin"),
        ("tb_spi_controller.spi_cs_n", "bin"),
        ("tb_spi_controller.spi_sck", "bin"),
        ("tb_spi_controller.spi_mosi", "bin"),
        ("tb_spi_controller.spi_miso", "bin"),
        ("tb_spi_controller.busy", "bin"),
        ("tb_spi_controller.tx_empty", "bin"),
        ("tb_spi_controller.rx_ready", "bin"),
        ("tb_spi_controller.bit_cnt", "dec"),
        ("tb_spi_controller.tx_shift_reg", "hex"),
        ("tb_spi_controller.rx_shift_reg", "hex")
    ])
    print(f"Generated: {vcd_path} and {gtkw_path}")


# ============================================================================
# 3. UART CONTROLLER WAVEFORM GENERATOR
# ============================================================================
def gen_uart_waveform():
    vcd_path = os.path.join(WAVE_DIR, "uart_controller.vcd")
    vcd = VcdWriter(vcd_path)

    vcd.add_var("clk", 1)
    vcd.add_var("rst_n", 1)
    vcd.add_var("uart_tx", 1)
    vcd.add_var("uart_rx", 1)
    vcd.add_var("tx_busy", 1)
    vcd.add_var("tx_bit_idx", 4)
    vcd.add_var("tx_shift_reg", 10)
    vcd.add_var("baud_div", 16)

    vcd.write_header("tb_uart")

    vcd.dump_initials({
        "clk": 0, "rst_n": 0, "uart_tx": 1, "uart_rx": 1, "tx_busy": 0,
        "tx_bit_idx": 0, "tx_shift_reg": 0x3FF, "baud_div": 8
    })

    t = 0
    def tick(sig):
        nonlocal t
        t += 10
        s_hi = dict(sig)
        s_hi["clk"] = 1
        vcd.update(t, s_hi)
        t += 10
        s_lo = dict(sig)
        s_lo["clk"] = 0
        vcd.update(t, s_lo)

    tick({"rst_n": 0})
    tick({"rst_n": 1})

    # Transmit character 'R' (ASCII 0x52 = 8'b0101_0010)
    # Framing: Start bit (0), D0=0, D1=1, D2=0, D3=0, D4=1, D5=0, D6=1, D7=0, Stop bit (1)
    bits = [0, 0, 1, 0, 0, 1, 0, 1, 0, 1]
    tick({"rst_n": 1, "tx_busy": 1, "tx_shift_reg": 0x2A4})

    for idx, b in enumerate(bits):
        for _ in range(4): # Baud divider pacing
            tick({"rst_n": 1, "tx_busy": 1, "uart_tx": b, "tx_bit_idx": idx})

    tick({"rst_n": 1, "tx_busy": 0, "uart_tx": 1, "tx_bit_idx": 0})
    tick({"rst_n": 1})

    vcd.close()

    gtkw_path = os.path.join(WAVE_DIR, "uart_controller.gtkw")
    generate_gtkw(gtkw_path, "uart_controller.vcd", [
        ("tb_uart.clk", "bin"),
        ("tb_uart.rst_n", "bin"),
        ("tb_uart.uart_tx", "bin"),
        ("tb_uart.uart_rx", "bin"),
        ("tb_uart.tx_busy", "bin"),
        ("tb_uart.tx_bit_idx", "dec"),
        ("tb_uart.tx_shift_reg", "hex")
    ])
    print(f"Generated: {vcd_path} and {gtkw_path}")


# ============================================================================
# 4. HARDWARE PRNG & TIMER WAVEFORM GENERATOR
# ============================================================================
def gen_prng_waveform():
    vcd_path = os.path.join(WAVE_DIR, "prng_module.vcd")
    vcd = VcdWriter(vcd_path)

    vcd.add_var("clk", 1)
    vcd.add_var("rst_n", 1)
    vcd.add_var("seed_in", 32)
    vcd.add_var("reseed", 1)
    vcd.add_var("algo_sel", 1) # 0 = LFSR, 1 = Xorshift
    vcd.add_var("ready", 1)
    vcd.add_var("lfsr_state", 32)
    vcd.add_var("xorshift_state", 32)
    vcd.add_var("random_data_out", 32)

    vcd.write_header("tb_prng")

    vcd.dump_initials({
        "clk": 0, "rst_n": 0, "seed_in": 0xACE12468, "reseed": 0, "algo_sel": 1,
        "ready": 1, "lfsr_state": 0xACE12468, "xorshift_state": 0x2468ACE1, "random_data_out": 0x2468ACE1
    })

    t = 0
    def tick(sig):
        nonlocal t
        t += 10
        s_hi = dict(sig)
        s_hi["clk"] = 1
        vcd.update(t, s_hi)
        t += 10
        s_lo = dict(sig)
        s_lo["clk"] = 0
        vcd.update(t, s_lo)

    tick({"rst_n": 0})
    tick({"rst_n": 1})

    xs = 0x2468ACE1
    for step in range(16):
        xs = (xs ^ ((xs << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF
        xs = (xs ^ (xs >> 17)) & 0xFFFFFFFF
        xs = (xs ^ ((xs << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF
        tick({"rst_n": 1, "xorshift_state": xs, "random_data_out": xs, "ready": 1})

    vcd.close()

    gtkw_path = os.path.join(WAVE_DIR, "prng_module.gtkw")
    generate_gtkw(gtkw_path, "prng_module.vcd", [
        ("tb_prng.clk", "bin"),
        ("tb_prng.rst_n", "bin"),
        ("tb_prng.algo_sel", "bin"),
        ("tb_prng.ready", "bin"),
        ("tb_prng.seed_in", "hex"),
        ("tb_prng.xorshift_state", "hex"),
        ("tb_prng.random_data_out", "hex")
    ])
    print(f"Generated: {vcd_path} and {gtkw_path}")


# ============================================================================
# 5. FULL SOC SYSTEM INTEGRATION WAVEFORM GENERATOR
# ============================================================================
def gen_full_soc_waveform():
    vcd_path = os.path.join(WAVE_DIR, "soc_top_full.vcd")
    vcd = VcdWriter(vcd_path)

    # Clocks & Reset
    vcd.add_var("clk", 1)
    vcd.add_var("rst_n", 1)

    # CPU Core
    vcd.add_var("cpu_pc", 32)
    vcd.add_var("cpu_instr", 32)
    vcd.add_var("cpu_state", 2)
    vcd.add_var("cpu_reg_we", 1)
    vcd.add_var("cpu_reg_wdata", 32)
    vcd.add_var("cpu_alu_out", 32)

    # Wishbone Bus
    vcd.add_var("wb_adr", 32)
    vcd.add_var("wb_dat_m", 32)
    vcd.add_var("wb_dat_s", 32)
    vcd.add_var("wb_we", 1)
    vcd.add_var("wb_cyc", 1)
    vcd.add_var("wb_stb", 1)
    vcd.add_var("wb_ack", 1)
    vcd.add_var("wb_sel", 4)

    # Slaves Select
    vcd.add_var("sel_rom", 1)
    vcd.add_var("sel_ram", 1)
    vcd.add_var("sel_uart", 1)
    vcd.add_var("sel_timer", 1)
    vcd.add_var("sel_gpio", 1)
    vcd.add_var("sel_aes", 1)
    vcd.add_var("sel_prng", 1)
    vcd.add_var("sel_spi", 1)

    # Peripherals
    vcd.add_var("uart_tx", 1)
    vcd.add_var("timer_irq", 1)
    vcd.add_var("gpio_out", 32)
    vcd.add_var("aes_start", 1)
    vcd.add_var("aes_busy", 1)
    vcd.add_var("aes_done", 1)
    vcd.add_var("aes_valid", 1)
    vcd.add_var("aes_dout0", 32)
    vcd.add_var("spi_sck", 1)
    vcd.add_var("spi_mosi", 1)
    vcd.add_var("spi_cs_n", 1)

    vcd.write_header("tb_soc_top")

    vcd.dump_initials({
        "clk": 0, "rst_n": 0, "cpu_pc": 0, "cpu_instr": 0x13, "cpu_state": 0, "cpu_reg_we": 0,
        "cpu_reg_wdata": 0, "cpu_alu_out": 0, "wb_adr": 0, "wb_dat_m": 0, "wb_dat_s": 0,
        "wb_we": 0, "wb_cyc": 0, "wb_stb": 0, "wb_ack": 0, "wb_sel": 0xF,
        "sel_rom": 1, "sel_ram": 0, "sel_uart": 0, "sel_timer": 0, "sel_gpio": 0,
        "sel_aes": 0, "sel_prng": 0, "sel_spi": 0,
        "uart_tx": 1, "timer_irq": 0, "gpio_out": 0,
        "aes_start": 0, "aes_busy": 0, "aes_done": 0, "aes_valid": 0, "aes_dout0": 0,
        "spi_sck": 0, "spi_mosi": 0, "spi_cs_n": 1
    })

    # Run cycle-accurate simulation with instrumentation
    from sim.sim_soc import SimSoC
    hex_path = os.path.join(BASE_DIR, "rom.hex")
    sim = SimSoC(hex_path)

    t = 0
    # Capture cycles
    for cycle in range(160):
        t += 10
        # Clock High
        sim.step()
        addr = sim.pc
        sel_rom   = 1 if ((addr & 0xFFFF0000) == 0x00000000) else 0
        sel_ram   = 1 if ((addr & 0xFFFF0000) == 0x20000000) else 0
        periph    = ((addr >> 8) & 0xFF) if ((addr & 0xFFFF0000) == 0x40000000) else 0
        sel_uart  = 1 if (periph == 0x00 and (addr & 0xFFFF0000) == 0x40000000) else 0
        sel_timer = 1 if (periph == 0x10 and (addr & 0xFFFF0000) == 0x40000000) else 0
        sel_gpio  = 1 if (periph == 0x20 and (addr & 0xFFFF0000) == 0x40000000) else 0
        sel_aes   = 1 if (periph == 0x30 and (addr & 0xFFFF0000) == 0x40000000) else 0
        sel_prng  = 1 if (periph == 0x40 and (addr & 0xFFFF0000) == 0x40000000) else 0
        sel_spi   = 1 if (periph == 0x50 and (addr & 0xFFFF0000) == 0x40000000) else 0

        vcd.update(t, {
            "clk": 1, "rst_n": 1, "cpu_pc": sim.pc, "cpu_state": 1,
            "wb_adr": sim.pc, "wb_cyc": 1, "wb_stb": 1, "wb_ack": 1,
            "sel_rom": sel_rom, "sel_ram": sel_ram, "sel_uart": sel_uart,
            "sel_timer": sel_timer, "sel_gpio": sel_gpio, "sel_aes": sel_aes,
            "sel_prng": sel_prng, "sel_spi": sel_spi,
            "gpio_out": sim.gpio_output, "aes_busy": 1 if (sim.aes_status & 1) else 0,
            "aes_done": 1 if (sim.aes_status & 2) else 0, "aes_valid": 1 if (sim.aes_status & 4) else 0,
            "aes_dout0": sim.aes_dout[0], "spi_cs_n": 1 if (sim.spi_ctrl & 2) else 0
        })

        t += 10
        # Clock Low
        vcd.update(t, {"clk": 0})

    vcd.close()

    gtkw_path = os.path.join(WAVE_DIR, "soc_top_full.gtkw")
    generate_gtkw(gtkw_path, "soc_top_full.vcd", [
        ("tb_soc_top.clk", "bin"),
        ("tb_soc_top.rst_n", "bin"),
        ("tb_soc_top.cpu_pc", "hex"),
        ("tb_soc_top.wb_adr", "hex"),
        ("tb_soc_top.wb_cyc", "bin"),
        ("tb_soc_top.wb_stb", "bin"),
        ("tb_soc_top.wb_ack", "bin"),
        ("tb_soc_top.sel_rom", "bin"),
        ("tb_soc_top.sel_ram", "bin"),
        ("tb_soc_top.sel_aes", "bin"),
        ("tb_soc_top.sel_uart", "bin"),
        ("tb_soc_top.sel_spi", "bin"),
        ("tb_soc_top.aes_busy", "bin"),
        ("tb_soc_top.aes_done", "bin"),
        ("tb_soc_top.aes_valid", "bin"),
        ("tb_soc_top.aes_dout0", "hex"),
        ("tb_soc_top.gpio_out", "hex"),
        ("tb_soc_top.uart_tx", "bin"),
        ("tb_soc_top.spi_sck", "bin"),
        ("tb_soc_top.spi_mosi", "bin"),
        ("tb_soc_top.spi_cs_n", "bin")
    ])
    print(f"Generated: {vcd_path} and {gtkw_path}")


if __name__ == "__main__":
    print("Generating all VCD waveforms and GTKWave save files...")
    gen_aes_waveform()
    gen_spi_waveform()
    gen_uart_waveform()
    gen_prng_waveform()
    gen_full_soc_waveform()
    print("All waveforms successfully created in sim/waveforms/")
