#ifndef DEBUG_H
#define DEBUG_H

void print_crash_dump(unsigned long mcause, unsigned long mepc, unsigned long mtval, unsigned long *fp);
void print_hex(unsigned long val);
void init();

#endif
