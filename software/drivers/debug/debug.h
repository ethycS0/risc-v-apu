#ifndef DEBUG_H
#define DEBUG_H

void init();
void print_hex(unsigned long val);

void print_crash_dump(unsigned long mcause, unsigned long mepc, unsigned long mtval, unsigned long *fp);
void print_gprs(void);
void print_csrs(void);
void print_stack(int entries);

#endif
