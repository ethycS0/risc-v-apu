#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * @brief Simple delay to prevent UART flooding
 */
void delay_cycles(int cycles) {
        for (volatile int i = 0; i < cycles; i++) {
                __asm__("NOP");
        }
}

/**
 * @brief Test 1: Malloc and Free
 * Allocates memory, writes a pattern, verifies it, and frees it.
 * This tests your _sbrk implementation.
 */
void test_memory(void) {
        printf("[MEM] Allocating 64 bytes...\n");

        char *buffer = (char *)malloc(64 * sizeof(char));

        if (buffer == NULL) {
                printf("[FAIL] Malloc returned NULL. Check _sbrk or heap size.\n");
                return;
        }

        const char *test_str = "RISC-V SoC Memory Test";
        strcpy(buffer, test_str);

        if (strcmp(buffer, test_str) == 0) {
                printf("[PASS] Memory Write/Read verification successful.\n");
                printf("      Data: %s\n", buffer);
        } else {
                printf("[FAIL] Memory corruption detected.\n");
        }

        free(buffer);
}

/**
 * @brief Test 2: Random Number Generation
 * Generates pseudo-random numbers.
 * Note: Without a hardware timer for srand(), sequences may repeat on reset.
 */
void test_random(void) {
        printf("[RND] Generating random numbers:\n");

        int r1 = rand();
        int r2 = rand();

        printf("      Val 1: 0x%08X\n", r1);
        printf("      Val 2: 0x%08X\n", r2);

        if (r1 != r2) {
                printf("[PASS] Random numbers vary.\n");
        } else {
                printf("[WARN] Random numbers identical (expected if srand not seeded).\n");
        }
}

/**
 * @brief Test 3: Input Scanning
 * Tests _read via scanf. Blocks until input is received.
 */
void test_input(void) {
        int val = 0;

        printf("[INP] Enter an integer: ");

        if (scanf("%d", &val) == 1) {
                printf("\n[PASS] You entered: %d\n", val);
        } else {
                char buffer[32];
                printf("\n[FAIL] Scanf failed to parse integer.\n");
                clearerr(stdin);
                scanf("%s", buffer);
        }
}

/**
 * @brief Main Test Loop
 */
int main(void) {
        int iteration = 1;

        printf("\n====================================\n");
        printf("  eSC-V Libc Integration Test       \n");
        printf("====================================\n");

        while (1) {
                printf("\n--- Iteration %d ---\n", iteration++);

                // 1. Test Printf formatting (Hex, Int, String)
                printf("[PRT] Formats: Hex[0x%X] Int[%d] Str[%s]\n", 0xDEADBEEF, 12345, "Hello");

                // 2. Test Memory Allocation
                test_memory();

                // 3. Test Random
                test_random();

                // 4. Test Scanf (Interactive)
                test_input();

                printf("Sleeping...\n");
                delay_cycles(1000000);
        }

        return 0;
}
