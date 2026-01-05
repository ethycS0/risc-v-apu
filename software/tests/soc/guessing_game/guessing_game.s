.section .text
.globl _start

# -------------------------------------------------------------------
# REGISTER MAPPING
# x1 (ra) : Return Address
# x2 (sp) : Stack Pointer (Not strictly used here, but good practice)
# x8 (s0) : UART BASE ADDRESS (0x80000000)
# x9 (s1) : THE SECRET NUMBER (ASCII)
# -------------------------------------------------------------------

_start:
    lui     s0, 0x80000        # s0 = 0x80000000 (UART Base)

# -------------------------------------------------------------------
# 1. SEEDING PHASE (The "Random" Generator)
# -------------------------------------------------------------------
new_game:
    # Print the intro banner
    la      a0, msg_intro      # Load address of intro message
    jal     ra, print_str      # Call print function

    # Initialize "Random" Counter in s1 (Start at ASCII '0')
    addi    s1, x0, 48         # 48 is ASCII for '0'

seed_loop:
    # Cycle s1 from '0' (48) to '9' (57) repeatedly
    addi    s1, s1, 1          # Increment secret number
    addi    t0, x0, 58         # Limit is '9' + 1
    bne     s1, t0, check_input
    addi    s1, x0, 48         # Reset to '0' if we hit limit

check_input:
    # Poll UART Status to see if user pressed a key to start
    lw      t1, 4(s0)          # Read status register
    andi    t1, t1, 2          # Mask Bit 1 (RX_VALID)
    beq     t1, x0, seed_loop  # If no key, keep cycling RNG

    # Key pressed! Consume it (clear RX) and start game
    lw      t2, 0(s0)          # Read the dummy start byte
    sw      x0, 4(s0)          # Clear RX flag
    
    # Print "Game Started" prompt
    la      a0, msg_prompt
    jal     ra, print_str

# -------------------------------------------------------------------
# 2. MAIN GAME LOOP
# -------------------------------------------------------------------
guess_loop:
    # Wait for User Input
    jal     ra, get_char       # Returns character in a0
    
    # Save the user's input char to t3 so we can use a0 for printing
    add     t3, a0, x0         

    # Echo the user's character back to screen (so they see what they typed)
    jal     ra, print_char

    # Compare Guess (t3) vs Secret (s1)
    beq     t3, s1, player_won
    blt     t3, s1, too_low
    bge     t3, s1, too_high

too_low:
    la      a0, msg_low
    jal     ra, print_str
    j       guess_loop         # Jump back to guess again

too_high:
    la      a0, msg_high
    jal     ra, print_str
    j       guess_loop         # Jump back to guess again

player_won:
    la      a0, msg_win
    jal     ra, print_str
    j       new_game           # Restart the whole game

# -------------------------------------------------------------------
# SUBROUTINES
# -------------------------------------------------------------------

# --- get_char ---
# Blocks until a character is received. Returns char in a0.
get_char:
    lw      t0, 4(s0)          # Load Status
    andi    t0, t0, 2          # Check RX_VALID bit
    beq     t0, x0, get_char   # Loop if empty
    
    lw      a0, 0(s0)          # Read Data
    sw      x0, 4(s0)          # Clear RX Flag (Important for your HW)
    ret

# --- print_str ---
# Prints null-terminated string pointed to by a0
print_str:
    add     t5, a0, x0         # Copy string address to t5
ps_loop:
    lb      a0, 0(t5)          # Load byte
    beq     a0, x0, ps_done    # If null, return
    
    # Save current return address (ra) because print_char overwrites it? 
    # Actually, we are leaf function here mostly, but let's be safe:
    # We'll inline the TX logic here to avoid stack complexity in a basic demo.
    
    # --- INLINED TX LOGIC (Your custom HW requirements) ---
wait_ready_1:
    lw      t1, 4(s0)
    andi    t1, t1, 1
    beq     t1, x0, wait_ready_1
    
    sw      a0, 0(s0)          # Write char
    
wait_busy:
    lw      t1, 4(s0)
    andi    t1, t1, 1
    bne     t1, x0, wait_busy  # Wait for TX_READY to go LOW
    
wait_ready_2:
    lw      t1, 4(s0)
    andi    t1, t1, 1
    beq     t1, x0, wait_ready_2 # Wait for TX_READY to go HIGH
    # ------------------------------------------------------

    addi    t5, t5, 1          # Next char
    j       ps_loop
ps_done:
    ret

# --- print_char ---
# Prints single char in a0. (Duplicates logic above for single calls)
print_char:
wait_pc_1:
    lw      t1, 4(s0)
    andi    t1, t1, 1
    beq     t1, x0, wait_pc_1
    sw      a0, 0(s0)
wait_pc_busy:
    lw      t1, 4(s0)
    andi    t1, t1, 1
    bne     t1, x0, wait_pc_busy
wait_pc_2:
    lw      t1, 4(s0)
    andi    t1, t1, 1
    beq     t1, x0, wait_pc_2
    ret

# -------------------------------------------------------------------
# DATA SECTION
# -------------------------------------------------------------------
.section .rodata
msg_intro:
    .string "\r\n\r\n=== GUESS THE NUMBER (0-9) ===\r\nPress any key to start RNG...\r\n"
msg_prompt:
    .string "Generating... Done! Enter guess: "
msg_low:
    .string " -> Too Low!\r\nTry again: "
msg_high:
    .string " -> Too High!\r\nTry again: "
msg_win:
    .string " -> CORRECT! You are the winner!\r\n"
