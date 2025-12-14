`default_nettype none
module pc #(
    parameter RESET_ADDR = 32'h00000000
)(
    input  wire        i_clk,
    input  wire        i_rst,       // synchronous active-high reset (per dff.v)
    input  wire        i_write,
    input  wire [31:0] i_next_pc,
    output reg  [31:0] o_pc
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= RESET_ADDR;
        end else if (i_write) begin
            o_pc <= i_next_pc;
        end
    end
endmodule
`default_nettype wire