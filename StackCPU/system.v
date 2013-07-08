`timescale 1ns / 1ps

module stack_system
(
	clk //Clock signal
	//That should be it
	//This system includes the main cpu, and a instruction memory (ram)
	//The main cpu includes a stack and data memory (ram)
);

//Signal to indicate instructions are being loaded (i.e. don't start executing yet)
reg loading_inst;

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
//Registers to interface with the instruction ram
reg ram_we;
reg[31 : 0] ram_addr;
reg[31 : 0] ram_data_in;
wire [31 : 0] ram_data_out;
//RAM instantiation
//Use same core gen part from cpu level
ram inst_ram(
  .clk(clk),
  .we(ram_we),
  .addr(ram_addr),
  .din(ram_data_in),
  .dout(ram_data_out)
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
	//Start off loading instructions
	loading_inst = 1;
end

//Main clock procedure
always @(posedge clk) begin
	if(loading_inst == 1) begin
		//Do instruction loading
write_ram(0,134217754);
write_ram(1,805306368);
write_ram(2,134217729);
write_ram(3,1342177280);
write_ram(4,134217730);
write_ram(5,1476395008);
write_ram(6,268435456);
write_ram(7,671088640);
write_ram(8,134217730);
write_ram(9,1073741824);
write_ram(10,134217729);
write_ram(11,1476395008);
write_ram(12,268435456);
write_ram(13,2147483648);
write_ram(14,134217729);
write_ram(15,134217732);
write_ram(16,1207959552);
write_ram(17,134217730);
write_ram(18,1476395008);
write_ram(19,268435456);
write_ram(20,2147483648);
write_ram(21,134217729);
write_ram(22,134217732);
write_ram(23,1207959552);
write_ram(24,2013265920);
write_ram(25,1342177280);
write_ram(26,134217732);
write_ram(27,134217729);
write_ram(28,134217732);
write_ram(29,1207959552);
		
		//End instruction loading
		loading_inst = 0;
	end
	else begin
		//Do normal operation
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
	end
end //End poseedge clk



endmodule
