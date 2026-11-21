// ============================================================================
// File: timer.h
// Description: System Timer Driver Header
// ============================================================================

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

void timer_init(uint16_t prescaler);
void timer_start(void);
void timer_stop(void);
uint32_t timer_get_count(void);
void timer_reset(void);
void timer_delay(uint32_t cycles);

#endif // TIMER_H
