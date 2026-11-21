// ============================================================================
// File: aes.c
// Description: AES-128 Hardware Accelerator Driver Implementation
// ============================================================================

#include "aes.h"
#include "soc_regs.h"

void aes_init(void) {
    AES_CTRL = AES_CTRL_RESET;
    for (volatile int i = 0; i < 10; i++);
    AES_CTRL = 0;
}

void aes_set_key(const uint32_t key[4]) {
    AES_KEY0 = key[0];
    AES_KEY1 = key[1];
    AES_KEY2 = key[2];
    AES_KEY3 = key[3];
}

void aes_encrypt_block(const uint32_t pt[4], uint32_t ct[4]) {
    // Load Plaintext
    AES_DIN0 = pt[0];
    AES_DIN1 = pt[1];
    AES_DIN2 = pt[2];
    AES_DIN3 = pt[3];

    // Trigger encryption (Mode = 0)
    AES_CTRL = AES_CTRL_START;

    // Wait until done
    while (AES_STATUS & AES_STATUS_BUSY);
    while (!(AES_STATUS & AES_STATUS_VALID));

    // Retrieve Ciphertext
    ct[0] = AES_DOUT0;
    ct[1] = AES_DOUT1;
    ct[2] = AES_DOUT2;
    ct[3] = AES_DOUT3;
}

void aes_decrypt_block(const uint32_t ct[4], uint32_t pt[4]) {
    // Load Ciphertext
    AES_DIN0 = ct[0];
    AES_DIN1 = ct[1];
    AES_DIN2 = ct[2];
    AES_DIN3 = ct[3];

    // Trigger decryption (Mode = 1)
    AES_CTRL = AES_CTRL_START | AES_CTRL_MODE_DEC;

    // Wait until done
    while (AES_STATUS & AES_STATUS_BUSY);
    while (!(AES_STATUS & AES_STATUS_VALID));

    // Retrieve Plaintext
    pt[0] = AES_DOUT0;
    pt[1] = AES_DOUT1;
    pt[2] = AES_DOUT2;
    pt[3] = AES_DOUT3;
}
