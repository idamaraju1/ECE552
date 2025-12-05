`default_nettype none
module dff (
    input  wire i_clk, // Global clock
    input  wire i_rst, // Synchronous active-high reset
    input  wire i_d,
    output reg  o_q
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_q <= 1'b0;
        end else begin
            o_q <= i_d;
        end
    end
endmodule
`default_nettype wire