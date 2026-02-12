# tests/libc
CC := riscv32-unknown-elf-gcc
AS := riscv32-unknown-elf-as

DRIVERS_DIR := ../../drivers
COMMON_DIR := ../../common

CFLAGS := -c -g -O0 -ffreestanding -march=rv32i_zicsr -mabi=ilp32
# CFLAGS := -c -g -O2 -ffreestanding -fcf-protection=branch -fno-inline-functions -fno-unit-at-a-time -mno-relax -fno-jump-tables -mstrict-align -march=rv32i_zicfilp_zicsr -mabi=ilp32 -D__OPTIMIZE_SIZE__ -fno-partial-inlining -fno-optimize-sibling-calls -fno-ipa-sra -fno-shrink-wrap -fno-caller-saves
CFLAGS += -I$(DRIVERS_DIR)/debug -I$(DRIVERS_DIR)/uart

export CC
export CFLAGS

ASFLAGS := -march=rv32i_zicfilp_zicsr -mabi=ilp32

LDFLAGS := -march=rv32i_zicfilp_zicsr -mabi=ilp32 -nostartfiles
LDFLAGS += --specs=nano.specs
LDFLAGS += -T$(COMMON_DIR)/link.ld

SRCS := main.c
OBJS := $(SRCS:.c=.o) 

TARGET := libc.elf

all: $(TARGET)

$(TARGET): crt0.o $(OBJS) $(DRIVERS_DIR)/libdrivers.a
	$(CC) $(LDFLAGS) -o $@ crt0.o $(OBJS) \
	    $(DRIVERS_DIR)/syscalls/syscalls.o \
	    $(DRIVERS_DIR)/debug/debug.o \
	    $(DRIVERS_DIR)/uart/uart.o

%.o: %.c 
	$(CC) $(CFLAGS) $< -o $@

crt0.o: $(COMMON_DIR)/crt0.s
	$(AS) $(ASFLAGS) $< -o $@

$(DRIVERS_DIR)/libdrivers.a:
	$(MAKE) -C $(DRIVERS_DIR) clean
	$(MAKE) -C $(DRIVERS_DIR)

clean: 
	rm -rf crt0.o $(OBJS) $(TARGET)

.PHONY: all clean

