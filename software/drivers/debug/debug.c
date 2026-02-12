#include "debug.h"
#include <stdio.h>

void print_crash_dump(unsigned long mcause, unsigned long mepc, unsigned long *fp) {
        printf("\n\n\033[31m!!! SYSTEM TRAP (CRASH) !!!\033[0m\n");

        printf("mcause: 0x%08lx ", mcause);
        if (mcause & 0x80000000) {
                printf("(Interrupt)\n");
        } else {
                printf("(Exception)\n");
                switch (mcause) {
                case 0:
                        printf(" - Instruction address misaligned\n");
                        break;
                case 1:
                        printf(" - Instruction access fault\n");
                        break;
                case 2:
                        printf(" - Illegal instruction\n");
                        break;
                case 4:
                        printf(" - Load address misaligned\n");
                        break;
                case 5:
                        printf(" - Load access fault\n");
                        break;
                case 6:
                        printf(" - Store/AMO address misaligned\n");
                        break;
                case 7:
                        printf(" - Store/AMO access fault\n");
                        break;
                }
        }

        printf("mepc:   0x%08lx (Address where crash happened)\n", mepc);

        // Simple Stack Trace Walking
        // Assumes standard RISC-V stack frame:
        // fp[0] = previous_fp
        // fp[-1] = return_address
        printf("\n--- STACK TRACE ---\n");
        int depth = 0;
        while (fp != 0 && depth < 10) {
                unsigned long ra = *(fp - 1);
                unsigned long prev_fp = *fp;

                printf("[%d] RA: 0x%08lx  FP: 0x%08lx\n", depth, ra, (unsigned long)fp);

                if (prev_fp <= (unsigned long)fp) {
                        break;
                }
                fp = (unsigned long *)prev_fp;
                depth++;
        }
        printf("-------------------\n");

        while (1)
                ; // Halt
}
