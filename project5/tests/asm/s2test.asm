L0: addi x7, x0, 0x100
L1: addi x6, x0, 0x1
    nop
    nop
L2: sw x6, 0(x7)
L3: sw x6, 4(x7)
    nop
    nop
    nop
L4: lw x5, 0(x7)
L5: lw x4, 4(x7)
    nop
    nop
    nop
L6: bne x4, x5, fail
pass: 
    li a0, 1
    ebreak
fail:
    li a0, 0xdead
    ebreak
