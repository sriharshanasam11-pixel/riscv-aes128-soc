#!/usr/bin/env python3
# ============================================================================
# File: build_app.py
# Description: RV32I Mini-Assembler & ROM Hex Generator
# Compiles app_asm.s into standard rom.hex for $readmemh simulation
# ============================================================================

import sys
import os
import re

REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
    'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
    's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}
for i in range(32):
    REG_MAP[f'x{i}'] = i

def parse_reg(r):
    r = r.strip().lower().rstrip(',')
    if r in REG_MAP:
        return REG_MAP[r]
    raise ValueError(f"Unknown register: {r}")

def parse_imm(val_str):
    val_str = val_str.strip().rstrip(',')
    sign = 1
    if val_str.startswith('-'):
        sign = -1
        val_str = val_str[1:]
    if val_str.startswith(('0x', '0X')):
        return sign * int(val_str, 16)
    return sign * int(val_str, 10)

def assemble_file(src_path, out_hex_path):
    with open(src_path, 'r') as f:
        lines = f.readlines()

    # Pass 1: Parse instructions, expand pseudo-ops, and collect label addresses
    instructions = []
    labels = {}
    current_addr = 0

    for raw_line in lines:
        line = raw_line.split('#')[0].strip()
        if not line or line.startswith('.'):
            continue

        if ':' in line:
            parts = line.split(':')
            label = parts[0].strip()
            labels[label] = current_addr
            line = parts[1].strip()
            if not line:
                continue

        # Tokenize instruction
        tokens = re.split(r'[\s,()]+', line)
        tokens = [t for t in tokens if t]
        if not tokens:
            continue

        op = tokens[0].lower()

        # Pseudo-instruction expansion
        if op == 'li':
            # li rd, imm
            rd = tokens[1]
            imm = parse_imm(tokens[2]) & 0xFFFFFFFF
            # Expand to lui + addi if needed
            if -2048 <= (imm if imm < 0x80000000 else imm - 0x100000000) <= 2047:
                instructions.append(('addi', rd, 'zero', str(imm), current_addr))
                current_addr += 4
            else:
                lui_val = (imm + 0x800) >> 12
                addi_val = imm & 0xFFF
                if addi_val >= 0x800:
                    addi_val -= 0x1000
                instructions.append(('lui', rd, hex(lui_val), current_addr))
                current_addr += 4
                instructions.append(('addi', rd, rd, str(addi_val), current_addr))
                current_addr += 4
        elif op == 'j':
            instructions.append(('jal', 'zero', tokens[1], current_addr))
            current_addr += 4
        elif op == 'beqz':
            instructions.append(('beq', tokens[1], 'zero', tokens[2], current_addr))
            current_addr += 4
        elif op == 'bnez':
            instructions.append(('bne', tokens[1], 'zero', tokens[2], current_addr))
            current_addr += 4
        else:
            instructions.append((tokens, current_addr))
            current_addr += 4

    # Pass 2: Generate machine code
    binary_words = []
    for item in instructions:
        if isinstance(item[0], str): # expanded pseudo op
            op = item[0]
            addr = item[-1]
            args = list(item[1:-1])
        else:
            tokens, addr = item
            op = tokens[0].lower()
            args = tokens[1:]

        word = 0
        if op == 'lui':
            rd = parse_reg(args[0])
            imm = parse_imm(args[1])
            word = ((imm & 0xFFFFF) << 12) | (rd << 7) | 0x37
        elif op == 'addi':
            rd = parse_reg(args[0])
            rs1 = parse_reg(args[1])
            imm = parse_imm(args[2]) & 0xFFF
            word = (imm << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13
        elif op == 'andi':
            rd = parse_reg(args[0])
            rs1 = parse_reg(args[1])
            imm = parse_imm(args[2]) & 0xFFF
            word = (imm << 20) | (rs1 << 15) | (7 << 12) | (rd << 7) | 0x13
        elif op == 'sw':
            # sw rs2, offset(rs1)
            rs2 = parse_reg(args[0])
            offset = parse_imm(args[1])
            rs1 = parse_reg(args[2])
            imm11_5 = (offset >> 5) & 0x7F
            imm4_0 = offset & 0x1F
            word = (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | (imm4_0 << 7) | 0x23
        elif op == 'lw':
            # lw rd, offset(rs1)
            rd = parse_reg(args[0])
            offset = parse_imm(args[1])
            rs1 = parse_reg(args[2])
            imm = offset & 0xFFF
            word = (imm << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03
        elif op == 'beq' or op == 'bne':
            rs1 = parse_reg(args[0])
            rs2 = parse_reg(args[1])
            target_str = args[2]
            target_addr = labels[target_str] if target_str in labels else parse_imm(target_str)
            offset = target_addr - addr
            b_imm12 = (offset >> 12) & 1
            b_imm10_5 = (offset >> 5) & 0x3F
            b_imm4_1 = (offset >> 1) & 0x0F
            b_imm11 = (offset >> 11) & 1
            funct3 = 0 if op == 'beq' else 1
            word = (b_imm12 << 31) | (b_imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b_imm4_1 << 8) | (b_imm11 << 7) | 0x63
        elif op == 'jal':
            rd = parse_reg(args[0])
            target_str = args[1]
            target_addr = labels[target_str] if target_str in labels else parse_imm(target_str)
            offset = target_addr - addr
            j_imm20 = (offset >> 20) & 1
            j_imm10_1 = (offset >> 1) & 0x3FF
            j_imm11 = (offset >> 11) & 1
            j_imm19_12 = (offset >> 12) & 0xFF
            word = (j_imm20 << 31) | (j_imm10_1 << 21) | (j_imm11 << 20) | (j_imm19_12 << 12) | (rd << 7) | 0x6F
        else:
            raise ValueError(f"Unsupported instruction: {op}")

        binary_words.append(word)

    # Write output hex file (4096 words, filled with NOPs)
    with open(out_hex_path, 'w') as f:
        for w in binary_words:
            f.write(f"{w:08x}\n")
        # Pad with NOPs up to 1024 words
        for _ in range(len(binary_words), 1024):
            f.write("00000013\n")

    print(f"Successfully assembled {len(binary_words)} instructions to {out_hex_path}")

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    src = os.path.join(base_dir, "app_asm.s")
    dst = os.path.join(base_dir, "..", "sim", "rom.hex")
    assemble_file(src, dst)
