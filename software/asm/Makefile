# Toolchain
PREFIX  = riscv32-none-elf-
AS      = $(PREFIX)as
LD      = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy

# Flags
ASFLAGS = -march=rv32i_zicsr -mabi=ilp32
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

# All available tests
ALL_TESTS = add csr stest soc_test

.PHONY: all clean help build-all

# Default Target
all: $(TARGET)

# 4. Binary -> Hex (Text) -> Project Root
$(TARGET): $(BIN)
	@echo "Generating Hex file at $(TARGET)..."
	hexdump -v -e '1/4 "%08x" "\n"' $< > $@
	@echo "Done: $(TEST) -> $(TARGET)"

# 3. ELF -> Binary (Raw Machine Code)
$(BIN): $(ELF)
	@echo "Creating binary from ELF..."
	$(OBJCOPY) -O binary $< $@

# 2. Object -> ELF (Linking with Memory Map)
$(ELF): $(OBJ)
	@echo "Linking object file..."
	$(LD) $(LDFLAGS) -o $@ $<

# 1. Assembly -> Object
$(OBJ): $(SRC)
	@echo "Assembling $(SRC)..."
	$(AS) $(ASFLAGS) -o $@ $<

# Build all tests sequentially
build-all:
	@for test in $(ALL_TESTS); do \
		echo "Building $$test..."; \
		$(MAKE) TEST=$$test all || exit 1; \
	done

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	rm -f add/*.o add/*.elf add/*.bin
	rm -f csr/*.o csr/*.elf csr/*.bin
	rm -f stest/*.o stest/*.elf stest/*.bin
	rm -f soc_test/*.o soc_test/*.elf soc_test/*.bin
	rm -f $(ROOT_DIR)/imem.hex
	@echo "Clean complete"

# Help target
help:
	@echo "RISC-V Assembly Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make              - Build default test ($(TEST))"
	@echo "  make TEST=<name>  - Build specific test"
	@echo "  make build-all    - Build all tests"
	@echo "  make clean        - Remove all build artifacts"
	@echo ""
	@echo "Available tests: $(ALL_TESTS)"

