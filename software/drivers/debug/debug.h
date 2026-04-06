#ifndef DEBUG_H
#define DEBUG_H

#define DEBUG_UPDATE()                                                                                                 \
        do {                                                                                                           \
                unsigned int current_sp;                                                                               \
                __asm__ volatile("mv %0, sp" : "=r"(current_sp));                                                      \
                update_dashboard(current_sp);                                                                          \
        } while (0)

void init();
void print_hex(unsigned long val);

void print_crash_dump(unsigned long mcause, unsigned long mepc, unsigned long mtval, unsigned long *fp);

void update_dashboard(unsigned int game_sp);

#endif
