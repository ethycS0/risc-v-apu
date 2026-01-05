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
TEST    ?= core/add

# Extract directory and base name from TEST path
TEST_DIR  = $(dir $(TEST))
TEST_NAME = $(notdir $(TEST))

# Files
SRC     = $(TEST_DIR)$(TEST_NAME)/$(TEST_NAME).s
OBJ     = $(TEST_DIR)$(TEST_NAME)/$(TEST_NAME).o
ELF     = $(TEST_DIR)$(TEST_NAME)/$(TEST_NAME).elf
BIN     = $(TEST_DIR)$(TEST_NAME)/$(TEST_NAME).bin
TARGET  = $(ROOT_DIR)/imem.hex

# All available tests
ALL_TESTS = core/add core/csr soc/feedback soc/transmit soc/hello_world soc/guessing_game

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
	find core soc -type f \( -name "*.o" -o -name "*.elf" -o -name "*.bin" \) -delete
	rm -f $(ROOT_DIR)/imem.hex
	@echo "Clean complete"

# Help target
help:
	@echo "RISC-V Assembly Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make                 - Build default test ($(TEST))"
	@echo "  make TEST=core/add   - Build specific test"
	@echo "  make TEST=soc/transmit - Build transmit test"
	@echo "  make build-all       - Build all tests"
	@echo "  make clean           - Remove all build artifacts"
	@echo ""
	@echo "Available tests:"
	@for test in $(ALL_TESTS); do echo "  $$test"; done

