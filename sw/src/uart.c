// ============================================================================
// File: uart.c
// Description: UART Driver Implementation
// ============================================================================

#include "uart.h"
#include "soc_regs.h"

void uart_init(uint32_t baud_div) {
    UART_BAUDDIV = baud_div;
    UART_CTRL = 0x03; // Enable TX and RX
}

void uart_putc(char c) {
    // Wait until transmitter is ready
    while (!(UART_STATUS & UART_STATUS_TX_READY));
    UART_DATA = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

char uart_getc(void) {
    while (!(UART_STATUS & UART_STATUS_RX_VALID));
    return (char)(UART_DATA & 0xFF);
}

void uart_print_hex32(uint32_t val) {
    const char hex_chars[] = "0123456789abcdef";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uint8_t nibble = (val >> (i * 4)) & 0x0F;
        uart_putc(hex_chars[nibble]);
    }
}
