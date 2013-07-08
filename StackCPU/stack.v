`timescale 1ns / 1ps

module stack
(
	data_in, //Input data
	data_out, //Output data
	sp, //Address being read, top of stack, -1 if stack is empty
	reset, //Reset the stack
	clk, //Clock
	push, //Push input data onto stack
	pop, //Pop data off stack into data out
	full //Stack full flag
);

parameter CPU_BIT_WIDTH = 32;

input[CPU_BIT_WIDTH-1:0] data_in;
output[CPU_BIT_WIDTH-1:0] data_out;
output[CPU_BIT_WIDTH-1:0] sp;
output full;
input reset;
input clk;
input push;
input pop;

//Have the outputs registered
//Registers are used to store data
reg[CPU_BIT_WIDTH-1:0] data_out;
//Current stack pointer
reg[CPU_BIT_WIDTH-1:0] sp;
reg full;

//Initial state for simulation
initial begin
	data_out = 0;
	sp = -1;
	full = 0;
end

//Registers to hold the data
//Maximum number of 'elements' in simulation is 65536  = 2^16
//Use 8 bits for stack address space = 256
parameter stack_addr_bits=4;
parameter stack_addr_max=15;
reg[CPU_BIT_WIDTH-1:0] mem[stack_addr_max:0];
//Iterator
integer i = 0;

always @ (posedge clk) begin
	if(reset == 1) begin
		//Loop through memory and reset each line
		for(i=0; i<=stack_addr_max; i = i+1) begin
			//Set memory line to 32 bits of binary 000...
			mem[i] = 0;
		end
		//Reset data otu and sp
		data_out = 0;
		sp = -1;
	end 
	else if( (pop==1) && (push==1) ) begin
		//If popping and pushing, just put the input right on the output
		//Change nothing else
		data_out <= data_in;
	end
	else if( pop==1) begin
		//Just pop
		//Take the value at the current stack pointer and output it
		//Reduce the stack pointer by one
		//Stack pointer goes 'negative' which ends up being larger than max address
		if(sp > stack_addr_max) begin
			sp = -1;
			data_out <=  mem[0];
		end
		else begin
			sp <= sp -1;
			data_out <=  mem[sp];
		end
		
		//No longer full
		full <= 0;
	end
	else if( push==1) begin
		//Just push
		//If stack pointer is incremented in parallel
		//Increment sp
		if(sp==stack_addr_max) begin
			sp = stack_addr_max;
			mem[sp] <= data_in;
			full <= 1;
		end
		else begin
			sp <= sp +1;
			full <= 0;
		end
		//Is at zero place value there
		mem[sp+1] <= data_in;
	end
	else begin
		//Do nothing
	end
end//End clk process
endmodule


