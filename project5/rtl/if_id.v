`default_nettype none

module if_id (
    input  wire        i_clk,
    input  wire        i_rst,
    
    // Inputs from IF stage
    input  wire [31:0] i_pc,
    input  wire [31:0] i_instruction,
    input  wire [31:0] i_pc_plus_4,
    
    // Outputs to ID stage
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction,
    output reg  [31:0] o_pc_plus_4,
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= 32'h00000000;
            o_instruction <= 32'h00000013;
            o_pc_plus_4 <= 32'h00000000;
            o_trap <= 0;
        end else begin
            o_pc <= i_pc;
            o_instruction <= i_instruction;
            o_pc_plus_4 <= i_pc_plus_4;
            o_trap <= i_trap;
        end
    end

endmodule

`default_nettype wire