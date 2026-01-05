.section .text
.globl _start

_start:
    lui     x1, 0x80000         # x1 = 0x80000000

listen_loop:
    lw      x2, 4(x1)           # Read status
    andi    x2, x2, 2           # Mask Bit 1 (RX_VALID)
    beq     x2, x0, listen_loop

    lw      x5, 0(x1)           # Read RX data
    sw      x0, 4(x1)           # Clear RX flag

    # Check for SPACE, CR, or LF
    addi    x6, x0, 32
    beq     x5, x6, print_msg
    addi    x6, x0, 13
    beq     x5, x6, print_msg
    addi    x6, x0, 10
    beq     x5, x6, print_msg

    jal     x0, listen_loop

print_msg:
    la      x4, msg             # Load message address

tx_loop:
    lb      x3, 0(x4)           # Load byte
    beq     x3, x0, listen_loop # If null, done

wait_tx_ready:
    # Wait for TX_READY = 1 (UART is idle)
    lw      x2, 4(x1)
    andi    x2, x2, 1
    beq     x2, x0, wait_tx_ready

    # Write character to trigger transmission
    sw      x3, 0(x1)

wait_tx_busy:
    # CRITICAL: Wait for TX_READY to go LOW (transmission started)
    lw      x2, 4(x1)
    andi    x2, x2, 1
    bne     x2, x0, wait_tx_busy  # Stay here while TX_READY=1

wait_tx_done:
    # Now wait for TX_READY to go HIGH again (transmission done)
    lw      x2, 4(x1)
    andi    x2, x2, 1
    beq     x2, x0, wait_tx_done  # Stay here while TX_READY=0

    # Move to next character
    addi    x4, x4, 1
    jal     x0, tx_loop

.section .rodata
msg:
    .string "Hello World!\r\n"

