// ============================================================================
// File: aes.h
// Description: AES-128 Hardware Accelerator Driver Header
// ============================================================================

#ifndef AES_H
#define AES_H

#include <stdint.h>

void aes_init(void);
void aes_set_key(const uint32_t key[4]);
void aes_encrypt_block(const uint32_t pt[4], uint32_t ct[4]);
void aes_decrypt_block(const uint32_t ct[4], uint32_t pt[4]);

#endif // AES_H
