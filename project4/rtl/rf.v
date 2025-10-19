`default_nettype none
module rf #(
    parameter BYPASS_EN = 0
) (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [4:0]  i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    input  wire [4:0]  i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    input  wire        i_rd_wen,
    input  wire [4:0]  i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);
    reg [31:0] mem [0:31];

    assign o_rs1_rdata = (i_rs1_raddr == 5'd0) ? 32'd0 :
                         (BYPASS_EN && i_rd_wen && (i_rd_waddr == i_rs1_raddr) && (i_rd_waddr != 5'd0)) ? i_rd_wdata :
                         mem[i_rs1_raddr];

    assign o_rs2_rdata = (i_rs2_raddr == 5'd0) ? 32'd0 :
                         (BYPASS_EN && i_rd_wen && (i_rd_waddr == i_rs2_raddr) && (i_rd_waddr != 5'd0)) ? i_rd_wdata :
                         mem[i_rs2_raddr];

    integer k;
    always @(posedge i_clk) begin
        if (i_rst) begin
            for (k = 0; k < 32; k = k + 1) mem[k] <= 32'd0;
        end else if (i_rd_wen && (i_rd_waddr != 5'd0)) begin
            mem[i_rd_waddr] <= i_rd_wdata;
        end
    end
endmodule
`default_nettype wire
