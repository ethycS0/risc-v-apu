# drivers
CC ?= riscv32-none-elf-gcc
AR ?= riscv32-none-elf-ar

CFLAGS := -fcf-protection=full -ffreestanding -march=rv32i_zicfilp_zicfiss_zicsr -mabi=ilp32
CFLAGS += -Iuart -Idebug
CFLAGS += -specs=nano.specs

ASM_SRCS := $(wildcard */*.S)
SRCS := $(wildcard */*.c)

OBJS := $(SRCS:.c=.o) $(ASM_SRCS:.S=.o)

LIB := libdrivers.a

all: $(LIB)

$(LIB): $(OBJS)
	$(AR) rcs $@ $^
	@echo "Built $@"

%.o: %.c 
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(LIB)

.PHONY: all clean
