OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
        RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

__stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS {
        .text : ALIGN(4) {
                KEEP(*(.text._start))
                *(.text.*)
        } > RAM
        
        .rodata : ALIGN(4) {
                *(.rodata.*)
        } > RAM

        .data : ALIGN(4) {
                *(.data.*)
        } > RAM

        .bss : ALIGN(4) {
                KEEP(*(.bss.*))
                *(COMMON)
        } > RAM
}

