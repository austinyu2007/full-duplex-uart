`timescale 1ns/1ps

module testbench ();

  //Seed to generate random uart byte package
  int seed = 32159874343190;
  
  logic clk = 1'b0;
  logic reset;
  
  logic rx_in0; //uart 0 rx
  logic tx_needed0;
  logic [7:0] databus_in0;
  logic [7:0] databus_out0;
  logic zero_to_one; //the line from uart 0 tx to uart 1 rx (aka uart 0 tx)
  logic rx_available0;
  logic rx_error0;
  
  logic rx_in1; //uart 1 rx
  logic tx_needed1;
  logic [7:0] databus_in1;
  logic [7:0] databus_out1;
  logic one_to_zero; //(the line from uart 1 tx to uart 1 rx (aka uart 1 tx)
  logic rx_available1;
  logic rx_error1;
  
  //Instantiate two uarts
  uart uart0
  (
    .clk(clk),
    .reset(reset),
    
    .rx_in(one_to_zero),
    .other_rx_available(rx_available1),
    .tx_needed(tx_needed0),
    .databus_in(databus_in0),
    .databus_out(databus_out0),
    .tx_out(zero_to_one),
    .rx_available(rx_available0),
    .rx_error(rx_error0)
  );
  
  uart uart1
  (
    .clk(clk),
    .reset(reset),
    
    .rx_in(zero_to_one),
    .other_rx_available(rx_available0),
    .tx_needed(tx_needed1),
    .databus_in(databus_in1),
    .databus_out(databus_out1),
    .tx_out(one_to_zero),
    .rx_available(rx_available1),
    .rx_error(rx_error1)
  );
  
  //clock
  initial begin
    forever #5 begin
      clk = ~clk;
    end
  end
  
  initial begin
    $urandom(seed);
    reset <= 1'b1; //reset everything for fresh slate
    #50; //Wait for reset to clear everything
    reset <= 1'b0;
    
    databus_in0 = $urandom_range(0, 63); //The byte that uart0 will send to uart1
    databus_in1 = $urandom_range(0, 63); //The byte that uart1 will send to uart0
    tx_needed0 = 1'b1; //the outside device (aka the testbench) is telling uart0 that it has a packet to transmit
    tx_needed1 = 1'b1; //the outside device (aka the testbench) is telling uart1 that it has a packet to transmit
    
    
    #500;
    //Transmission done, no more tx needed
    tx_needed0 = 1'b0;
    tx_needed1 = 1'b0;
    
    //Wait for everything to transmit
    #1300;
    $display("DATABUS1 OUTPUT: %b		EXPECTED: %b", databus_out1, databus_in0);
    $display("DATABUS0 OUTPUT: %b		EXPECTED: %b", databus_out0, databus_in1);
    
    $display("");
    if (rx_error0 || rx_error1) begin
      $display("FAIL: either parity bit or stop bit error");
    end else begin
      $display("SUCCESS: no error detected");
    end
    $finish;
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, testbench);
  end
endmodule
