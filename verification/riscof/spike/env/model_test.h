#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

#define RVMODEL_HALT                                              \
        la t0, tohost;                                            \
        li t1, 1;                                                 \
        sw t1, 0(t0);                                             \
  self_loop:                                                      \
        j self_loop;

#define RVMODEL_DATA_SECTION                                      \
        .pushsection .tohost,"aw",@progbits;                      \
        .align 8; .global tohost; tohost: .word 0; .word 0;       \
        .align 8; .global fromhost; fromhost: .word 0; .word 0;   \
        .popsection;

#define RVMODEL_BOOT

/* RVMODEL_DATA_BEGIN: Marks the start of the signature for RISCOF */
#define RVMODEL_DATA_BEGIN                                              \
  .section .sig,"aw",@progbits;                                         \
  .align 4; .global begin_signature; begin_signature:

/* RVMODEL_DATA_END: Marks the end of the signature */
#define RVMODEL_DATA_END                                                \
  .align 4; .global end_signature; end_signature:                       \
  RVMODEL_DATA_SECTION                                                  \

/* Standard IO Macros (Left empty if not using serial out) */
#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT

#endif // _COMPLIANCE_MODEL_H
