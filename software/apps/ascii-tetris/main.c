#include "tetris.h"
#include "uart.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
        while (1) {
                unsigned char c = 0x00;
                while (c != 0x20) {
                        uart_getc(&c);
                }

                setvbuf(stdout, NULL, _IONBF, 0); // Disable all buffering for stdout
                printf("Welcome to Tetris\n");

                tetris_run(20, 20);
        }
        return EXIT_SUCCESS;
}
