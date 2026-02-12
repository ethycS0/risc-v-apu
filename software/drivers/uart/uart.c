#include "uart.h"

#define MEM_BASE 0x00000000
#define UART_BASE 0x80000000

#define REG(base, offset) (*((volatile unsigned char *)(base + offset)))

#define UART_DR REG(UART_BASE, 0x00)     // UART Data Register
#define UART_STATUS REG(UART_BASE, 0x04) // Read for RX|TX status, Write to clear RX_VALID

#define UART_TX_READY (UART_STATUS & 0x01) // 0 -> TX line is busy  | 1 -> Can Transmit
#define UART_RX_VALID (UART_STATUS & 0x02) // 0 -> No valid RX data | 1 -> Valid RX data, read and clear bit

void uart_putc(char c) {
        while (UART_TX_READY != 1) {
                // Wait for TX Ready
        }

        UART_DR = c; // Write Character to Data Register

        __asm__("nop");

        if (c == '\n') { // Recursive Call to handle newline (CR + LF)
                while (UART_TX_READY != 1) {
                        // Wait for TX Ready
                }
                UART_DR = '\r';
        }
}

int uart_getc(unsigned char *c) {
        if (UART_RX_VALID == 0) { // Check valid data available
                return 0;
        }

        *c = UART_DR;    // Get data
        UART_STATUS = 0; // Clear data valid flag
        return 1;
}
