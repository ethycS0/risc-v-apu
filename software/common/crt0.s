# Bootstrap Assembly for C

.section .text.init
.global _start

_start:
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

        call main

loop:   j loop  
