#include "debug.h"
#include "uart.h"

extern void enable_lp(void);

void win_function(char *ignored) {
        uart_puts("\n\n[!] CRITICAL: JOP EXPLOIT SUCCESSFUL!\n");
        uart_puts("[!] Control flow hijacked to win_function().\n");
        while (1) {
                __asm__("nop");
        }
}

void normal_action(char *msg) {
        uart_puts("\nNormal action executed safely. Message: ");
        uart_puts(msg);
        uart_puts("\n");
}

struct VulnerableContext {
        char buffer[16];
        void (*action)(char *);
};

int main(void) {
        init();

#ifdef __ENABLE_ZICFILP__
        enable_lp();
        uart_puts("\n[SYSTEM] Zicfilp (Landing Pads) ENABLED.\n");
#else
        uart_puts("\n[SYSTEM] Zicfilp (Landing Pads) DISABLED.\n");
#endif

        struct VulnerableContext ctx;
        ctx.action = normal_action;

        uart_puts("[INFO] Address of normal_action: ");
        print_hex((unsigned int)&normal_action);
        uart_puts("\n");
        uart_puts("[INFO] Address of win_function:  ");
        print_hex((unsigned int)&win_function);
        uart_puts("\n");

        uart_puts("\nEnter string (Overflow past 16 bytes to overwrite func ptr):\n> ");

        int i = 0;
        unsigned char c;
        while (1) {
                if (uart_getc(&c)) {
                        uart_putc(c);

                        if (c == '\r' || c == '\n') {
                                ctx.buffer[i] = '\0';
                                break;
                        }
                        ctx.buffer[i++] = c;
                }
        }

        uart_puts("\n[SYSTEM] Executing context action pointer...\n");

        ctx.action(ctx.buffer);

        uart_puts("[SYSTEM] Normal execution finished.\n");
        while (1) {
                __asm__("nop");
        }
        return 0;
}
