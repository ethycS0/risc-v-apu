# Toolchain
PREFIX = riscv32-unknown-elf-
OBJCOPY = $(PREFIX)objcopy

.PHONY: all drivers clean ascii-tetris libc

all: drivers

drivers:
	$(MAKE) -C drivers

libc: drivers 
	$(MAKE) -C tests/libc
	$(OBJCOPY) -O binary tests/libc/libc.elf tests/libc/libc.bin
	hexdump -v -e '1/4 "%08x" "\n"' tests/libc/libc.bin > ../code.hex
	@echo "Generated code.hex for libc"

ascii-tetris: drivers
	$(MAKE) -C apps/ascii-tetris
	$(OBJCOPY) -O binary apps/ascii-tetris/ascii-tetris.elf apps/ascii-tetris/ascii-tetris.bin
	hexdump -v -e '1/4 "%08x" "\n"' apps/ascii-tetris/ascii-tetris.bin > ../code.hex
	@echo "Generated code.hex for ascii-tetris"

clean:
	$(MAKE) -C drivers clean
	$(MAKE) -C apps/ascii-tetris clean
	$(MAKE) -C tests/libc clean
	rm -f ../code.hex apps/*/*.bin tests/*/*.bin

