module branch_predict(
  input wire i_clk,
  input wire i_rst,
  input wire is_branch,
  input wire actual_taken,
  output reg mispredict,
  output reg flush_pipeline
);

  // simple start to a static always not taken branch predictor

  always @(posedge clk) begin
    if(i_rst) begin
      mispredict <= 0;
      flush_pipeline <= 0;
    end else begin
      // check if a branch instruction
      if(is_branch) begin
        // always predict not taken
        if(actual_taken) begin
          // misprediction
          mispredict <= 1;
          flush_pipeline <- 1;
        end else begin
          // correct prediction
          mispredict <= 0;
          flush_pipeline <= 0;
        end
      // not a branch isntruction
      end else begin
        mispredict <= 0;
        flush_pipeline <= 0;
  end

endmodule
