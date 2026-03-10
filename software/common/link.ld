OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
        RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 32K
}


SECTIONS {
        .text : ALIGN(4) {
                KEEP(*(.text.init))
                *(.text.*)
        } > RAM
        
        .rodata : ALIGN(4) {
                *(.rodata.*)
        } > RAM

        .data : ALIGN(4) {
                *(.data.*)
                *(.sdata*)
        } > RAM

        .bss : ALIGN(4) {
                _bss_start = .;
                *(.bss.*)
                *(.sbss.*)
                *(COMMON)
                . = ALIGN(8);
                _bss_end = .;
        } > RAM

        . = ALIGN(8);
        _end = .;
        _heap_start = .;

        _stack_size = 2K;
        _stack_top = ORIGIN(RAM) + LENGTH(RAM);
        _stack_bottom = _stack_top - _stack_size;

        _shadow_stack_size = 1K;
        _shadow_stack_top = _stack_bottom; 
        _shadow_stack_bottom = _shadow_stack_top - _shadow_stack_size;

        ASSERT(_end <= _shadow_stack_bottom, "Error: Heap collides with shadow stack")
}

