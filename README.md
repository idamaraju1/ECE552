# ECE 552: Introduction to Computer Architecture

Course Repository for ECE 552: Introduction to Computer Architecture

This project is divided into several phases:
1. RISC-V Assembly Language (2.5%)
2. Verilog and Debugging (2.5%)
3. Digital Design (5.0%)
4. Single-Cycle Processor Design (10.0%)

More to be announced...

## phase4 notes
- HowToRun.txt (for unjuanable2): how to run local tests
- all control signals.xlsx: values of all controls signals corresponding to each inst
- rtl/: all .v files need to be submitted
  - rf.v: 
    - doesn't have an write_enable signal. Because in tb.v, they use the condition ```rd_waddr != 5'd0``` to indicate a write inst.
    - the array name of registers inside rf.v must be ```mem``` to match tb.v
  - pc.v: doesn't instantiate dff.v. Because the reset values of o_pc and o_retire_valid aren't 0.
- tb/: tb.v
