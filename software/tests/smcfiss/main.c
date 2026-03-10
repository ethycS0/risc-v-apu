#include "debug.h"
#include "uart.h"

void win_function(void) {
        uart_puts("\n\n[!] CRITICAL: ROP EXPLOIT SUCCESSFUL!\n");
        uart_puts("[!] Control flow hijacked via Return Address Overwrite!\n");
        while (1) {
                __asm__("nop");
        }
}

void vulnerable_function(void) {
        char buffer[16];

        uart_puts("\n[INFO] Address of win_function:  ");
        print_hex((unsigned int)&win_function);
        uart_puts("\n");
        uart_puts("Enter payload (Overflow past 16 bytes to overwrite saved RA):\n> ");

        // Make these static so they live in .bss, not on the stack!
        static int i;
        static unsigned char c;

        i = 0; // Remember to initialize it here

        while (1) {
                if (uart_getc(&c)) {
                        uart_putc(c);

                        if (c == '\r' || c == '\n') {
                                buffer[i] = '\0';
                                break;
                        }
                        buffer[i++] = c;
                }
        }

        uart_puts("\n[SYSTEM] vulnerable_function() returning...\n");
}

int main(void) {
        init();

#ifdef __ENABLE_SMCFISS__
        uart_puts("\n[SYSTEM] Smcfiss (Shadow Stack) ENABLED.\n");
#else
        uart_puts("\n[SYSTEM] Smcfiss (Shadow Stack) DISABLED.\n");
#endif

        vulnerable_function();

        uart_puts("[SYSTEM] Normal execution finished. Exploit failed.\n");
        while (1) {
                __asm__("nop");
        }
        return 0;
}
