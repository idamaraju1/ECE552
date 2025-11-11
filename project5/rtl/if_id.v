`default_nettype none

module if_id (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_flush,         // 1 = flush (insert NOP)
    input  wire        i_stall,         // 1 = stall (hold current values)
    
    // Inputs from IF stage
    input  wire [31:0] i_pc,
    input  wire [31:0] i_instruction,
    input  wire [31:0] i_pc_plus_4,
    input  wire        i_valid,
    
    // Outputs to ID stage
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction,
    output reg  [31:0] o_pc_plus_4,
    output reg         o_valid
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= 32'h00000000;
            o_instruction <= 32'h00000013;
            o_pc_plus_4 <= 32'h00000004;
            o_valid <= 1'b0;
        end else if (i_flush) begin
            o_pc         <= 32'h00000000;
            o_instruction <= 32'h00000013;
            o_pc_plus_4  <= 32'h00000004;
            o_valid <= 1'b0;
        end else if (i_stall) begin
            // Hold current values when stalled
            o_pc         <= o_pc;
            o_instruction <= o_instruction;
            o_pc_plus_4  <= o_pc_plus_4;
            o_valid <= o_valid;
        end else begin
            o_pc         <= i_pc;
            o_instruction <= i_instruction;
            o_pc_plus_4  <= i_pc_plus_4;
            o_valid <= i_valid;
        end 
    end

endmodule

`default_nettype wire