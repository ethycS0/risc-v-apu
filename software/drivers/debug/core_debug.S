# Functions to Print Internal states of CPU 

.global GPRS_SIZE
.global CSRS_SIZE

.set GPRS_SIZE, 128
.set CSRS_SIZE, 32

.section .bss
        .align 4
        .global gprs_dump_buf
        .global csrs_dump_buf
gprs_dump_buf:
        .space GPRS_SIZE
csrs_dump_buf:
        .space CSRS_SIZE

        .section .text
        .global _dump_gprs
        .global _dump_csrs
_dump_gprs:
        lpad 0
        sspush ra
        
        la t0, gprs_dump_buf
        
        sw x1, 1*4(t0)
        sw x2, 2*4(t0) 
        sw x3, 3*4(t0)
        sw x4, 4*4(t0)
        sw x5, 5*4(t0)
        sw x6, 6*4(t0)
        sw x7, 7*4(t0)
        sw x8, 8*4(t0)
        sw x9, 9*4(t0)
        sw x10, 10*4(t0)
        sw x11, 11*4(t0)
        sw x12, 12*4(t0)
        sw x13, 13*4(t0)
        sw x14, 14*4(t0)
        sw x15, 15*4(t0)
        sw x16, 16*4(t0)
        sw x17, 17*4(t0)
        sw x18, 18*4(t0)
        sw x19, 19*4(t0)
        sw x20, 20*4(t0)
        sw x21, 21*4(t0)
        sw x22, 22*4(t0)
        sw x23, 23*4(t0)
        sw x24, 24*4(t0)
        sw x25, 25*4(t0)
        sw x26, 26*4(t0)
        sw x27, 27*4(t0)
        sw x28, 28*4(t0)
        sw x29, 29*4(t0)
        sw x30, 30*4(t0)
        sw x31, 31*4(t0)
        
        mv t0, x1
        sspopchk t0
        jr t0


_dump_csrs:
        lpad 0
        sspush ra

        la t0, csrs_dump_buf

        csrr t1, mtvec
        sw t1, 0*4(t0)

        csrr t1, mseccfg
        sw t1, 1*4(t0)

        csrr t1, mcycle
        sw t1, 2*4(t0)

        csrr t1, minstret
        sw t1, 3*4(t0)

        csrr t1, ssp
        sw t1, 4*4(t0)

        csrr t1, mscratch
        sw t1, 5*4(t0)

        csrr t1, pmpcfg0
        sw t1, 6*4(t0)

        csrr t1, pmpaddr0
        sw t1, 7*4(t0)

        mv t0, ra
        sspopchk t0
        jr t0

