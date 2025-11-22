L0:  addi x7, x0, 0x140
L1:  addi x1, x0, 10
     nop
     nop
L2:  add x2, x1, x1
     nop 
     nop
L3:  add x3, x2, x2
     nop
     nop
L4:  add x4, x3, x3
     nop
     nop
L5:  add x5, x4, x4
     nop
     nop
L6:  add x6, x5, x5
     nop
     nop
L7:  beq  x6, x7, L10
     nop
     nop
L8:  lui  a0, 0xdead
L9:  ebreak
L10: lui  a0, 0x1
L11: ebreak
