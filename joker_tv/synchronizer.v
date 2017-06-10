module synchronizer #(
  parameter NUM_STAGES = 2
) (
  output    sync_out,
  input     async_in,
  input     clk
);
 
  reg   [NUM_STAGES:1]    sync_reg;
 
  always @ (posedge clk) begin
    sync_reg <= {sync_reg[NUM_STAGES-1:1], async_in};
  end
 
  assign sync_out = sync_reg[NUM_STAGES];
 
endmodule
