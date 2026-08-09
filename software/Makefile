# Toolchain
PREFIX = riscv32-none-elf-
OBJCOPY = $(PREFIX)objcopy

.PHONY: all  clean ascii-tetris pong-c libc cfi

all: libc

libc:  
	$(MAKE) -C tests/libc
	$(OBJCOPY) -O binary tests/libc/libc.elf tests/libc/libc.bin
	hexdump -v -e '1/4 "%08x" "\n"' tests/libc/libc.bin > ../code.hex
	@echo "Generated code.hex for libc"

cfi:  
	$(MAKE) -C tests/cfi
	$(OBJCOPY) -O binary tests/cfi/cfi.elf tests/cfi/cfi.bin
	hexdump -v -e '1/4 "%08x" "\n"' tests/cfi/cfi.bin > ../code.hex
	@echo "Generated code.hex for cfi"


ascii-tetris: 
	$(MAKE) -C apps/ascii-tetris
	$(OBJCOPY) -O binary apps/ascii-tetris/ascii-tetris.elf apps/ascii-tetris/ascii-tetris.bin
	hexdump -v -e '1/4 "%08x" "\n"' apps/ascii-tetris/ascii-tetris.bin > ../code.hex
	@echo "Generated code.hex for ascii-tetris"

pong-c: 
	$(MAKE) -C apps/pong-c
	$(OBJCOPY) -O binary apps/pong-c/pong-c.elf apps/pong-c/pong-c.bin
	hexdump -v -e '1/4 "%08x" "\n"' apps/pong-c/pong-c.bin > ../code.hex
	@echo "Generated code.hex for pong-c"

clean:
	$(MAKE) -C drivers clean
	$(MAKE) -C apps/ascii-tetris clean
	$(MAKE) -C apps/pong-c clean
	$(MAKE) -C tests/libc clean
	$(MAKE) -C tests/cfi clean
	rm -f ../code.hex apps/*/*.bin tests/*/*.bin

