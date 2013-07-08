`timescale 1ns / 1ps

module ram
(
	clk,
	we,
	addr,
	din,
	dout
);

parameter CPU_BIT_WIDTH = 32;

//Inputs
input clk;
input we;
input [CPU_BIT_WIDTH-1:0] addr;
input [CPU_BIT_WIDTH-1:0] din;

//Outputs
output [CPU_BIT_WIDTH-1:0] dout;

//Input wires
wire clk;
wire we;
wire [CPU_BIT_WIDTH-1:0] addr;
wire [CPU_BIT_WIDTH-1:0] din;

//Output registers
reg [CPU_BIT_WIDTH-1:0] dout;

//Registers to hold the actual data
//Maximum number of 'elements' in simulation is 65536  = 2^16
//Use 8 bits for address space = 256
parameter addr_bits=8;
parameter addr_max=255;
reg[CPU_BIT_WIDTH-1:0] mem[addr_max:0];


//Main process
always @ (posedge clk) begin
	//Check read or write
	if(we == 1) begin
		//Write in mem at address
		mem[addr] = din;
	end
	else if(we ==0) begin
		//Read from memory
		dout = mem[addr];
	end
	else begin
		//Do nothing
	end
end
endmodule



