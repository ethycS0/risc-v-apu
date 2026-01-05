.section .text
.globl _start

_start:
        # Load UART base address into x1
        lui     x1, 0x80000         # x1 = 0x80000000

rx_loop:
        # Poll RX status
        lw      x2, 4(x1)           # Read status register
        andi    x2, x2, 2           # Check bit 1 (RX_VALID)
        beq     x2, x0, rx_loop     # Loop if no data available

        # Read and modify data
        lw      x3, 0(x1)           # Read received byte
        sw      x0, 4(x1)
        addi    x3, x3, 1           # Increment by 1

tx_loop:
        # Poll TX status
        lw      x2, 4(x1)           # Read status register
        andi    x2, x2, 1           # Check bit 1 (TX_READY)
        beq     x2, x0, tx_loop     # Loop if not ready

        # Transmit data
        sw      x3, 0(x1)           # Write byte to TX

        # Loop back to receive next byte
        jal     x0, rx_loop         # Jump back to start

