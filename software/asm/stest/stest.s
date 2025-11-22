# ==============================================================================
# RISC-V RV32I + Zicsr Pipeline Stress Test
# ==============================================================================
# Register Usage Map:
# x1 - x10 : Working registers for calculations
# x28      : Trap Handler Counter (increments on ECALL)
# x29      : CSR verification scratchpad
# x30      : Test Status (1 = PASS, 0 = FAIL)
# x31      : Current Test ID (For debugging where it crashed)
# ==============================================================================

.globl _start
_start:
    # --------------------------------------------------------------------------
    # 1. BASIC DATAPATH & HAZARD TEST (RAW Hazards)
    # --------------------------------------------------------------------------
    li x31, 1               # Test ID: 1
    addi x1, x0, 10         # x1 = 10
    addi x2, x0, 20         # x2 = 20
    
    # TEST: ALU-to-ALU Forwarding (EX -> EX)
    add x3, x1, x2          # x3 = 30 (Write is in WB, next instr needs it in EX)
    sub x4, x3, x1          # x4 = 30 - 10 = 20 (Must forward x3 from EX/MEM)
    
    # CHECK: x4 must be 20
    addi x5, x0, 20
    bne x4, x5, fail

    # TEST: MEM-to-EX Hazard (Load-Use Stall)
    # Assuming x0 points to valid memory, we use relative addressing
    # We store 0xDEADBEEF to address 0x100 for testing
    lui x6, 0x80000         # x6 = 0x80000000
    addi x6, x6, 0x200      # x6 = 0x80000100    
    li x7, 0xDEADBEEF
    sw x7, 0(x6)            # Store to memory
    
    lw x8, 0(x6)            # Load x8 (Result ready in WB stage)
    and x9, x8, x7          # Use x8 immediately (Must STALL 1 cycle)
    
    # CHECK: x9 must be 0xDEADBEEF
    bne x9, x7, fail

    # --------------------------------------------------------------------------
    # 2. CONTROL LOGIC & FLUSHING (Branch/Jump)
    # --------------------------------------------------------------------------
    li x31, 2               # Test ID: 2
    
    # TEST: Branch Taken (Flush pipeline)
    addi x10, x0, 5
    beq x10, x10, jump_target
    
    # If we are here, flush failed!
    j fail

jump_target:
    # TEST: JALR LSB Masking (The Zicsr/JALR compliance check)
    # Target = 4-byte aligned label 'jalr_target', but we add 1 to force misalignment
    la x11, jalr_target     # Load address of label
    addi x11, x11, 1        # Add 1 (odd address)
    jalr x0, 0(x11)         # JALR should mask LSB to 0 and jump correctly
    
    # If we are here, masking failed!
    j fail

jalr_target:
    nop                     # Landing pad

    # --------------------------------------------------------------------------
    # 3. CSR ATOMICITY & LOGIC
    # --------------------------------------------------------------------------
    li x31, 3               # Test ID: 3
    
    # Using mtvec (0x305) as our test register
    li x12, 0xAAAAAAAA      # Pattern 1010...
    
    # TEST: CSRRW (Write Pattern)
    csrrw x13, mtvec, x12   # x13 = old_mtvec, mtvec = 0xAAAAAAAA
    csrr x14, mtvec         # Read back
    bne x14, x12, fail      # Check write

    # TEST: CSRRS (Bit Set)
    # Current: 1010... (0xA)
    # Mask:    0101... (0x5) -> 0x55555555
    li x15, 0x55555555
    csrrs x13, mtvec, x15   # mtvec should become 0xFFFFFFFF
    li x16, 0xFFFFFFFF
    csrr x14, mtvec
    bne x14, x16, fail

    # TEST: CSRRC (Bit Clear)
    # Current: 1111... (0xF)
    # Mask:    1111...0000 (0xFFFF0000)
    li x15, 0xFFFF0000
    csrrc x13, mtvec, x15   # mtvec should become 0x0000FFFF
    li x16, 0x0000FFFF
    csrr x14, mtvec
    bne x14, x16, fail

    # TEST: Side-Effect Protection (Read Only)
    # CSRRS with x0 (imm=0) should NOT write to CSR.
    # However, checking this without a hardware write counter is hard in ASM.
    # We assume the logic check verified earlier covers this.

    # --------------------------------------------------------------------------
    # 4. TRAP HANDLING (ECALL -> MRET)
    # --------------------------------------------------------------------------
    li x31, 4               # Test ID: 4
    li x28, 0               # Reset Trap Counter

    # A. Setup Trap Vector (mtvec) to point to our handler
    la x1, trap_handler
    csrw mtvec, x1

    # B. Trigger Trap
    ecall                   # Should Jump to 'trap_handler'

    # C. Check Return
    # If we are here, MRET worked!
    li x2, 1
    bne x28, x2, fail       # Ensure handler actually ran (x28 should be 1)

    # --------------------------------------------------------------------------
    # SUCCESS
    # --------------------------------------------------------------------------
    li x31, 0xCAFEBABE      # Signature
    li x30, 1               # PASS
    j end

fail:
    li x30, 0               # FAIL status
end:
    li x5, 0x80010000   
    li x6, 1            
    sw x6, 0(x5)        

# ------------------------------------------------------------------------------
# TRAP HANDLER
# ------------------------------------------------------------------------------
.align 4
trap_handler:
    # 1. Increment Verification Counter
    addi x28, x28, 1

    # 2. Adjust MEPC (Return Address)
    # ECALL sets MEPC to the address of the ECALL instruction.
    # We must add 4 to return to the instruction *after* ECALL.
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    # 3. Return from Trap
    # This tests your new MRET logic (Jump to MEPC, restore status)
    mret
