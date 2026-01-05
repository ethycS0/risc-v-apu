OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
        RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS {
        .text : ALIGN(4) {
                *(.text)
                *(.text.*)
        } > RAM
        
        .rodata : ALIGN(4) {
                *(.rodata)
                *(.rodata.*)
        } > RAM

        .data : ALIGN(4) {
                *(.data)
                *(.data.*)
        } > RAM

        .bss : ALIGN(4) {
                *(.bss)
                *(.bss.*)
                *(COMMON)
        } > RAM
}

