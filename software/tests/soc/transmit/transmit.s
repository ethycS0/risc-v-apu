# Test program: Continuously send 'X' (0x58)
# Memory map: 0x80000000 = UART data, 0x80000004 = UART status

.org 0x0000

_start:
    # Load UART base address into a0
    lui     a0, 0x80000         # a0 = 0x80000000

wait_tx_ready:
    # Poll UART status until TX ready (bit 0)
    lw      t0, 4(a0)           # t0 = status register
    andi    t1, t0, 1           # t1 = tx_ready bit
    beq     t1, zero, wait_tx_ready

    # Send 'X' (0x58)
    li      t2, 0x41            # t2 = 'A'
    sw      t2, 0(a0)           # Write to UART TX

    # Loop forever
    j       wait_tx_ready

