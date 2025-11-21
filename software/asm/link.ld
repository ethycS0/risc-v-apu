OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY {
        RAM (rwx) : ORIGIN = 0x08000000, LENGTH = 128K
}

SECTIONS {
        .text : { *(.text) } > RAM
        .data : { *(.data) } > RAM
        .bss : { *(.bss) } > RAM
}
