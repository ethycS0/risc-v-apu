# Bootstrap for simple C programs

.section .text._start
.global _start

_start:
        la sp, __stack_top
        mv s0, sp
        jal ra, main

loop:   j loop  
