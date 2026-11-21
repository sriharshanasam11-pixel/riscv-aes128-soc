// ============================================================================
// File: prng.c
// Description: Hardware PRNG Driver Implementation
// ============================================================================

#include "prng.h"
#include "soc_regs.h"

void prng_init(uint32_t seed, uint8_t use_xorshift) {
    PRNG_SEED = seed;
    PRNG_CTRL = PRNG_CTRL_ENABLE | (use_xorshift ? PRNG_CTRL_XORSHIFT : 0);
}

uint32_t prng_get_random(void) {
    return PRNG_DATA;
}

void prng_reseed(uint32_t new_seed) {
    PRNG_SEED = new_seed;
    PRNG_CTRL |= PRNG_CTRL_RESEED;
}
