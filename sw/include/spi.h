// ============================================================================
// File: spi.h
// Description: SPI Master Driver Header
// ============================================================================

#ifndef SPI_H
#define SPI_H

#include <stdint.h>

void spi_init(uint16_t clk_div);
void spi_cs_assert(void);
void spi_cs_deassert(void);
uint8_t spi_transfer_byte(uint8_t tx_data);
void spi_write_block(const uint8_t *buffer, uint32_t len);

#endif // SPI_H
