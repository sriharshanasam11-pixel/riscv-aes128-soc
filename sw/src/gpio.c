// ============================================================================
// File: gpio.c
// Description: GPIO Driver Implementation
// ============================================================================

#include "gpio.h"
#include "soc_regs.h"

void gpio_init(uint32_t output_mask) {
    GPIO_DIR = output_mask;
    GPIO_OUTPUT = 0;
}

void gpio_write(uint32_t val) {
    GPIO_OUTPUT = val;
}

uint32_t gpio_read(void) {
    return GPIO_INPUT;
}

void gpio_set_bit(uint8_t pin) {
    GPIO_SET = (1U << pin);
}

void gpio_clear_bit(uint8_t pin) {
    GPIO_CLEAR = (1U << pin);
}

void gpio_toggle_bit(uint8_t pin) {
    uint32_t curr = GPIO_OUTPUT;
    GPIO_OUTPUT = curr ^ (1U << pin);
}
