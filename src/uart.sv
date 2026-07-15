`timescale 1ns/1ps

module uart
  (
    input logic clk,
    input logic reset,
    
    input logic rx_in,
    input logic other_rx_available,
    input logic tx_needed,
    input logic [7:0] databus_in,
    
    output logic [7:0] databus_out,
    output logic tx_out,
    output logic rx_available,
    output logic rx_error
  );
  
  parameter BITS_PER_PACKET = 9; //Includes 8 data bits, 1 parity bit
  parameter BAUD_RATE = 11520000;
  parameter CLK_FRQ = 500000000;
  
  parameter cycles_per_bit = 4; //I am manually setting this to a very low cycles per bit becaues otherwise the waveforms would look too messy
  
  logic [8:0] current_rx_data; //Holds all the rx_data until it's ready to be sent to serial_out
  logic [13:0] baud_counter;
  logic [1:0] rx_state;
  logic [2:0] tx_state;
  logic [4:0] bits_received;
  logic [4:0] bits_sent;
  logic [7:0] tx_buffer;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      databus_out 		<= 'b0;
      tx_out 			<= 'b1;
      rx_available 		<= 'b1;
      rx_error 			<= 'b0;
      
      current_rx_data 	<= 'b0;
      baud_counter 		<= 'b0;
      rx_state 			<= 'b0;
      bits_received 	<= 'b0;
      bits_sent 		<= 'b0;
      tx_buffer 		<= 'b0;
    end else begin
      if (baud_counter == cycles_per_bit - 1) begin
        baud_counter <= '0;
        
        case (rx_state)
          2'b00: //IDLE
            begin
              if (rx_in == 1'b0) begin
                rx_error <= 1'b0;
                rx_state <= 2'b01;
                rx_available <= 1'b0;
                bits_received <= 'b0;
              end
            end
          2'b01: //LOAD
            begin
              if (bits_received < BITS_PER_PACKET) begin
                current_rx_data[bits_received] <= rx_in;
                bits_received <= bits_received + 1;
              end else begin
                rx_state <= 2'b10;
              end
            end
          2'b10: //DECODE
            begin
              if (^current_rx_data == 1) begin //EVEN PARITY
                rx_error <= 1'b1;
              end else if (rx_in == 1'b0) begin
                rx_error <= 1'b1;
              end
              
              rx_state <= 2'b11;
            end
          2'b11: //SEND TO DATABUS
            begin
              databus_out <= current_rx_data[7:0];
              rx_available <= 1'b1;
              rx_state <= 2'b00;
            end
        endcase
        
        
        case (tx_state)
          3'b000: //IDLE
            begin
              if (tx_needed == 1'b1 && other_rx_available == 1'b1) begin
                bits_sent <= 'b0;
                
                tx_out <= 1'b0;
                tx_state <= 3'b001;
                tx_buffer <= databus_in;
              end else begin
                tx_out <= 1'b1;
              end
            end
          
          3'b001: //SEND DATA BITS
            begin
              if (bits_sent < BITS_PER_PACKET - 1) begin //Subtract one because we will send parity bit in next cycle
                tx_out <= databus_in[bits_sent];
                bits_sent <= bits_sent + 1;
                
                if (bits_sent == BITS_PER_PACKET - 2) begin
                  tx_state <= 3'b010;
                end
              end
            end
          
          3'b010: //PARITY BIT
            begin
              tx_out <= ^databus_in;
              tx_state <= 3'b011;
            end
          
          3'b011: //STOP BIT
            begin
              tx_out <= 1'b1;
              tx_state <= 3'b100;
            end
          
          3'b100: //Rest
            begin
              tx_buffer <= 'b0;
              tx_state <= 3'b000;
            end
          
          default: //How did we get here?
            begin
              tx_state <= 3'b000;
            end
        endcase
      end else begin
        baud_counter <= baud_counter + 1;
      end
    end
  end
endmodule
