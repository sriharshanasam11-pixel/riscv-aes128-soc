// ============================================================================
// File: spi.c
// Description: SPI Master Driver Implementation
// ============================================================================

#include "spi.h"
#include "soc_regs.h"

void spi_init(uint16_t clk_div) {
    SPI_CLKDIV = (uint32_t)clk_div;
    SPI_CTRL = SPI_CTRL_CS_N; // Enable disabled, CS_N high (inactive)
}

void spi_cs_assert(void) {
    SPI_CTRL &= ~SPI_CTRL_CS_N; // Active low
}

void spi_cs_deassert(void) {
    SPI_CTRL |= SPI_CTRL_CS_N; // Inactive high
}

uint8_t spi_transfer_byte(uint8_t tx_data) {
    // Wait for transmit buffer ready
    while (!(SPI_STATUS & SPI_STATUS_TX_EMPTY));
    SPI_DATA = (uint32_t)tx_data;

    // Wait until transfer completes
    while (SPI_STATUS & SPI_STATUS_BUSY);
    return (uint8_t)(SPI_DATA & 0xFF);
}

void spi_write_block(const uint8_t *buffer, uint32_t len) {
    spi_cs_assert();
    for (uint32_t i = 0; i < len; i++) {
        spi_transfer_byte(buffer[i]);
    }
    spi_cs_deassert();
}
