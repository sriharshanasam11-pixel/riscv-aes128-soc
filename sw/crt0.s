/* ============================================================================
 * File: crt0.s
 * Description: RISC-V RV32I Startup Assembly & Vector Table
 * ============================================================================ */

.section .text.init
.global _start
.type _start, @function

_start:
    /* Disable interrupts and initialize registers */
    li x1, 0
    li x2, 0x20004000  /* Stack Pointer (top of 16KB Data RAM) */
    li x3, 0           /* Global Pointer */
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0           /* Frame Pointer */
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    /* Clear BSS Section */
    la t0, _bss_start
    la t1, _bss_end
clear_bss_loop:
    bge t0, t1, bss_cleared
    sw zero, 0(t0)
    addi t0, t0, 4
    j clear_bss_loop

bss_cleared:
    /* Call main application */
    call main

    /* Trap loop on exit */
exit_loop:
    wfi
    j exit_loop
