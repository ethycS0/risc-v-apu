#include "debug.h"
#include "uart.h"

// --- ANSI Escape Codes for Terminal Colors ---
#define RESET "\033[0m"
#define RED "\033[1;31m"
#define GREEN "\033[1;32m"
#define YELLOW "\033[1;33m"
#define CYAN "\033[1;36m"

void win_function(void) {
        uart_puts("\n" RED "==================================================" RESET "\n");
        uart_puts(RED "[!] CRITICAL: ARBITRARY CODE EXECUTION ACHIEVED!" RESET "\n");
        uart_puts(RED "[!] Control flow successfully hijacked." RESET "\n");
        uart_puts(RED "==================================================" RESET "\n");
        while (1) {
                __asm__("nop");
        }
}

void vulnerable_function(void) {
        char buffer[16];
        uart_puts(YELLOW "[*] Awaiting ROP payload via UART..." RESET "\n> ");

        static int i;
        static unsigned char c;
        i = 0;
        while (1) {
                if (uart_getc(&c)) {
                        // Removed uart_putc(c) here to hide the ugly payload string in the screenshot
                        if (c == '\r' || c == '\n') {
                                buffer[i] = '\0';
                                break;
                        }
                        buffer[i++] = c;
                }
        }
        uart_puts(CYAN "\n[+] Payload received. Executing return..." RESET "\n");
}

int main(void) {
        init();

        uart_puts("\n" CYAN "=== RISC-V M-MODE SECURE MONITOR ===" RESET "\n");

#ifdef __ENABLE_SMCFISS__
        uart_puts(GREEN "[+] Smcfiss (Shadow Stack) : ENABLED" RESET "\n");
#else
        uart_puts(RED "[-] Smcfiss (Shadow Stack) : DISABLED" RESET "\n");
#endif

#ifdef __ENABLE_ZICFILP__
        uart_puts(GREEN "[+] Zicfilp (Landing Pad)  : ENABLED" RESET "\n");
#else
        uart_puts(RED "[-] Zicfilp (Landing Pad)  : DISABLED" RESET "\n");
#endif
        uart_puts(CYAN "====================================" RESET "\n\n");

        struct __attribute__((packed)) {
                char buffer[16];
                void (*action)(char *);
        } ctx;

        ctx.action = (void (*)(char *))vulnerable_function;

        void *jop_landing_addr;
        __asm__ volatile("la %0, jop_landing" : "=r"(jop_landing_addr));

        uart_puts("[INFO] jop_landing target : ");
        print_hex((unsigned int)jop_landing_addr);
        uart_puts("\n[INFO] win_function target: ");
        print_hex((unsigned int)win_function);

        uart_puts("\n\n" YELLOW "[*] PHASE 1: JOP VULNERABILITY (Zicfilp Test)" RESET "\n");
        uart_puts("Overflow ctx.buffer to overwrite ctx.action:\n> ");

        static int ji;
        static unsigned char jc;
        ji = 0;

        while (1) {
                if (uart_getc(&jc)) {
                        // Removed echo here too
                        if (jc == '\r' || jc == '\n') {
                                ctx.buffer[ji] = '\0';
                                break;
                        }
                        ctx.buffer[ji++] = jc;
                }
        }

        uart_puts(CYAN "\n[+] Payload received. Jumping via hijacked ctx.action..." RESET "\n");
        ctx.action(ctx.buffer);

        // --- ROP Target Label ---
        static const int password[] = {'r', 'e', 'a', 'l', '_', 'p', 'a', 's', 's', 'w', 'o', 'r', 'd', 0};
        char pbuf[16];

        uart_puts("\n" YELLOW "[*] PHASE 2: ROP VULNERABILITY (Smcfiss Test)" RESET "\n");
        uart_puts("Enter Password to proceed naturally:\n> ");

        static int pi;
        static unsigned char pc;
        pi = 0;
        while (1) {
                if (uart_getc(&pc)) {
                        uart_putc(pc); // We keep echo here because this is natural typing
                        if (pc == '\r' || pc == '\n') {
                                pbuf[pi] = '\0';
                                break;
                        }
                        pbuf[pi++] = pc;
                }
        }

        int match = 1;
        for (int k = 0; k < 16; k++) {
                if ((unsigned char)pbuf[k] != (unsigned int)password[k]) {
                        match = 0;
                        break;
                }
                if (password[k] == 0)
                        break;
        }

        if (match) {
                __asm__ volatile(".globl jop_landing\njop_landing:");
                win_function();
        }

        uart_puts(GREEN "\n[+] Normal execution finished. System Safe." RESET "\n");
        while (1) {
                __asm__("nop");
        }
        return 0;
}
