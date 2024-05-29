// Code your testbench here
// or browse Examples
class transaction;
  rand bit a,b,c;
  bit sum,carry;
  bit exp_sum,exp_carry;
  
  function transaction copy();
    copy=new();
    copy.a=this.a;
    copy.b=this.b;
    copy.c=this.c;
    copy.sum=this.sum;
    copy.carry=this.carry;
  endfunction
  
  function void display(input string tag);
    $display("[%0s]: A :%0b : B :%0b : C :%0b : SUM :%0b : CARRY :%0b " ,tag,a,b,c,sum,carry);
  endfunction
endclass

class generator;
  transaction tr;
  mailbox # (transaction)data_to_driver;
  mailbox # (transaction)data_to_scoreboard;
  event sconext;
  event done;
  int count;
  
  function new(mailbox #(transaction)data_to_driver, mailbox #(transaction)data_to_scoreboard);
    this.data_to_driver=data_to_driver;
    this.data_to_scoreboard=data_to_scoreboard;
    tr=new();
  endfunction
  
  task run();
    repeat (count)begin
      assert(tr.randomize) else $error("[GEN] : RANDOMIZATION ERROR");
      data_to_driver.put(tr.copy);
      data_to_scoreboard.put(tr.copy);
      tr.display("GEN");
      @(sconext);
    end
    ->done;
  endtask
  
endclass

class driver;
  transaction tr;
  mailbox # (transaction)data_to_driver;
  
  virtual fa_vff vif;
  
  function new(mailbox # (transaction)data_to_driver);
    this.data_to_driver=data_to_driver;
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
      data_to_driver.get(tr); // Get a transaction from the generator
      vif.a <= tr.a; // Set DUT input from the transaction
      vif.b <= tr.b;
      vif.c <= tr.c;// Set DUT input from the transaction
      @(negedge vif.clk); // Wait for the rising edge of the clock
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
  mailbox #(transaction) data_to_driver; // Create a mailbox to send data to the scoreboard
  virtual fa_vff vif; // Virtual interface for DUT
  
  function new(mailbox #(transaction) data_to_driver);
    this.data_to_driver = data_to_driver; // Initialize the mailbox for sending data to the scoreboard
  endfunction
  
  task run();
    tr = new(); // Create a new transaction
    $display("before mon disp");
    
      forever begin @(negedge vif.clk); // Wait for two rising edges of the clock
      tr.a= vif.a;
      tr.b= vif.b;
      tr.c= vif.c;
      tr.sum = vif.sum;
      tr.carry= vif.carry;// Capture DUT output
      data_to_driver.put(tr); 
        // Send the captured data to the scoreboard
      tr.display("MON"); 
      $display("after mon disp");
    end
  endtask
  
endclass
 
class scoreboard;
  transaction tr; // Define a transaction object
  transaction trref; // Define a reference transaction object for comparison
  mailbox #(transaction) data_to_driver; // Create a mailbox to receive data from the monitor
  mailbox #(transaction) data_to_scoreboard; // Create a mailbox to receive reference data from the generator
  event sconext; // Event to signal completion of scoreboard work
 
  function new(mailbox #(transaction) data_to_driver, mailbox #(transaction) data_to_scoreboard);
    this.data_to_driver = data_to_driver; // Initialize the mailbox for receiving data from the driver
    this.data_to_scoreboard = data_to_scoreboard; // Initialize the mailbox for receiving reference data from the generator
  endfunction
  
  task run();
    forever begin
      data_to_driver.get(tr); // Get a transaction from the driver
      data_to_scoreboard.get(trref);
         
      tr.display("SCO"); // Display the driver's transaction information
      trref.display("REF"); // Display the reference transacti// Get a reference transaction from the generator
      case({tr.a,tr.b,tr.c})
        3'b000 : begin tr.exp_sum= 0;tr.exp_carry= 0;end
        3'b001 : begin tr.exp_sum= 1;tr.exp_carry= 0;end
        3'b010 : begin tr.exp_sum= 1;tr.exp_carry= 0;end
        3'b011 : begin tr.exp_sum= 0;tr.exp_carry= 1;end
        3'b100 :  begin tr.exp_sum= 1;tr.exp_carry= 0;end
        3'b101 :  begin tr.exp_sum= 0;tr.exp_carry= 1;end
        3'b110 :  begin tr.exp_sum= 0;tr.exp_carry= 1;end
        3'b111 :  begin tr.exp_sum= 1;tr.exp_carry= 1;end
      endcase
    
      if ((tr.exp_sum == tr.sum) && (tr.exp_carry == tr.carry))
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
  mailbox #(transaction) data_to_scoreboard; // Mailbox for communication between generator and scoreboard

  virtual fa_vff vif; // Virtual interface for DUT
 
  function new(virtual fa_vff vif);
    gdmbx = new(); // Create a mailbox for generator-driver communication
    data_to_scoreboard = new(); // Create a mailbox for generator-scoreboard reference data
    gen = new(gdmbx, data_to_scoreboard); // Initialize the generator
    drv = new(gdmbx); // Initialize the driver
    msmbx = new(); // Create a mailbox for monitor-scoreboard communication
    mon = new(msmbx); // Initialize the monitor
    sco = new(msmbx, data_to_scoreboard); // Initialize the scoreboard
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
    fa_vff vif(); // Create DUT interface

    full_adder dut(vif); // Instantiate DUT

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
  
  
       
  
  							
