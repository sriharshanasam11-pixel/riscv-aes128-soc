/* ============================================================================
 * File: linker.ld
 * Description: Linker script mapping text to ROM (16KB) and data/bss to RAM (16KB)
 * ============================================================================ */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > ROM

    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > ROM

    .bss : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    _end = .;
}
