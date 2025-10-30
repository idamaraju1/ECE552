`default_nettype none

// The register file is effectively a single cycle memory with 32-bit words
// and depth 32. It has two asynchronous read ports, allowing two independent
// registers to be read at the same time combinationally, and one synchronous
// write port, allowing a register to be written to on the next clock edge.
//
// The register `x0` is hardwired to zero.
// NOTE: This can be implemented either by silently discarding writesto
// address 5'd0, or by muxing the output to zero when reading from that
// address.
module rf #(
    // When this parameter is set to 1, "RF bypass" mode is enabled. This
    // allows data at the write port to be observed at the read ports
    // immediately without having to wait for the next clock edge. This is
    // a common forwarding optimization in a pipelined core (phase 5), but will
    // cause a single-cycle processor to behave incorrectly. You are required
    // to implement and test both modes. In phase 4, you will disable this
    // parameter, before enabling it in phase 6.
    parameter BYPASS_EN = 1
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Both read register ports are asynchronous (zero-cycle). That is, read
    // data is visible combinationally without having to wait for a clock.
    //
    // The read ports are *independent* and can read two different registers
    // (but of course, also the same register if needed).
    //
    // Register `x0` is hardwired to zero, so reading from address 5'd0
    // should always return 32'd0 on either port regardless of any writes.
    //
    // Register read port 1, with input address [0,31] and output data.
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    // Register read port 2, with input address [0,31] and output data.
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    // The register write port is synchronous. 
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);

    // 32 (deep) 32-bit (wide) registers,
    wire [31:0] mem [31:0];
    // 32bit each    an array of 32 registers
    // Register `x0` is hardwired to zero

    // Read data (asynchronous/combinational) + RF bypassing.
    assign o_rs1_rdata = (i_rs1_raddr == 5'd0) ? 32'd0 : 
        (BYPASS_EN && (i_rd_waddr == i_rs1_raddr) && (i_rd_waddr != 5'd0)) ? i_rd_wdata : 
        mem[i_rs1_raddr];
    assign o_rs2_rdata = (i_rs2_raddr == 5'd0) ? 32'd0 : 
        (BYPASS_EN && (i_rd_waddr == i_rs2_raddr) && (i_rd_waddr != 5'd0)) ? i_rd_wdata : 
        mem[i_rs2_raddr];

    // Write data (synchronous).
    genvar i;
    generate 
        for (i = 0; i < 32; i = i + 1) begin 
            dff reg_ff[31:0] (
                .i_clk({32{i_clk}}), 
                .i_rst({32{i_rst}}), 
                .i_d( (i_rd_waddr == i[4:0] && i_rd_waddr != 5'd0) ? i_rd_wdata : mem[i] ), 
                .o_q(mem[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
