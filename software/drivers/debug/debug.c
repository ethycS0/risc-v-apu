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

void print_crash_dump(unsigned long mcause, unsigned long mepc, unsigned long mtval, unsigned long *fp) {
        uart_puts("\n\n\033[31m!!! SYSTEM TRAP (CRASH) !!!\033[0m\n");
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
                        uart_puts(" - Store/AMO access fault\n");
                        break;
                case 18:
                        uart_puts(" - Software check exception\n");
                        break;
                default:
                        uart_puts(" - Unknown exception code\n");
                        break;
                }

                uart_puts("\nmcause: ");
                print_hex(mcause);
                uart_puts("\nmepc:   ");
                print_hex(mepc);
                uart_puts("\nmtval:  ");
                print_hex(mtval);
                uart_puts("\n-------------------\n");
                while (1) {
                        __asm__("NOP");
                }
        }
}
