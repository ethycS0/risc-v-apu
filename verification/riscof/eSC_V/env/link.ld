OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text) }

  . = ALIGN(16);
  .data : 
  { 
    *(.data)
    *(.data.*)
    *(.tohost)

    /* --- SIGNATURE SECTION --- */
    . = ALIGN(16);
    
    /* 1. Map Start Symbol to Assembly Label */
    PROVIDE(rvtest_sig_begin = begin_signature);
    
    *(.signature)
    *(.test.output)
    
    /* 2. Map End Symbol to Assembly Label (Ignores Padding) */
    PROVIDE(rvtest_sig_end = end_signature);
  }

  .bss : { *(.bss) }
  _end = .;
}
