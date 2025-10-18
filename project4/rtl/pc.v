`default_nettype none
module pc (
    input  wire        i_clk,
    input  wire        i_rst,       // synchronous active-high reset (per dff.v)
    input  wire [31:0] i_next_pc,
    output wire [31:0] o_pc,
    output wire        o_retire_valid
);
    // 32-bit PC register: implemented as 32 one-bit DFF instances
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : g_pc
            dff u_pc_bit (
                .i_clk (i_clk),
                .i_rst (i_rst),          // reset to 0
                .i_d   (i_next_pc[i]),
                .o_q   (o_pc[i])
            );
        end
    endgenerate

    // retire_valid: resets to 0; after reset stays at 1 (single-cycle: one retire per cycle)
    dff u_retire_valid (
        .i_clk (i_clk),
        .i_rst (i_rst),
        .i_d   (1'b1),
        .o_q   (o_retire_valid)
    );
endmodule
`default_nettype wire