 # Bootstrap Assembly for C

.section .text.init

.global _start
.global _trap_handler
.global _enable_lp        

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
        call main


loop: j loop

.align 4
_trap_handler:
        csrr a0, 0x342
        csrr a1, 0x341
        mv a2, s0

        call print_crash_dump

die:
        j die

_enable_lp:
        li t0, 1
        csrw 0x747, t0
        ret 
