#include "debug.h"
#include "uart.h"

extern unsigned int gprs_dump_buf[32];
extern unsigned int csrs_dump_buf[8];

extern void _dump_gprs(void);
extern void _dump_csrs(void);

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

void print_gprs(void) {

        _dump_gprs();

        const char *names[32] = {"zero", "ra  ", "sp  ", "gp  ", "tp  ", "t0  ", "t1  ", "t2  ", "s0  ", "s1  ", "a0  ",
                                 "a1  ", "a2  ", "a3  ", "a4  ", "a5  ", "a6  ", "a7  ", "s2  ", "s3  ", "s4  ", "s5  ",
                                 "s6  ", "s7  ", "s8  ", "s9  ", "s10 ", "s11 ", "t3  ", "t4  ", "t5  ", "t6  "};

        uart_puts("\033[1;33m\n=== HARDWARE GPR DUMP ===\033[0m\n");

        for (int i = 0; i < 16; i++) {
                unsigned int val1 = gprs_dump_buf[i];
                unsigned int val2 = gprs_dump_buf[i + 16];

                if (i == 0) {
                        val1 = 0;
                }

                uart_puts("\033[1;36m");
                uart_puts(names[i]);
                uart_puts("\033[0m: ");
                print_hex(val1);

                uart_puts("    ");

                uart_puts("\033[1;36m");
                uart_puts(names[i + 16]);
                uart_puts("\033[0m: ");
                print_hex(val2);

                uart_puts("\n");
        }
        uart_puts("\033[1;33m=========================\033[0m\n");
}

void print_csrs(void) {
        _dump_csrs();

        const char *names[8] = {"mtvec   ", "mseccfg ", "mcycle  ", "minstret",
                                "ssp     ", "mscratch", "pmpcfg0 ", "pmpaddr0"};

        uart_puts("\033[1;33m\n=== HARDWARE CSR DUMP ===\033[0m\n");
        for (int i = 0; i < 4; i++) {
                unsigned int val1 = csrs_dump_buf[i];
                unsigned int val2 = csrs_dump_buf[i + 4];

                uart_puts("\033[1;36m");
                uart_puts(names[i]);
                uart_puts("\033[0m: ");
                print_hex(val1);

                uart_puts("    ");

                uart_puts("\033[1;36m");
                uart_puts(names[i + 4]);
                uart_puts("\033[0m: ");
                print_hex(val2);

                uart_puts("\n");
        }
        uart_puts("\033[1;33m=========================\033[0m\n");
}

void print_stack(int entries) {
        if (entries > 16) {
                return;
        }

        unsigned int sp_val;
        __asm__ volatile("mv %0, sp" : "=r"(sp_val));

        unsigned int *sp_ptr = (unsigned int *)sp_val;

        uart_puts("\033[1;35m\n=== HARDWARE STACK DUMP ===\033[0m\n");
        for (int i = 0; i < entries; i++) {
                unsigned int *current_addr = sp_ptr + i;
                print_hex(*current_addr);
                uart_puts("\n");
        }

        uart_puts("\033[1;33m=========================\033[0m\n");
}
