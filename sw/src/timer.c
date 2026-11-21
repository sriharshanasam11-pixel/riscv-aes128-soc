// ============================================================================
// File: timer.c
// Description: System Timer Driver Implementation
// ============================================================================

#include "timer.h"
#include "soc_regs.h"

void timer_init(uint16_t prescaler) {
    TIMER_PRESCALE = (uint32_t)prescaler;
    TIMER_COUNT = 0;
    TIMER_COMPARE = 0xFFFFFFFFU;
    TIMER_CTRL = 0;
}

void timer_start(void) {
    TIMER_CTRL |= TIMER_CTRL_ENABLE;
}

void timer_stop(void) {
    TIMER_CTRL &= ~TIMER_CTRL_ENABLE;
}

uint32_t timer_get_count(void) {
    return TIMER_COUNT;
}

void timer_reset(void) {
    TIMER_COUNT = 0;
}

void timer_delay(uint32_t cycles) {
    uint32_t start = TIMER_COUNT;
    while ((TIMER_COUNT - start) < cycles);
}
