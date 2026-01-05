#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H
#define RVMODEL_DATA_SECTION \
        .section .data;                                                 \
        .pushsection .tohost,"aw",@progbits;                            \
        .align 8; .global tohost; tohost: .dword 0;                     \
        .align 8; .global fromhost; fromhost: .dword 0;                 \
        .popsection;                                                    \
                                                                        \
        .align 8; .global begin_regstate; begin_regstate:               \
        .word 128;                                                      \
        .align 8; .global end_regstate; end_regstate:                   \
        .word 4;

#define RVMODEL_BOOT \
    .section .text.init; \
    .globl _start; \
    _start:

#define RVMODEL_HALT                                              \
  li x1, 1;                                                       \
  la t5, tohost;                                                  \
  sw x1, 0(t5);                                                   \
1: j 1b;

#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_S, _R, _I)
#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT

#define RVMODEL_DATA_BEGIN                                              \
  .section .test.output;                                                \
  .align 4;                                                             \
  .global begin_signature; begin_signature:

#define RVMODEL_DATA_END                                                \
  .align 4;                                                             \
  .global end_signature; end_signature:                                 \
  RVMODEL_DATA_SECTION

#endif // _COMPLIANCE_MODEL_H

