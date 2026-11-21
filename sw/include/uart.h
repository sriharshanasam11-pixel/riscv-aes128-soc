// ============================================================================
// File: uart.h
// Description: UART Driver Header
// ============================================================================

#ifndef UART_H
#define UART_H

#include <stdint.h>

void uart_init(uint32_t baud_div);
void uart_putc(char c);
void uart_puts(const char *str);
char uart_getc(void);
void uart_print_hex32(uint32_t val);

#endif // UART_H
