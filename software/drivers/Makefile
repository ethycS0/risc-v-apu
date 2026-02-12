# drivers
CC ?= riscv32-unknown-elf-gcc
AS ?= riscv32-unknown-elf-as
AR ?= riscv32-unknown-elf-ar

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
