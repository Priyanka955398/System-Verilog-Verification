// Code your testbench here
// or browse Examples
class transaction;
  rand bit a,b;
  bit y;
  bit expy;
  
  function transaction copy();
    copy=new();
    copy.a=this.a;
    copy.b=this.b;
    copy.y=this.y;
  endfunction
  
  function void display(input string tag);
    $display("[%0s]: A :%0b : B :%0b : Y :%0b" ,tag,a,b,y);
  endfunction
endclass

class generator;
  transaction tr;
  mailbox # (transaction)mbx;
  mailbox # (transaction)mbxref;
  event sconext;
  event done;
  int count;
  
  function new(mailbox #(transaction)mbx, mailbox #(transaction)mbxref);
    this.mbx=mbx;
    this.mbxref=mbxref;
    tr=new();
  endfunction
  
  task run();
    repeat (count)begin
      assert(tr.randomize) else $error("[GEN] : RANDOMIZATION ERROR");
      mbx.put(tr.copy);
      mbxref.put(tr.copy);
      tr.display("GEN");
      @(sconext);
    end
    ->done;
  endtask
  
endclass

class driver;
  transaction tr;
  mailbox # (transaction)mbx;
  
  virtual and_vff vif;
  
  function new(mailbox # (transaction)mbx);
    this.mbx=mbx;
  endfunction
  
  task reset();
     vif.rst <= 1'b1; 
    repeat(5) @(posedge vif.clk); 
    vif.rst <= 1'b0; 
    @(posedge vif.clk); 
    $display("[DRV] : RESET DONE");
  endtask 
  
  task run();
    forever begin
       @(negedge vif.clk); 
      mbx.get(tr); // Get a transaction from the generator
      vif.a <= tr.a; // Set DUT input from the transaction
      vif.b <= tr.b; // Set DUT input from the transaction
     // Wait for the rising edge of the clock
      tr.display("DRV"); // Display transaction information
      //vif.a <= 1'b0;// Set DUT input to 0
      //vif.b <= 1'b0;
     // @(negedge vif.clk); // Wait for the rising edge of the clock
      $display("after drv disp");
    end
  endtask
  
endclass

class monitor;
  transaction tr; // Define a transaction object
  mailbox #(transaction) mbx; // Create a mailbox to send data to the scoreboard
  virtual and_vff vif; // Virtual interface for DUT
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx; // Initialize the mailbox for sending data to the scoreboard
  endfunction
  
  task run();
    tr = new(); // Create a new transaction
    $display("before mon disp");
    
      forever begin @(negedge vif.clk); // Wait for two rising edges of the clock
      tr.a= vif.a;
      tr.b= vif.b;
      tr.y = vif.y; // Capture DUT output
      mbx.put(tr); // Send the captured data to the scoreboard
      tr.display("MON"); 
      $display("after mon disp");
    end
  endtask
  
endclass
 
class scoreboard;
  transaction tr; // Define a transaction object
  transaction trref; // Define a reference transaction object for comparison
  mailbox #(transaction) mbx; // Create a mailbox to receive data from the monitor
  mailbox #(transaction) mbxref; // Create a mailbox to receive reference data from the generator
  event sconext; // Event to signal completion of scoreboard work
 
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx; // Initialize the mailbox for receiving data from the driver
    this.mbxref = mbxref; // Initialize the mailbox for receiving reference data from the generator
  endfunction
  
  task run();
    forever begin
      mbx.get(tr); // Get a transaction from the driver
      mbxref.get(trref);
         
      tr.display("SCO"); // Display the driver's transaction information
      trref.display("REF"); // Display the reference transacti// Get a reference transaction from the generator
      case({tr.a,tr.b})
        2'b00 : tr.expy=  0;
        2'b01 : tr.expy=  0;
        2'b10 : tr.expy=  0;
        2'b11 : tr.expy=  1;
      endcase
    
      if (tr.expy == tr.y)
        $display("[SCO] : DATA MATCHED"); // Compare data and display the result
      else
        $display("[SCO] : DATA MISMATCHED");
      $display("-------------------------------------------------");
      ->sconext; // Signal completion of scoreboard work
    end
  endtask
endclass
  
   
////////////////////////////////////////////////////////
 
class environment;
  generator gen; // Generator instance
  driver drv; // Driver instance
  monitor mon; // Monitor instance
  scoreboard sco; // Scoreboard instance
  event next; // Event to signal communication between generator and scoreboard
 
  mailbox #(transaction) gdmbx; // Mailbox for communication between generator and driver
  mailbox #(transaction) msmbx; // Mailbox for communication between monitor and scoreboard
  mailbox #(transaction) mbxref; // Mailbox for communication between generator and scoreboard

  virtual and_vff vif; // Virtual interface for DUT
 
  function new(virtual and_vff vif);
    gdmbx = new(); // Create a mailbox for generator-driver communication
    mbxref = new(); // Create a mailbox for generator-scoreboard reference data
    gen = new(gdmbx, mbxref); // Initialize the generator
    drv = new(gdmbx); // Initialize the driver
    msmbx = new(); // Create a mailbox for monitor-scoreboard communication
    mon = new(msmbx); // Initialize the monitor
    sco = new(msmbx, mbxref); // Initialize the scoreboard
    this.vif = vif; // Set the virtual interface for DUT
    drv.vif = this.vif; // Connect the virtual interface to the driver
    mon.vif = this.vif; // Connect the virtual interface to the monitor
    gen.sconext = next; // Set the communication event between generator and scoreboard
    sco.sconext = next; // Set the communication event between scoreboard and generator
  endfunction
  
  task pre_test();
    drv.reset(); // Perform the driver reset
  endtask
  
  task test();
    fork
      gen.run(); // Start generator
      drv.run(); // Start driver
      mon.run(); // Start monitor
      sco.run(); // Start scoreboard
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered); // Wait for generator to complete
    $finish(); // Finish simulation
  endtask
  
  task run();
    pre_test(); // Run pre-test setup
    test(); // Run the test
    post_test(); // Run post-test cleanup
  endtask
endclass
 
/////////////////////////////////////////////////////
 
  module tb();
    and_vff vif(); // Create DUT interface

    and_gate dut(vif); // Instantiate DUT

    initial begin
      vif.clk <= 0; // Initialize clock signal
    end

    always #10 vif.clk <= ~vif.clk; // Toggle the clock every 10 time units

    environment env; // Create environment instance

    initial begin
      env = new(vif); // Initialize the environment with the DUT interface
      env.gen.count = 10; // Set the generator's stimulus count
      env.run(); // Run the environment
    end

    initial begin
      $dumpfile("dump.vcd"); // Specify the VCD dump file
      $dumpvars; // Dump all variables
    end
  endmodule
  
  
       


  
  
