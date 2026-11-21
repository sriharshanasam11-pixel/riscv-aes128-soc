// ============================================================================
// File: soc_regs.h
// Description: SoC Base Addresses, Register Offsets, and Bitfield Definitions
// ============================================================================

#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

// Base Addresses
#define ROM_BASE        0x00000000U
#define RAM_BASE        0x20000000U
#define UART_BASE       0x40000000U
#define TIMER_BASE      0x40001000U
#define GPIO_BASE       0x40002000U
#define AES_BASE        0x40003000U
#define PRNG_BASE       0x40004000U
#define SPI_BASE        0x40005000U

// UART Registers
#define UART_DATA       REG32(UART_BASE + 0x00U)
#define UART_STATUS     REG32(UART_BASE + 0x04U)
#define UART_CTRL       REG32(UART_BASE + 0x08U)
#define UART_BAUDDIV    REG32(UART_BASE + 0x0CU)

#define UART_STATUS_RX_VALID  (1U << 0)
#define UART_STATUS_TX_READY  (1U << 1)

// Timer Registers
#define TIMER_COUNT     REG32(TIMER_BASE + 0x00U)
#define TIMER_COMPARE   REG32(TIMER_BASE + 0x04U)
#define TIMER_CTRL      REG32(TIMER_BASE + 0x08U)
#define TIMER_PRESCALE  REG32(TIMER_BASE + 0x0CU)

#define TIMER_CTRL_ENABLE       (1U << 0)
#define TIMER_CTRL_AUTO_RELOAD  (1U << 1)
#define TIMER_CTRL_IRQ_EN       (1U << 2)
#define TIMER_CTRL_MATCH_FLAG   (1U << 3)

// GPIO Registers
#define GPIO_INPUT      REG32(GPIO_BASE + 0x00U)
#define GPIO_OUTPUT     REG32(GPIO_BASE + 0x04U)
#define GPIO_DIR        REG32(GPIO_BASE + 0x08U)
#define GPIO_SET        REG32(GPIO_BASE + 0x0CU)
#define GPIO_CLEAR      REG32(GPIO_BASE + 0x10U)

// AES Accelerator Registers
#define AES_CTRL        REG32(AES_BASE + 0x00U)
#define AES_STATUS      REG32(AES_BASE + 0x04U)
#define AES_KEY0        REG32(AES_BASE + 0x08U)
#define AES_KEY1        REG32(AES_BASE + 0x0CU)
#define AES_KEY2        REG32(AES_BASE + 0x10U)
#define AES_KEY3        REG32(AES_BASE + 0x14U)
#define AES_DIN0        REG32(AES_BASE + 0x18U)
#define AES_DIN1        REG32(AES_BASE + 0x1CU)
#define AES_DIN2        REG32(AES_BASE + 0x20U)
#define AES_DIN3        REG32(AES_BASE + 0x24U)
#define AES_DOUT0       REG32(AES_BASE + 0x28U)
#define AES_DOUT1       REG32(AES_BASE + 0x2CU)
#define AES_DOUT2       REG32(AES_BASE + 0x30U)
#define AES_DOUT3       REG32(AES_BASE + 0x34U)

#define AES_CTRL_START        (1U << 0)
#define AES_CTRL_MODE_DEC     (1U << 1)
#define AES_CTRL_RESET        (1U << 2)
#define AES_CTRL_IRQ_EN       (1U << 3)

#define AES_STATUS_BUSY       (1U << 0)
#define AES_STATUS_DONE       (1U << 1)
#define AES_STATUS_VALID      (1U << 2)

// PRNG Registers
#define PRNG_SEED       REG32(PRNG_BASE + 0x00U)
#define PRNG_CTRL       REG32(PRNG_BASE + 0x04U)
#define PRNG_STATUS     REG32(PRNG_BASE + 0x08U)
#define PRNG_DATA       REG32(PRNG_BASE + 0x0CU)

#define PRNG_CTRL_ENABLE      (1U << 0)
#define PRNG_CTRL_RESEED      (1U << 1)
#define PRNG_CTRL_XORSHIFT    (1U << 2)

// SPI Registers
#define SPI_DATA        REG32(SPI_BASE + 0x00U)
#define SPI_STATUS      REG32(SPI_BASE + 0x04U)
#define SPI_CTRL        REG32(SPI_BASE + 0x08U)
#define SPI_CLKDIV      REG32(SPI_BASE + 0x0CU)

#define SPI_STATUS_BUSY       (1U << 0)
#define SPI_STATUS_TX_EMPTY   (1U << 1)
#define SPI_STATUS_RX_READY   (1U << 2)

#define SPI_CTRL_ENABLE       (1U << 0)
#define SPI_CTRL_CS_N         (1U << 1)

#endif // SOC_REGS_H
