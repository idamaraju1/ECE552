cd .../ECE552/project5

iverilog -g2012 \
    -o tb/hart_sim \
    -s hart_tb \
    tb/tb.v \
    rtl/hart.v \
    rtl/if_id.v \
    rtl/id_ex.v \
    rtl/ex_mem.v \
    rtl/mem_wb.v \
    rtl/pc.v \
    rtl/rf.v \
    rtl/ctrl.v \
    rtl/alu.v \
    rtl/alu_ctrl.v \
    rtl/imm.v \
    rtl/trap.v \
    rtl/dff.v

cd tb
vvp hart_sim