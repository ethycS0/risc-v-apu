# drivers
CC ?= riscv32-unknown-elf-gcc
AR ?= riscv32-unknown-elf-ar

CFLAGS := -fcf-protection=full -ffreestanding -march=rv32i_zicfilp_zicfiss_zicsr -mabi=ilp32
CFLAGS += -Iuart -Idebug

DIRS := $(wildcard */*)
SRCS := $(wildcard */*.c)
OBJS := $(SRCS:.c=.o)

LIB := libdrivers.a

all: $(LIB)

$(LIB): $(OBJS)
	$(AR) rcs $@ $^
	@echo "Built $@"

%.o: %.c 
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(LIB)

.PHONY: all clean
