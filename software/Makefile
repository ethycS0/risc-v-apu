# Toolchain
PREFIX = riscv32-unknown-elf-
OBJCOPY = $(PREFIX)objcopy

.PHONY: all  clean ascii-tetris pong-c libc zicfilp smcfiss

all: libc

libc:  
	$(MAKE) -C tests/libc
	$(OBJCOPY) -O binary tests/libc/libc.elf tests/libc/libc.bin
	hexdump -v -e '1/4 "%08x" "\n"' tests/libc/libc.bin > ../code.hex
	@echo "Generated code.hex for libc"

zicfilp:  
	$(MAKE) -C tests/zicfilp
	$(OBJCOPY) -O binary tests/zicfilp/zicfilp.elf tests/zicfilp/zicfilp.bin
	hexdump -v -e '1/4 "%08x" "\n"' tests/zicfilp/zicfilp.bin > ../code.hex
	@echo "Generated code.hex for zicfilp"

smcfiss:  
	$(MAKE) -C tests/smcfiss
	$(OBJCOPY) -O binary tests/smcfiss/smcfiss.elf tests/smcfiss/smcfiss.bin
	hexdump -v -e '1/4 "%08x" "\n"' tests/smcfiss/smcfiss.bin > ../code.hex
	@echo "Generated code.hex for smcfiss"


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
	$(MAKE) -C tests/zicfilp clean
	$(MAKE) -C tests/smcfiss clean
	rm -f ../code.hex apps/*/*.bin tests/*/*.bin

