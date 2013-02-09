`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:33:35 12/17/2012 
// Design Name: 
// Module Name:    SPI_Slave_SIM_v1_0 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module SPI_Slave_SIM_v1_0(clk2x, sck, mosi, miso, ssel, decPack, timeUs);//, ledReceived, rightComb, SSEL_active1);

	input clk2x;					// Input clock signal

	input sck, ssel, mosi;	// Input SPI signals
	
	input[31:0] decPack;		// input for receiving decoded data
	input[31:0] timeUs;		// timer for microsec
	
	output miso;

//	output ledReceived;		// TEST SIGNAL - LED on when package received
//	output rightComb;			// TEST SIGNAL If right combination for sending info has went then switch on LED
//	output SSEL_active1;		// TEST SIGNAL for detecting beginning of transmition

	reg  right = 1'b1;

	/*sync SCK to the FPGA clock using a 3-bits shift register*/
	reg [2:0] SCKr = 3'b000;  
	always @(negedge clk2x) 
		SCKr <= {SCKr[1:0], sck};
	wire SCK_risingedge = (SCKr[2:1]==2'b01);  	// for SCK rising edges
	wire SCK_fallingedge = (SCKr[2:1]==2'b10);  	// for SCK falling edges
	/***********************/

	/* same thing for SSEL */
	reg [2:0] SSELr = 3'b111;  
	always @(negedge clk2x) 
		SSELr <= {SSELr[1:0], ssel};
	wire SSEL_active = ~SSELr[1];  						// SSEL is active low
	wire SSEL_startmessage = (SSELr[2:1]==2'b10);  	// message starts at falling edge
	wire SSEL_endmessage = (SSELr[2:1]==2'b01); 	 	// message stops at rising edge
	
	assign SSEL_active1 = ~SSEL_active;
	/***********************/

	/*same thing for MOSI*/
	reg [1:0] MOSIr = 2'b00;  
	always @(negedge clk2x) 
		MOSIr <= {MOSIr[0], mosi};
	wire MOSI_data = MOSIr[1];
	/***********************/

	/*Receiving data from MOSI*/
	reg [2:0] bitcnt;

	reg byte_received;  								// high when a byte has been received
	reg [7:0] byte_data_received = 8'h0;

	always @(negedge clk2x)
	begin
	  if(~SSEL_active)
		 bitcnt <= 3'b000;
	  else if (SSEL_startmessage) 
		  bitcnt <= 3'b000;
	  else if(SCK_risingedge) 		// shifting received data with sck_risingedge
		  begin
			 bitcnt <= bitcnt + 3'b001;
			 byte_data_received <= {byte_data_received[6:0], MOSI_data}; 
		  end
	end

	/*Using the LSB of the data received to control an LED*/
	always @(negedge clk2x) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);
	
	reg byte_received1 = 1'b0;
	always @(negedge clk2x)
		if (byte_received)
			byte_received1 = ~byte_received1;
		
	
	reg byteRecShifted;  
	always @(negedge clk2x) byteRecShifted <= byte_received;
	
	reg LED = 1'b1;
	always @(negedge clk2x) 
		if(byte_received) 
			LED <= byte_data_received[0];
	/*****************************************************/


	/*Detecting if the correct byte for trancieving sequence has gone*/
	reg correctByte = 1'b0;
	
	always @(negedge clk2x) 
		if (SSEL_active == 1'b1) begin
			if (byte_received)
				if (byte_data_received == 8'hE0) begin
					correctByte <= 1'b1;
					right			<= 1'b0;	//for test with leds
				end 
		end
		else correctByte <= 1'b0;
	
	assign rightComb = right;
	
	/********************Transmittion Part******************************/
	reg [7:0] byte_data_sent = 8'b00000000;

	reg [3:0] cntBytes = 4'b0000;
	reg [7:0] cntPackages = 8'h0;
	
	reg [31:0] cntUS 			= 32'b11111111111111111111111111111111;
	reg [31:0] decodePack	= 32'b11111111111111111111111111111111;
	
	always @(negedge clk2x)
		if (correctByte  == 1'b1) begin
			if((SCK_risingedge) && (bitcnt[2:0] == 3'b111)) begin
				cntBytes <=		cntBytes + 1'b1; // count the bytes
				if (cntBytes == 4'b0111) begin
					cntPackages	<=	cntPackages+8'h1;  // count the full messages
					cntBytes 	<= 4'b0000;
				end
			end
		end

	
	/*Shifting to SPI*/
	always @(negedge clk2x) begin
		if (cntBytes == 4'b0000)
			if (byte_received) begin
				decodePack <= decPack;
				cntUS		  <= timeUs;
		end
		
		if (correctByte == 1'b1) begin						// if correct byte received
			if(SSEL_active)
			  if((SSEL_startmessage)||(SCK_fallingedge && bitcnt ==3'b000 ))
					if(cntBytes[2]) begin								// second part of 4 byte package
						byte_data_sent <= cntUS[31:24];  
						cntUS	<= {cntUS[23:0], 8'h00};
					end
					else begin												// first part of 4 byte package
						byte_data_sent <= decodePack[31:24];
						decodePack		<= {decodePack[23:0], 8'h00};
					end
					
			  if(SCK_fallingedge && bitcnt !=3'b000) begin
					byte_data_sent <= {byte_data_sent[6:0], 1'b0};
			  end
			  
		end
		else 															// if not correct byte received 
			byte_data_sent[7] <= 1'bz;
	end


	assign miso = byte_data_sent[7];  // send MSB first
	//need to tri-state MISO when SSEL is inactive if there are some others clients
	/*****************************/

assign ledReceived = byte_received1;

endmodule
