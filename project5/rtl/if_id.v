`default_nettype none

module if_id (
    input  wire        i_clk,
    
    // Inputs from IF stage
    input  wire [31:0] i_pc,
    input  wire [31:0] i_instruction,
    
    // Outputs to ID stage
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction
);

    always @(posedge i_clk) begin
        o_pc <= i_pc;
        o_instruction <= i_instruction;
    end

endmodule

`default_nettype wire