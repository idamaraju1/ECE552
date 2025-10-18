`default_nettype none
module pc (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [31:0] i_next_pc,
    output wire [31:0] o_pc,
    output wire        o_retire_valid
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= 32'd0;
            o_retire_valid <= 1'b0;
        end else begin
            o_pc <= i_next_pc;
            o_retire_valid <= 1'b1;
        end
    end


endmodule

`default_nettype wire