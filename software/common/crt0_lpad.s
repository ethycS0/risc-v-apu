# Bootstrap Assembly for C

.section .text.init
.global _start
.global _trap_handler  

_start:
    la t0, _trap_handler
    csrw 0x305, t0  

    la sp, _stack_top
    mv s0, sp

    la t0, _bss_start
    la t1, _bss_end

clear_bss:
    bgeu t0, t1, bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j clear_bss

bss_done:
    li t0, 1           
    csrw 0x747, t0     

    call main

loop:   j loop  

.align 4
_trap_handler:
    csrr a0, 0x342  # Read mcause (Exception Cause) into Argument 0
    csrr a1, 0x341  # Read mepc   (Exception PC / Address) into Argument 1
    mv   a2, s0     # Move Frame Pointer into Argument 2 (for stack trace)
    
    call print_crash_dump
die:
    j die

