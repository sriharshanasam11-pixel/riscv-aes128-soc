// ============================================================================
// File: prng.h
// Description: Hardware PRNG Driver Header
// ============================================================================

#ifndef PRNG_H
#define PRNG_H

#include <stdint.h>

void prng_init(uint32_t seed, uint8_t use_xorshift);
uint32_t prng_get_random(void);
void prng_reseed(uint32_t new_seed);

#endif // PRNG_H
