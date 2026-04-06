#include "debug.h"
#include "uart.h"

#define ANSI_SAVE_CURSOR "\x1B[s"
#define ANSI_RESTORE_CURSOR "\x1B[u"

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

void uart_put_int(int num) {
        if (num == 0) {
                uart_putc('0');
                return;
        }
        char buf[10];
        int i = 0;
        while (num > 0) {
                buf[i++] = (num % 10) + '0';
                num /= 10;
        }
        while (i > 0) {
                uart_putc(buf[--i]);
        }
}

void set_cursor(int row, int col) {
        uart_puts("\x1B[");
        uart_put_int(row);
        uart_putc(';');
        uart_put_int(col);
        uart_putc('H');
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

void print_gprs_col(int start_row, int col) {
        _dump_gprs();

        const char *names[32] = {"zero", "ra  ", "sp  ", "gp  ", "tp  ", "t0  ", "t1  ", "t2  ", "s0  ", "s1  ", "a0  ",
                                 "a1  ", "a2  ", "a3  ", "a4  ", "a5  ", "a6  ", "a7  ", "s2  ", "s3  ", "s4  ", "s5  ",
                                 "s6  ", "s7  ", "s8  ", "s9  ", "s10 ", "s11 ", "t3  ", "t4  ", "t5  ", "t6  "};

        set_cursor(start_row, col);
        uart_puts("\033[1;33m=== HARDWARE GPR DUMP ===\033[0m");

        for (int i = 0; i < 16; i++) {
                set_cursor(start_row + 1 + i, col); // Move down one row at a time

                unsigned int val1 = (i == 0) ? 0 : gprs_dump_buf[i];
                unsigned int val2 = gprs_dump_buf[i + 16];

                uart_puts("\033[1;36m");
                uart_puts(names[i]);
                uart_puts("\033[0m: ");
                print_hex(val1);

                uart_puts("    ");

                uart_puts("\033[1;36m");
                uart_puts(names[i + 16]);
                uart_puts("\033[0m: ");
                print_hex(val2);
        }
}

void print_csrs_col(int start_row, int col) {
        _dump_csrs();

        const char *names[8] = {"mtvec   ", "mseccfg ", "mcycle  ", "minstret",
                                "ssp     ", "mscratch", "pmpcfg0 ", "pmpaddr0"};

        set_cursor(start_row, col);
        uart_puts("\033[1;33m=== HARDWARE CSR DUMP ===\033[0m");

        for (int i = 0; i < 4; i++) {
                set_cursor(start_row + 1 + i, col);

                uart_puts("\033[1;36m");
                uart_puts(names[i]);
                uart_puts("\033[0m: ");
                print_hex(csrs_dump_buf[i]);

                uart_puts("    ");

                uart_puts("\033[1;36m");
                uart_puts(names[i + 4]);
                uart_puts("\033[0m: ");
                print_hex(csrs_dump_buf[i + 4]);
        }
}

void print_stack_col(int start_row, int col, int entries) {
        if (entries > 16)
                entries = 16;

        unsigned int sp_val;
        __asm__ volatile("mv %0, sp" : "=r"(sp_val));
        unsigned int *sp_ptr = (unsigned int *)sp_val;

        set_cursor(start_row, col);
        uart_puts("\033[1;35m=== HARDWARE STACK DUMP ===\033[0m");

        for (int i = 0; i < entries; i++) {
                set_cursor(start_row + 1 + i, col);
                uart_puts("PTR_");
                uart_put_int(i);
                uart_puts(": ");
                print_hex(*(sp_ptr + i));
        }
}

void update_dashboard() {
        int dashboard_col = 120;

        uart_puts(ANSI_SAVE_CURSOR);

        print_gprs_col(2, dashboard_col);

        print_csrs_col(21, dashboard_col);

        print_stack_col(28, dashboard_col, 8);

        uart_puts(ANSI_RESTORE_CURSOR);
}
