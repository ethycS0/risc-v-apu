#include "tetris.h"
#include "uart.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
        printf("Welcome to Tetris\n");
        while (1) {
                unsigned char c = 0x00;
                while (c != 0x20) {
                        uart_getc(&c);
                }

                tetris_run(20, 20);
        }
        return EXIT_SUCCESS;
}
