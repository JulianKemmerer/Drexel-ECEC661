`timescale 1ns / 1ps

//THIS FILE IS UNNEEDED
//INSTRUCTIONS WILL BE HANDED TO THE CPU VIA EDK SOFTWARE
//NOT STORED IN AN INSTRUCTION MEMORY

module stack_system
(
	clk //Clock signal
	//That should be it
	//This system includes the main cpu, and a instruction memory (ram)
	//The main cpu includes a stack and data memory (ram)
);

//Define machine width
parameter CPU_BIT_WIDTH = 32;

//Global signals
input clk; //Clk input
wire clk; //Wire input for clock

//Signals interface with the cpu
//Inputs to CPU, registers
reg [CPU_BIT_WIDTH-1:0] cpu_inst;
reg cpu_inst_ready;
//Outputs from CPU, wires
wire cpu_inst_complete;
wire [CPU_BIT_WIDTH-1:0] cpu_pc_next;
//CPU instantiation
stack_cpu CPU(
	.clk(clk), //Clock signal
	.inst(cpu_inst), //Full instruction vector
	.inst_complete(cpu_inst_complete), //Signal that instruction has completed
	.inst_ready(cpu_inst_ready), //High when inst is valid, begin fetch stage
	.pc_next(cpu_pc_next) //What the next PC value should be (supplied to instruction mem to provide next instruction)
);

//Memory instantiation
//Same as in main cpu
//Registers to interface with the ram
reg[3 : 0] ram_we;
reg[31 : 0] ram_addr;
reg[31 : 0] ram_data_in;
wire [31 : 0] ram_data_out;
//RAM instantiation
//Use same core gen part from cpu level
stack_cpu_ram cpu_inst_ram(
  .clka(clk),
  .wea(ram_we),
  .addra(ram_addr),
  .dina(ram_data_in),
  .douta(ram_data_out)
);

//Helper tasks to write/read from memory
task read_ram; input [CPU_BIT_WIDTH-1:0] addr; output [CPU_BIT_WIDTH-1:0] data;
begin
	//'Wait' for positive edge to trigger read
	@(posedge clk);
	//Set write enable low (read), and address bits
	ram_we = 0;
	ram_addr = addr;
	$display("	CPU External: Inst mem read: set read signals");
	//Wait for posedge again to do read inside ram, default state is read so don't turn off
	@(posedge clk);
	$display("	CPU External: Inst mem read: output available, no signals to reset");
	//Wait for negative edge to actually read
	@(negedge clk);
	data = ram_data_out;
	$display("	CPU External: Inst mem read: ouput value read");
end
endtask

task write_ram; input [CPU_BIT_WIDTH-1:0] addr; input [CPU_BIT_WIDTH-1:0] data;
begin
	//'Wait' for positive edge to trigger write
	@(posedge clk);
	//Set write to high and supply data,address
	//4 bit write enable
	ram_we = 4'b1111;
	ram_data_in = data;
	ram_addr = addr;
	$display("	CPU External: Inst mem write: set write signals");
	//Wait for next positive edge for write to go through, reset signals
	@(posedge clk);
	ram_we = 0;
	$display("	CPU External: Inst mem write: written, reset write signals");
	//Don't need to wait any longer since we don't need that value outside the ram
end
endtask


//Simulation initial conditions
initial begin
	cpu_inst = 0;
	cpu_inst_ready = 0;
	ram_we = 0;
	ram_addr = 0;
	ram_data_in = 0;
end

//Main clock procedure
always @ (posedge clk) begin
	//Wait for inst complete
	if(cpu_inst_complete == 1) begin
		$display("CPU External: Inst complete - read next instruction");
		//Load from memory into cpu_inst at PC address
		read_ram(cpu_pc_next,cpu_inst);
		
		//Set flag that instruction is ready
		cpu_inst_ready = 1;
	end
	else begin
		$display("CPU External: Inst not complete - waiting, do not read next instruction");
		//Inst not complete, so a new inst should not be ready
		cpu_inst_ready = 0;
	end
end //End poseedge clk



endmodule
