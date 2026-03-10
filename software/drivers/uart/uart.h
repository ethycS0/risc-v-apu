#ifndef UART_H
#define UART_H

void uart_putc(char c);
int uart_getc(unsigned char *c);
void uart_puts(const char *str);

#endif
