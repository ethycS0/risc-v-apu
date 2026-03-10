#include "debug.h"
#include "uart.h"

void init() {
        unsigned char c = 0x00;
        while (c != 0x20) {
                uart_getc(&c);
        }
}

void print_hex(unsigned long val) {
        uart_puts("0x");
        for (int i = 28; i >= 0; i -= 4) {
                unsigned int nibble = (val >> i) & 0xF;
                if (nibble < 10)
                        uart_putc('0' + nibble);
                else
                        uart_putc('A' + (nibble - 10));
        }
}

void print_crash_dump(unsigned long mcause, unsigned long mepc, unsigned long *fp) {
        uart_puts("\n\n\033[31m!!! SYSTEM TRAP (CRASH) !!!\033[0m\n");
        uart_puts("mcause: ");
        print_hex(mcause);
        uart_puts(" ");
        if (mcause & 0x80000000) {
                uart_puts("(Interrupt)\n");
        } else {
                uart_puts("(Exception)\n");
                switch (mcause) {
                case 0:
                        uart_puts(" - Instruction address misaligned\n");
                        break;
                case 1:
                        uart_puts(" - Instruction access fault\n");
                        break;
                case 2:
                        uart_puts(" - Illegal instruction\n");
                        break;
                case 4:
                        uart_puts(" - Load address misaligned\n");
                        break;
                case 5:
                        uart_puts(" - Load access fault\n");
                        break;
                case 6:
                        uart_puts(" - Store/AMO address misaligned\n");
                        break;
                case 7:
                        uart_puts(" - Store/AMO access fault (Smcfiss shadow stack violation?)\n");
                        break;
                case 18:
                        uart_puts(" - Software check exception (Zicfilp Landing Pad violation!)\n");
                        break;
                default:
                        uart_puts(" - Unknown exception code\n");
                        break;
                }
                uart_puts("mepc:   ");
                print_hex(mepc);
                uart_puts(" (Address where crash happened)\n");

                // Simple Stack Trace Walking
                // Assumes standard RISC-V stack frame:
                // fp[0] = previous_fp
                // fp[-1] = return_address

                uart_puts("\n--- STACK TRACE ---\n");
                int depth = 0;
                while (fp != 0 && depth < 10) {
                        unsigned long ra = *(fp - 1);
                        unsigned long prev_fp = *fp;
                        uart_puts("[");
                        uart_putc('0' + depth);
                        uart_puts("] RA: ");
                        print_hex(ra);
                        uart_puts("  FP: ");
                        print_hex((unsigned long)fp);
                        uart_puts("\n");
                        if (prev_fp <= (unsigned long)fp) {
                                break;
                        }
                        fp = (unsigned long *)prev_fp;

                        depth++;
                }
                uart_puts("-------------------\n");
                while (1) {
                        __asm__("NOP");
                }
        }
}
