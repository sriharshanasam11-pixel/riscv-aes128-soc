// ============================================================================
// File: gpio.h
// Description: GPIO Driver Header
// ============================================================================

#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

void gpio_init(uint32_t output_mask);
void gpio_write(uint32_t val);
uint32_t gpio_read(void);
void gpio_set_bit(uint8_t pin);
void gpio_clear_bit(uint8_t pin);
void gpio_toggle_bit(uint8_t pin);

#endif // GPIO_H
