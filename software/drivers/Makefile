# drivers
CC := riscv32-unknown-elf-gcc
AR := riscv32-unknown-elf-ar 

CFLAGS := -c -g -O0 -ffreestanding -march=rv32i_zicsr -mabi=ilp32
CFLAGS += -Iuart

DIRS := $(wildcard */*)
SRCS := $(wildcard */*.c)
OBJS := $(SRCS:.c=.o)

LIB := libdrivers.a

all: $(LIB)

$(LIB): $(OBJS)
	$(AR) rcs $@ $^
	@echo "Built $@"

%.o: %.c 
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(OBJS) $(LIB)

.PHONY: all clean
