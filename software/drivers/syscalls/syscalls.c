/**
 * Resources in case I require them in the future
 *
 * https://popovicu.com/posts/bare-metal-printf/
 * https://popovicu.com/posts/bare-metal-programming-risc-v/
 * https://interrupt.memfault.com/blog/boostrapping-libc-with-newlib
 * https://www.sourceware.org/newlib/
 **/

#include "uart.h"

#include <errno.h>
#include <sys/stat.h>
#include <sys/times.h>
#include <unistd.h>

extern int errno;

void *_sbrk(int incr) {
        extern char _end;
        extern char _stack_bottom;

        static char *heap_end = &_end;
        char *prev_heap_end = heap_end;

        if (heap_end + incr > &_stack_bottom) {
                errno = ENOMEM;
                return (void *)-1;
        }

        heap_end += incr;
        return (void *)prev_heap_end;
}

int _read(int file, char *ptr, int len) {
        if (file != STDIN_FILENO) {
                errno = EBADF;
                return -1;
        }

        int itr = 0;
        for (; itr < len; itr++) {
                int result;
                unsigned char recv;

                do {
                        result = uart_getc(&recv);
                } while (result == -1);

                ptr[itr] = recv;
                if (recv == '\n' || recv == '\r') {
                        itr++;
                        break;
                }
        }

        return itr;
}

int _write(int file, char *ptr, int len) {
        if (file != STDOUT_FILENO && file != STDERR_FILENO) {
                errno = EBADF;
                return -1;
        }

        int itr = 0;
        for (; itr < len; itr++) {
                uart_putc(ptr[itr]);
        }

        return itr;
}

// These are for file descriptors and IO relevant to an Operating Systems
// Minimal Implementations for syscalls that are not important for eSC-V

char *__env[1] = {0};
char **environ = __env;

int _open(const char *name, int flags, int mode) { return -1; }
int _close(int fd) { return -1; }
int _lseek(int file, int offset, int whence) { return 0; }
int _getpid(void) { return 1; }
int _isatty(int file) { return 1; }
int _times(struct tms *buf) { return -1; }

int _fstat(int file, struct stat *st) {
        st->st_mode = S_IFCHR;
        return 0;
}

int _kill(int pid, int sig) {
        errno = EINVAL;
        return -1;
}

void _exit(int code) {
        while (1) {
                __asm__("NOP");
        }
}

int _execve(char *name, char **argv, char **env) {
        errno = ENOMEM;
        return -1;
}

int _fork(void) {
        errno = EAGAIN;
        return -1;
}

int _link(char *old, char *new) {
        errno = EMLINK;
        return -1;
}

int _stat(char *file, struct stat *st) {
        st->st_mode = S_IFCHR;
        return 0;
}

int _unlink(char *name) {
        errno = ENOENT;
        return -1;
}

int _wait(int *status) {
        errno = ECHILD;
        return -1;
}
