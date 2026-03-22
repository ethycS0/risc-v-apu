# tests/zicfilp
CC := riscv32-unknown-elf-gcc

DRIVERS_DIR := ../../drivers
COMMON_DIR := ../../common

CFLAGS := -c -g -O2 -fcf-protection=branch -ffreestanding -march=rv32i_zicfilp_zicfiss_zicsr -mabi=ilp32
CFLAGS += -I$(DRIVERS_DIR)/debug -I$(DRIVERS_DIR)/uart
CFLAGS += -D__ENABLE_ZICFILP__ 

LDFLAGS := -march=rv32i_zicfilp_zicsr -mabi=ilp32 -nostartfiles
LDFLAGS += --specs=nano.specs
LDFLAGS += -T$(COMMON_DIR)/link.ld

SRCS := main.c
OBJS := $(SRCS:.c=.o) 

TARGET := zicfilp.elf

all: $(TARGET)

$(TARGET): crt0.o $(OBJS) $(DRIVERS_DIR)/libdrivers.a
	$(CC) $(LDFLAGS) -o $@ crt0.o $(OBJS) $(DRIVERS_DIR)/libdrivers.a

%.o: %.c 
	$(CC) $(CFLAGS) $< -o $@

crt0.o: $(COMMON_DIR)/crt0.S
	$(CC) $(CFLAGS) -x assembler-with-cpp -c $< -o $@

$(DRIVERS_DIR)/libdrivers.a:
	$(MAKE) -C $(DRIVERS_DIR) clean
	$(MAKE) -C $(DRIVERS_DIR)

clean: 
	rm -rf crt0.o $(OBJS) $(TARGET)

.PHONY: all clean

