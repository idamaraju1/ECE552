    .section .text
    .global _start

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------
_start:

    # x2 holds base pointer
    addi x2, x0, 0x100        # arbitrary base

    # pre-init memory
    # (Assume testbench preloads mem[x2] = 10, mem[x2+4] = 20)
    
# ------------------------------------------------------------
# Load-use hazard: MUST STALL
# ------------------------------------------------------------

    lw   x1, 0(x2)            # x1 = 10      (in EX stage)
    addi x3, x1, 1            # must stall   → x3 = 11

    # Space instructions to visually see no mis-execution
    addi x4, x3, 1            # x4 = 12
    addi x5, x4, 2            # x5 = 14

# ------------------------------------------------------------
# Forwardable sequence (no stall, forwarding works)
# ------------------------------------------------------------

    add  x6, x3, x4           # x6 = 11 + 12 = 23
    addi x7, x6, 1            # x7 = 24

# ------------------------------------------------------------
# Load from MEM stage — forwarding should resolve, no stall
# ------------------------------------------------------------

    lw   x8, 4(x2)            # x8 = 20
    add  x9, x8, x7           # forwarding ok → x9 = 20 + 24 = 44

# ------------------------------------------------------------
# Chain to ensure no hidden corruption
# ------------------------------------------------------------

    addi x10, x9, 3           # x10 = 47
    addi x11, x10, 1          # x11 = 48

# ------------------------------------------------------------
# End
# ------------------------------------------------------------
done:
    ebreak
