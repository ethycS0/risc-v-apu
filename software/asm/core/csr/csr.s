# RISC-V CSR Unit Test
# Target: Custom VHDL CSR Unit (RV32I Zicsr)
# Registers x1-x10 used for data/temp.
# Register x15 used for final checks/readbacks.

.globl _start

_start:
    # =================================================================
    # 1. SETUP TEST DATA
    # =================================================================
    li x1, 0xAAAAAAAA       # Pattern 1010... (Alternating bits)
    li x2, 0x55555555       # Pattern 0101... (Alternating bits)
    li x3, 0xFFFFFFFF       # All Ones
    li x4, 0x00000000       # Zero

    # =================================================================
    # 2. TEST CSRRW (Atomic Read / Write)
    # Target: mepc (0x341) - Initial Value: 0x00000000
    # =================================================================
    
    # Write 0xAAAAAAAA to mepc, read old value (0) into x15
    csrrw x15, 0x341, x1    
    # EXPECT: x15 = 0x00000000
    # EXPECT: CSR(0x341) internal = 0xAAAAAAAA

    # Verify the write by reading it back using CSRRS with x0 (Read-only)
    csrrs x5, 0x341, x0     
    # EXPECT: x5 = 0xAAAAAAAA

    # =================================================================
    # 3. TEST CSRRS (Atomic Read / Set Bits)
    # Logic: New = Old | Src
    # Current mepc: 0xAAAAAAAA
    # =================================================================

    # Set bits using 0x55555555. (A | 5) = F
    csrrs x6, 0x341, x2
    # EXPECT: x6 = 0xAAAAAAAA (Old Value)
    # EXPECT: CSR(0x341) internal = 0xFFFFFFFF

    # =================================================================
    # 4. TEST CSRRC (Atomic Read / Clear Bits)
    # Logic: New = Old & (!Src)
    # Current mepc: 0xFFFFFFFF
    # =================================================================

    # Clear bits using 0xAAAAAAAA. (F & !A) = 5
    csrrc x7, 0x341, x1
    # EXPECT: x7 = 0xFFFFFFFF (Old Value)
    # EXPECT: CSR(0x341) internal = 0x55555555

    # =================================================================
    # 5. TEST IMMEDIATE OPS (CSRRWI, CSRRSI, CSRRCI)
    # Target: mtvec (0x305) - Initial Value: 0x00000000
    # =================================================================

    # CSRRWI: Write Immediate 5 (0x00000005) to mtvec
    csrrwi x8, 0x305, 5
    # EXPECT: x8 = 0x00000000 (Old Value)
    # EXPECT: CSR(0x305) = 0x00000005

    # CSRRSI: Set Bit 4 (Imm=16 is too big for 5-bit uimm, max is 31)
    # Let's Set Bit 3 (Val 8). 5 | 8 = 13 (0xD)
    csrrsi x9, 0x305, 8
    # EXPECT: x9 = 0x00000005
    # EXPECT: CSR(0x305) = 0x0000000D

    # CSRRCI: Clear Bit 0 (Val 1). 13 & !1 = 12 (0xC)
    csrrci x10, 0x305, 1
    # EXPECT: x10 = 0x0000000D
    # EXPECT: CSR(0x305) = 0x0000000C

    # =================================================================
    # 6. TEST READ-ONLY PROTECTION
    # Target: misa (0x301)
    # VHDL defines: WHEN x"301" => NULL; (Write ignored)
    # =================================================================

    # Try to overwrite misa with 0xFFFFFFFF
    csrrw x15, 0x301, x3
    
    # Read it back to verify it DID NOT change
    csrrs x5, 0x301, x0
    # EXPECT: x5 = 0x40000100 (Your VHDL default)
    # EXPECT: x15 = 0x40000100 (Old value read before attempted write)

    # =================================================================
    # 7. TEST COUNTERS
    # Target: mcycle (0xB00)
    # =================================================================

    # Read cycle counter
    csrrs x6, 0xB00, x0
    nop
    nop
    nop
    # Read cycle counter again (should be higher)
    csrrs x7, 0xB00, x0
    # VERIFY: x7 > x6

    # =================================================================
    # 8. DONE (Infinite Loop)
    # =================================================================
    # Exit
    li x5, 0x80010000   
    li x6, 1            
    sw x6, 0(x5)        

halt:
    beq x0, x0, halt
