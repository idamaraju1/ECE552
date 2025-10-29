`default_nettype none
module pc #(
    parameter RESET_ADDR = 32'h00000000
)(
    input  wire        i_clk,
    input  wire        i_rst,       // synchronous active-high reset (per dff.v)
    input  wire [31:0] i_next_pc,
    output reg  [31:0] o_pc,
    output reg         o_retire_valid
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= RESET_ADDR;
            o_retire_valid <= 1'b1;
        end else begin
            o_pc <= i_next_pc;
            o_retire_valid <= 1'b1;
        end
    end
endmodule
`default_nettype wire