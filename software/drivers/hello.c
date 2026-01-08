
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
}

void uart_puts(const char *str) {
        while (*str) {             // Iterate over the string
                uart_putc(*str++); // Write Character
        }
}

int uart_available() { return UART_RX_VALID; } // Return new valid data

unsigned char uart_recv() {
        if (UART_RX_VALID == 0) { // If ran without checking data available, give 0
                return 0x00;
        }

        unsigned char recv_data = UART_DR; // Get data
        UART_STATUS = 0;                   // Clear data valid flag
        return recv_data;
}

void main() {
        int enable = 0;
        while (1) {
                if (uart_available()) {
                        if (uart_recv() == 0x20) {
                                enable = !enable;
                        }
                }

                if (enable) {
                        uart_puts("The quick brown fox jumps over the lazy dog. \r\n");
                }
        }
}
