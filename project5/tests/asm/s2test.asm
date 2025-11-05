    .section .text
    .global _start

_start:
    # Set up base address for memory
    addi x2, x0, 0x100      # x2 = base address 0x100

    # Store values into memory
    addi x3, x0, 10         # x3 = 10
    sw   x3, 0(x2)          # mem[0x100] = 10

    addi x4, x0, 20         # x4 = 20
    sw   x4, 4(x2)          # mem[0x104] = 20

    addi x5, x0, 30         # x5 = 30
    sw   x5, 8(x2)          # mem[0x108] = 30

    # Now load values back
    lw   x6, 0(x2)          # x6 = mem[0x100] -> should be 10
    lw   x7, 4(x2)          # x7 = mem[0x104] -> should be 20
    lw   x8, 8(x2)          # x8 = mem[0x108] -> should be 30

    # Do some dependent instructions to test stalling
    add  x9, x6, x7         # x9 = 10 + 20 = 30
    add  x10, x9, x8        # x10 = 30 + 30 = 60

    ebreak                   # stop simulation
