default: code.hex

hello.o : hello.c 
	riscv32-none-elf-gcc -c -g -O0 -ffreestanding -march=rv32i_zicsr -mabi=ilp32 -o hello.o hello.c

startup.o : startup.s
	riscv32-none-elf-as -march=rv32i_zicsr -mabi=ilp32 -o startup.o startup.s

hello.elf: hello.o startup.o link.ld 
	riscv32-none-elf-ld -T link.ld -o hello.elf hello.o startup.o

hello.bin: hello.elf 
	riscv32-none-elf-objcopy -O binary hello.elf hello.bin 

code.hex: hello.bin 
	hexdump -v -e '1/4 "%08x" "\n"' hello.bin > ../../code.hex

clean: 
	rm -rf hello.o startup.o hello.bin hello.elf ../../code.hex
