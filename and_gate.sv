module and_gate (and_vff vif);
  always @(posedge vif.clk)
    begin
      if (vif.rst == 1'b1)
        vif.y <= 0;
      else
        vif.y <= vif.a & vif.b; // Use non-blocking assignment for combinational logic
    end
endmodule
        
interface and_vff;
  logic clk;
  logic rst;
  logic a;
  logic b;
  logic y;
endinterface
