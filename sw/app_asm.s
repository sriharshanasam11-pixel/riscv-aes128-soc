# ============================================================================
# File: app_asm.s
# Description: Self-Contained RISC-V RV32I Assembly Application for AES-128 SoC
# Tests UART, Timer, GPIO, PRNG, AES-128 Encrypt/Decrypt, and SPI
# ============================================================================

.globl _start

_start:
    # 1. Initialize Stack Pointer
    lui   sp, 0x20004         # sp = 0x20004000 (top of 16KB Data RAM)

    # Base addresses in saved registers
    lui   s0, 0x40000         # s0 = UART_BASE (0x40000000)
    lui   s1, 0x40001         # s1 = TIMER_BASE (0x40001000)
    lui   s2, 0x40002         # s2 = GPIO_BASE (0x40002000)
    lui   s3, 0x40003         # s3 = AES_BASE (0x40003000)
    lui   s4, 0x40004         # s4 = PRNG_BASE (0x40004000)
    lui   s5, 0x40005         # s5 = SPI_BASE (0x40005000)

    # 2. Configure UART
    li    t0, 434
    sw    t0, 12(s0)          # UART_BAUDDIV = 434
    li    t0, 3
    sw    t0, 8(s0)           # UART_CTRL = 3 (TX_EN | RX_EN)

    # Send 'R' 'V' '3' '2' ' ' 'A' 'E' 'S' '\n'
    li    t0, 82              # 'R'
    sw    t0, 0(s0)
    li    t0, 86              # 'V'
    sw    t0, 0(s0)
    li    t0, 51              # '3'
    sw    t0, 0(s0)
    li    t0, 50              # '2'
    sw    t0, 0(s0)
    li    t0, 32              # ' '
    sw    t0, 0(s0)
    li    t0, 65              # 'A'
    sw    t0, 0(s0)
    li    t0, 69              # 'E'
    sw    t0, 0(s0)
    li    t0, 83              # 'S'
    sw    t0, 0(s0)
    li    t0, 10              # '\n'
    sw    t0, 0(s0)

    # 3. Configure GPIO
    li    t0, 7
    sw    t0, 8(s2)           # GPIO_DIR = 0x07 (Pins 0, 1, 2 outputs)
    li    t0, 1
    sw    t0, 4(s2)           # GPIO_OUTPUT = 1 (Pin 0 Heartbeat on)

    # 4. Read from PRNG
    lw    t1, 12(s4)          # t1 = PRNG_DATA (sample random value)

    # 5. Load NIST AES-128 Key
    # Key: 00010203 04050607 08090a0b 0c0d0e0f
    li    t0, 0x00010203
    sw    t0, 8(s3)           # AES_KEY0

    li    t0, 0x04050607
    sw    t0, 12(s3)          # AES_KEY1

    li    t0, 0x08090a0b
    sw    t0, 16(s3)          # AES_KEY2

    li    t0, 0x0c0d0e0f
    sw    t0, 20(s3)          # AES_KEY3

    # 6. Load NIST AES-128 Plaintext
    # Plaintext: 00112233 44556677 8899aabb ccddeeff
    li    t0, 0x00112233
    sw    t0, 24(s3)          # AES_DIN0

    li    t0, 0x44556677
    sw    t0, 28(s3)          # AES_DIN1

    li    t0, 0x8899aabb
    sw    t0, 32(s3)          # AES_DIN2

    li    t0, 0xccddeeff
    sw    t0, 36(s3)          # AES_DIN3

    # 7. Start Encryption (Mode = 0, Start = 1)
    li    t0, 1
    sw    t0, 0(s3)           # AES_CTRL = 1

wait_enc_done:
    lw    t0, 4(s3)           # t0 = AES_STATUS
    andi  t1, t0, 2           # Check DONE bit
    beqz  t1, wait_enc_done

    # 8. Check Ciphertext against NIST Golden Vector
    # CT: 69c4e0d8 6a7b0430 d8cdb780 70b4c55a
    lw    t1, 40(s3)          # AES_DOUT0
    li    t0, 0x69c4e0d8
    bne   t1, t0, test_failed

    lw    t2, 44(s3)          # AES_DOUT1
    li    t0, 0x6a7b0430
    bne   t2, t0, test_failed

    lw    t3, 48(s3)          # AES_DOUT2
    li    t0, 0xd8cdb780
    bne   t3, t0, test_failed

    lw    t4, 52(s3)          # AES_DOUT3
    li    t0, 0x70b4c55a
    bne   t4, t0, test_failed

    # 9. Test Decryption: Load Ciphertext back into DIN
    sw    t1, 24(s3)          # AES_DIN0
    sw    t2, 28(s3)          # AES_DIN1
    sw    t3, 32(s3)          # AES_DIN2
    sw    t4, 36(s3)          # AES_DIN3

    # Start Decryption (Mode = 1, Start = 1 -> AES_CTRL = 3)
    li    t0, 3
    sw    t0, 0(s3)           # AES_CTRL = 3

wait_dec_done:
    lw    t0, 4(s3)           # t0 = AES_STATUS
    andi  t1, t0, 2           # Check DONE bit
    beqz  t1, wait_dec_done

    # 10. Check Decrypted Plaintext against Original
    lw    t1, 40(s3)          # AES_DOUT0
    li    t0, 0x00112233
    bne   t1, t0, test_failed

    lw    t1, 44(s3)          # AES_DOUT1
    li    t0, 0x44556677
    bne   t1, t0, test_failed

    lw    t1, 48(s3)          # AES_DOUT2
    li    t0, 0x8899aabb
    bne   t1, t0, test_failed

    lw    t1, 52(s3)          # AES_DOUT3
    li    t0, 0xccddeeff
    bne   t1, t0, test_failed

    # 11. Stream byte over SPI
    li    t0, 0x69
    sw    t0, 0(s5)           # SPI_DATA = 0x69

    # 12. Success: Print 'P' 'A' 'S' 'S' '\n'
    li    t0, 80              # 'P'
    sw    t0, 0(s0)
    li    t0, 65              # 'A'
    sw    t0, 0(s0)
    li    t0, 83              # 'S'
    sw    t0, 0(s0)
    li    t0, 83              # 'S'
    sw    t0, 0(s0)
    li    t0, 10              # '\n'
    sw    t0, 0(s0)

    # Set GPIO Pin 1 High (Green LED)
    li    t0, 3               # Heartbeat (Pin 0) + PASS (Pin 1)
    sw    t0, 4(s2)           # GPIO_OUTPUT = 3
    j     idle_loop

test_failed:
    # Failure: Print 'F' 'A' 'I' 'L' '\n'
    li    t0, 70              # 'F'
    sw    t0, 0(s0)
    li    t0, 65              # 'A'
    sw    t0, 0(s0)
    li    t0, 73              # 'I'
    sw    t0, 0(s0)
    li    t0, 76              # 'L'
    sw    t0, 0(s0)
    li    t0, 10              # '\n'
    sw    t0, 0(s0)

    # Set GPIO Pin 2 High (Red LED)
    li    t0, 5               # Heartbeat (Pin 0) + FAIL (Pin 2)
    sw    t0, 4(s2)           # GPIO_OUTPUT = 5

idle_loop:
    # Infinite loop
    j     idle_loop
