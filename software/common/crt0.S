 # Bootstrap Assembly for C

.section .text.init

.global _start
.global _trap_handler
.global _enable_zicfilp        

_start:
        la t0, _trap_handler
        csrw 0x305, t0

        la sp, _stack_top
        mv s0, sp

        la t0, _bss_start
        la t1, _bss_end

clear_bss:
        bgeu t0, t1, init_cfi_security
        sw zero, 0(t0)
        addi t0, t0, 4
        j clear_bss

init_cfi_security:
#ifdef __ENABLE_ZICFILP__
        li t0, 1
        csrw 0x747, t0
#endif

#ifdef __ENABLE_SMCFISS__
        la t0, _shadow_stack_bottom
        srli t0, t0, 2          
        csrw 0x3B0, t0          

        la t0, _shadow_stack_top
        srli t0, t0, 2          
        csrw 0x3B1, t0          

        li t0, 1
        csrw 0x350, t0          

        li t0, 0x8000000A       
        csrw 0x352, t0          

        la t0, _shadow_stack_top
        csrw 0x011, t0          

        csrr t0, 0x747
        ori  t0, t0, 4          
        csrw 0x747, t0
#endif

call_main:
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

