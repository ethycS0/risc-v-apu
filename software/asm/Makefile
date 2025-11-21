# Toolchain
PREFIX  = riscv32-none-elf-
AS      = $(PREFIX)as
LD      = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy

# Flags
ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -T link.ld

# Directories
ROOT_DIR = ../..
TEST    ?= add
TEST_DIR = $(TEST)

# Files
SRC     = $(TEST_DIR)/$(TEST).s
OBJ     = $(TEST_DIR)/$(TEST).o
ELF     = $(TEST_DIR)/$(TEST).elf
BIN     = $(TEST_DIR)/$(TEST).bin
TARGET  = $(ROOT_DIR)/imem.hex

.PHONY: all clean

# Default Target
all: $(TARGET)

# 4. Binary -> Hex (Text) -> Project Root
$(TARGET): $(BIN)
	@echo "Generating Hex file at $(TARGET)..."
	hexdump -v -e '1/4 "%08x" "\n"' $< > $@

# 3. ELF -> Binary (Raw Machine Code)
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

# 2. Object -> ELF (Linking with Memory Map)
$(ELF): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $<

# 1. Assembly -> Object
$(OBJ): $(SRC)
	$(AS) $(ASFLAGS) -o $@ $<

# Cleanup
clean:
	rm -f $(TEST_DIR)/*.o $(TEST_DIR)/*.elf $(TEST_DIR)/*.bin $(TARGET)
	rm -f $(TARGET)
