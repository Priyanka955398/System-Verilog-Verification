
module full_adder (fa_vff vif);
  always @(posedge vif.clk) begin
    if (vif.rst == 1'b1) begin
      vif.sum <= 0;
      vif.carry <= 0;
    end else begin
      vif.sum <= vif.a ^ vif.b ^ vif.c;
      vif.carry <= (vif.a & vif.b) | (vif.b & vif.c) | (vif.c & vif.a);
    end
  end
endmodule

        
interface fa_vff;
  logic clk;
  logic rst;
  logic a;
  logic b;
  logic c;
  logic sum;
  logic carry;
endinterface
