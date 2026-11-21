#!/usr/bin/env python3
# ============================================================================
# File: sim_soc.py
# Description: Cycle-Accurate SoC Simulator & Golden Reference Verification Engine
# Executes RISC-V machine instructions, emulates Wishbone bus transactions,
# exercises AES-128, PRNG, SPI, UART, Timer, GPIO, and verifies NIST test vectors.
# ============================================================================

import sys
import os

# NIST FIPS-197 AES Reference Constants
SBOX = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
]
INV_SBOX = [0] * 256
for idx, val in enumerate(SBOX):
    INV_SBOX[val] = idx

RCON = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]

def xtime(a):
    return (((a << 1) ^ 0x1B) & 0xFF) if (a & 0x80) else (a << 1)

def gf_mul(a, b):
    p = 0
    for _ in range(8):
        if b & 1: p ^= a
        a = xtime(a)
        b >>= 1
    return p

def aes_key_expansion(key_bytes):
    w = []
    for i in range(4):
        w.append([key_bytes[4*i], key_bytes[4*i+1], key_bytes[4*i+2], key_bytes[4*i+3]])
    for i in range(4, 44):
        temp = list(w[i-1])
        if i % 4 == 0:
            temp = [temp[1], temp[2], temp[3], temp[0]]
            temp = [SBOX[b] for b in temp]
            temp[0] ^= RCON[i // 4]
        word = [w[i-4][j] ^ temp[j] for j in range(4)]
        w.append(word)
    rkeys = []
    for r in range(11):
        rk = []
        for c in range(4):
            rk.extend(w[r*4 + c])
        rkeys.append(rk)
    return rkeys

def aes_encrypt(pt_bytes, rkeys):
    s = [pt_bytes[i] ^ rkeys[0][i] for i in range(16)]
    for r in range(1, 10):
        # SubBytes
        s = [SBOX[b] for b in s]
        # ShiftRows
        s = [
            s[0],  s[5],  s[10], s[15],
            s[4],  s[9],  s[14], s[3],
            s[8],  s[13], s[2],  s[7],
            s[12], s[1],  s[6],  s[11]
        ]
        # MixColumns
        new_s = []
        for c in range(4):
            col = s[c*4 : c*4+4]
            new_s.extend([
                gf_mul(2, col[0]) ^ gf_mul(3, col[1]) ^ col[2] ^ col[3],
                col[0] ^ gf_mul(2, col[1]) ^ gf_mul(3, col[2]) ^ col[3],
                col[0] ^ col[1] ^ gf_mul(2, col[2]) ^ gf_mul(3, col[3]),
                gf_mul(3, col[0]) ^ col[1] ^ col[2] ^ gf_mul(2, col[3])
            ])
        s = new_s
        # AddRoundKey
        s = [s[i] ^ rkeys[r][i] for i in range(16)]

    # Final Round (Round 10)
    s = [SBOX[b] for b in s]
    s = [
        s[0],  s[5],  s[10], s[15],
        s[4],  s[9],  s[14], s[3],
        s[8],  s[13], s[2],  s[7],
        s[12], s[1],  s[6],  s[11]
    ]
    s = [s[i] ^ rkeys[10][i] for i in range(16)]
    return s

def aes_decrypt(ct_bytes, rkeys):
    s = [ct_bytes[i] ^ rkeys[10][i] for i in range(16)]
    for r in range(9, 0, -1):
        # InvShiftRows
        s = [
            s[0],  s[13], s[10], s[7],
            s[4],  s[1],  s[14], s[11],
            s[8],  s[5],  s[2],  s[15],
            s[12], s[9],  s[6],  s[3]
        ]
        # InvSubBytes
        s = [INV_SBOX[b] for b in s]
        # AddRoundKey
        s = [s[i] ^ rkeys[r][i] for i in range(16)]
        # InvMixColumns
        new_s = []
        for c in range(4):
            col = s[c*4 : c*4+4]
            new_s.extend([
                gf_mul(0x0e, col[0]) ^ gf_mul(0x0b, col[1]) ^ gf_mul(0x0d, col[2]) ^ gf_mul(0x09, col[3]),
                gf_mul(0x09, col[0]) ^ gf_mul(0x0e, col[1]) ^ gf_mul(0x0b, col[2]) ^ gf_mul(0x0d, col[3]),
                gf_mul(0x0d, col[0]) ^ gf_mul(0x09, col[1]) ^ gf_mul(0x0e, col[2]) ^ gf_mul(0x0b, col[3]),
                gf_mul(0x0b, col[0]) ^ gf_mul(0x0d, col[1]) ^ gf_mul(0x09, col[2]) ^ gf_mul(0x0e, col[3])
            ])
        s = new_s

    # Final Round (Round 0)
    s = [
        s[0],  s[13], s[10], s[7],
        s[4],  s[1],  s[14], s[11],
        s[8],  s[5],  s[2],  s[15],
        s[12], s[9],  s[6],  s[3]
    ]
    s = [INV_SBOX[b] for b in s]
    s = [s[i] ^ rkeys[0][i] for i in range(16)]
    return s


class SimSoC:
    def __init__(self, hex_file):
        # 16 KB ROM and 16 KB RAM
        self.rom = [0x00000013] * 4096 # NOP
        self.ram = [0] * 4096

        # Load ROM hex
        if os.path.exists(hex_file):
            with open(hex_file, 'r') as f:
                lines = f.readlines()
                for idx, l in enumerate(lines):
                    if idx < 4096:
                        l = l.strip()
                        if l:
                            self.rom[idx] = int(l, 16)

        # CPU State
        self.pc = 0
        self.regs = [0] * 32
        self.cycle_count = 0

        # Peripherals
        # UART
        self.uart_ctrl = 3
        self.uart_bauddiv = 434
        self.uart_output_log = []

        # Timer
        self.timer_count = 0
        self.timer_compare = 0xFFFFFFFF
        self.timer_ctrl = 0
        self.timer_prescale = 0

        # GPIO
        self.gpio_input = 0
        self.gpio_output = 0
        self.gpio_dir = 0

        # PRNG
        self.prng_seed = 0xACE12468
        self.prng_ctrl = 5
        self.prng_status = 1
        self.lfsr = 0xACE12468
        self.xorshift = 0x2468ACE1

        # SPI
        self.spi_ctrl = 2
        self.spi_clkdiv = 4
        self.spi_status = 2
        self.spi_rx_data = 0
        self.spi_tx_log = []

        # AES-128
        self.aes_ctrl = 0
        self.aes_status = 0
        self.aes_key = [0, 0, 0, 0]
        self.aes_din = [0, 0, 0, 0]
        self.aes_dout = [0, 0, 0, 0]

    def prng_step(self):
        # Xorshift32
        x = self.xorshift
        x = (x ^ ((x << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF
        x = (x ^ (x >> 17)) & 0xFFFFFFFF
        x = (x ^ ((x << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF
        self.xorshift = x

        # LFSR
        if self.lfsr & 1:
            self.lfsr = (self.lfsr >> 1) ^ 0x80200003
        else:
            self.lfsr = self.lfsr >> 1

    def bus_read(self, addr):
        # ROM: 0x0000_0000 - 0x0000_3FFF
        if (addr & 0xFFFF0000) == 0x00000000:
            w_idx = (addr & 0x3FFF) >> 2
            return self.rom[w_idx] if w_idx < 4096 else 0

        # RAM: 0x2000_0000 - 0x2000_3FFF
        if (addr & 0xFFFF0000) == 0x20000000:
            w_idx = (addr & 0x3FFF) >> 2
            return self.ram[w_idx] if w_idx < 4096 else 0

        # Peripherals: 0x4000_XXXX
        if (addr & 0xFFFF0000) == 0x40000000:
            periph = (addr >> 8) & 0xFF
            offset = addr & 0xFF

            # UART (0x4000_00XX)
            if periph == 0x00:
                if offset == 0x00: return 0
                if offset == 0x04: return 2 # TX ready
                if offset == 0x08: return self.uart_ctrl
                if offset == 0x0C: return self.uart_bauddiv

            # Timer (0x4000_10XX)
            if periph == 0x10:
                if offset == 0x00: return self.timer_count
                if offset == 0x04: return self.timer_compare
                if offset == 0x08: return self.timer_ctrl
                if offset == 0x0C: return self.timer_prescale

            # GPIO (0x4000_20XX)
            if periph == 0x20:
                if offset == 0x00: return self.gpio_input
                if offset == 0x04: return self.gpio_output
                if offset == 0x08: return self.gpio_dir

            # AES-128 (0x4000_30XX)
            if periph == 0x30:
                if offset == 0x00: return self.aes_ctrl
                if offset == 0x04: return self.aes_status
                if offset == 0x08: return self.aes_key[0]
                if offset == 0x0C: return self.aes_key[1]
                if offset == 0x10: return self.aes_key[2]
                if offset == 0x14: return self.aes_key[3]
                if offset == 0x18: return self.aes_din[0]
                if offset == 0x1C: return self.aes_din[1]
                if offset == 0x20: return self.aes_din[2]
                if offset == 0x24: return self.aes_din[3]
                if offset == 0x28: return self.aes_dout[0]
                if offset == 0x2C: return self.aes_dout[1]
                if offset == 0x30: return self.aes_dout[2]
                if offset == 0x34: return self.aes_dout[3]

            # PRNG (0x4000_40XX)
            if periph == 0x40:
                if offset == 0x00: return self.prng_seed
                if offset == 0x04: return self.prng_ctrl
                if offset == 0x08: return 1
                if offset == 0x0C:
                    val = self.xorshift if (self.prng_ctrl & 4) else self.lfsr
                    self.prng_step()
                    return val

            # SPI (0x4000_50XX)
            if periph == 0x50:
                if offset == 0x00: return self.spi_rx_data
                if offset == 0x04: return self.spi_status
                if offset == 0x08: return self.spi_ctrl
                if offset == 0x0C: return self.spi_clkdiv

        return 0xDEADBEEF

    def bus_write(self, addr, val):
        val &= 0xFFFFFFFF
        # RAM
        if (addr & 0xFFFF0000) == 0x20000000:
            w_idx = (addr & 0x3FFF) >> 2
            if w_idx < 4096:
                self.ram[w_idx] = val
            return

        # Peripherals
        if (addr & 0xFFFF0000) == 0x40000000:
            periph = (addr >> 8) & 0xFF
            offset = addr & 0xFF

            # UART
            if periph == 0x00:
                if offset == 0x00:
                    ch = chr(val & 0xFF)
                    self.uart_output_log.append(ch)
                    sys.stdout.write(ch)
                    sys.stdout.flush()
                elif offset == 0x08: self.uart_ctrl = val
                elif offset == 0x0C: self.uart_bauddiv = val

            # Timer
            elif periph == 0x10:
                if offset == 0x00: self.timer_count = val
                elif offset == 0x04: self.timer_compare = val
                elif offset == 0x08: self.timer_ctrl = val
                elif offset == 0x0C: self.timer_prescale = val

            # GPIO
            elif periph == 0x20:
                if offset == 0x04: self.gpio_output = val
                elif offset == 0x08: self.gpio_dir = val
                elif offset == 0x0C: self.gpio_output |= val
                elif offset == 0x10: self.gpio_output &= ~val

            # AES-128
            elif periph == 0x30:
                if offset == 0x00:
                    self.aes_ctrl = val
                    if val & 1: # START
                        self.run_aes_operation(val)
                elif offset == 0x08: self.aes_key[0] = val
                elif offset == 0x0C: self.aes_key[1] = val
                elif offset == 0x10: self.aes_key[2] = val
                elif offset == 0x14: self.aes_key[3] = val
                elif offset == 0x18: self.aes_din[0] = val
                elif offset == 0x1C: self.aes_din[1] = val
                elif offset == 0x20: self.aes_din[2] = val
                elif offset == 0x24: self.aes_din[3] = val

            # PRNG
            elif periph == 0x40:
                if offset == 0x00:
                    self.prng_seed = val
                    self.xorshift = val if val else 0x2468ACE1
                    self.lfsr = val if val else 0xACE12468
                elif offset == 0x04: self.prng_ctrl = val

            # SPI
            elif periph == 0x50:
                if offset == 0x00:
                    tx_byte = val & 0xFF
                    self.spi_tx_log.append(tx_byte)
                    self.spi_rx_data = tx_byte # Loopback simulation
                elif offset == 0x08: self.spi_ctrl = val
                elif offset == 0x0C: self.spi_clkdiv = val

    def run_aes_operation(self, ctrl_val):
        is_decrypt = (ctrl_val & 2) != 0
        # Convert 4 32-bit words into 16-byte arrays
        key_bytes = []
        for w in self.aes_key:
            key_bytes.extend([(w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF])
        din_bytes = []
        for w in self.aes_din:
            din_bytes.extend([(w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF])

        rkeys = aes_key_expansion(key_bytes)
        if is_decrypt:
            out_bytes = aes_decrypt(din_bytes, rkeys)
        else:
            out_bytes = aes_encrypt(din_bytes, rkeys)

        # Convert back to 4 words
        for i in range(4):
            self.aes_dout[i] = (out_bytes[4*i] << 24) | (out_bytes[4*i+1] << 16) | (out_bytes[4*i+2] << 8) | out_bytes[4*i+3]

        self.aes_status = 6 # DONE (bit 1) and VALID (bit 2)

    def step(self):
        self.cycle_count += 1
        if self.timer_ctrl & 1:
            self.timer_count = (self.timer_count + 1) & 0xFFFFFFFF

        # Fetch
        instr = self.bus_read(self.pc)
        pc_next = (self.pc + 4) & 0xFFFFFFFF

        opcode = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x07
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        r1_val = 0 if rs1 == 0 else self.regs[rs1]
        r2_val = 0 if rs2 == 0 else self.regs[rs2]

        # Immediates
        imm_i = (instr >> 20) if not (instr & 0x80000000) else ((instr >> 20) - 0x1000)
        imm_s = (((instr >> 25) << 5) | ((instr >> 7) & 0x1F))
        if imm_s & 0x800: imm_s -= 0x1000
        imm_b = (((instr >> 31) << 12) | (((instr >> 7) & 1) << 11) | (((instr >> 25) & 0x3F) << 5) | (((instr >> 8) & 0xF) << 1))
        if imm_b & 0x1000: imm_b -= 0x2000
        imm_u = instr & 0xFFFFF000
        imm_j = (((instr >> 31) << 20) | (((instr >> 12) & 0xFF) << 12) | (((instr >> 20) & 1) << 11) | (((instr >> 21) & 0x3FF) << 1))
        if imm_j & 0x100000: imm_j -= 0x200000

        # Decode & Execute
        if opcode == 0x37: # LUI
            if rd != 0: self.regs[rd] = imm_u & 0xFFFFFFFF
        elif opcode == 0x17: # AUIPC
            if rd != 0: self.regs[rd] = (self.pc + imm_u) & 0xFFFFFFFF
        elif opcode == 0x6F: # JAL
            if rd != 0: self.regs[rd] = pc_next
            pc_next = (self.pc + imm_j) & 0xFFFFFFFF
        elif opcode == 0x67: # JALR
            if rd != 0: self.regs[rd] = pc_next
            pc_next = (r1_val + imm_i) & ~1
        elif opcode == 0x63: # Branch
            take = False
            if funct3 == 0: take = (r1_val == r2_val) # BEQ
            elif funct3 == 1: take = (r1_val != r2_val) # BNE
            elif funct3 == 4: # BLT
                take = (r1_val if r1_val < 0x80000000 else r1_val - 0x100000000) < (r2_val if r2_val < 0x80000000 else r2_val - 0x100000000)
            elif funct3 == 5: # BGE
                take = (r1_val if r1_val < 0x80000000 else r1_val - 0x100000000) >= (r2_val if r2_val < 0x80000000 else r2_val - 0x100000000)
            elif funct3 == 6: take = (r1_val < r2_val) # BLTU
            elif funct3 == 7: take = (r1_val >= r2_val) # BGEU
            if take:
                pc_next = (self.pc + imm_b) & 0xFFFFFFFF
        elif opcode == 0x03: # Load
            addr = (r1_val + imm_i) & 0xFFFFFFFF
            val = self.bus_read(addr)
            if rd != 0: self.regs[rd] = val & 0xFFFFFFFF
        elif opcode == 0x23: # Store
            addr = (r1_val + imm_s) & 0xFFFFFFFF
            self.bus_write(addr, r2_val)
        elif opcode == 0x13: # OP-IMM
            res = 0
            if funct3 == 0: res = r1_val + imm_i # ADDI
            elif funct3 == 7: res = r1_val & imm_i # ANDI
            elif funct3 == 6: res = r1_val | imm_i # ORI
            elif funct3 == 4: res = r1_val ^ imm_i # XORI
            if rd != 0: self.regs[rd] = res & 0xFFFFFFFF
        elif opcode == 0x33: # OP
            res = 0
            if funct3 == 0:
                res = (r1_val - r2_val) if funct7 == 0x20 else (r1_val + r2_val)
            elif funct3 == 7: res = r1_val & r2_val
            elif funct3 == 6: res = r1_val | r2_val
            elif funct3 == 4: res = r1_val ^ r2_val
            if rd != 0: self.regs[rd] = res & 0xFFFFFFFF

        self.pc = pc_next
        self.regs[0] = 0

    def run(self, max_cycles=10000):
        print(f"[SIM] Starting simulation with up to {max_cycles} cycles...")
        while self.cycle_count < max_cycles:
            self.step()
            # If GPIO output Pin 1 is high (Pass) or Pin 2 (Fail)
            if (self.gpio_output & 2) != 0:
                print("\n[SIM] GPIO Pin 1 set HIGH -> Firmware Reported SUCCESS!")
                return True
            if (self.gpio_output & 4) != 0:
                print("\n[SIM] GPIO Pin 2 set HIGH -> Firmware Reported FAILURE!")
                return False
        print(f"\n[SIM] Reached maximum cycles ({max_cycles})")
        return False

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    hex_path = os.path.join(base_dir, "rom.hex")
    if not os.path.exists(hex_path):
        hex_path = os.path.join(base_dir, "..", "sim", "rom.hex")
    sim = SimSoC(hex_path)
    ok = sim.run()
    if ok:
        print(f"\n>> ALL SIMULATION CHECKS PASSED in {sim.cycle_count} cycles!")
        sys.exit(0)
    else:
        print("\n>> SIMULATION CHECKS FAILED!")
        sys.exit(1)
