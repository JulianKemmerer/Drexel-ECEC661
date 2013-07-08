`timescale 1ns / 1ps

//Main stack cpu module
module stack_cpu
(
	clk, //Clock signal
	inst, //Full instruction vector
	inst_complete, //Signal that instruction has completed
	inst_ready, //High when inst is valid, begin fetch stage, must be forced low to invalidate
	pc_next //What the next PC value should be (supplied to instruction mem to provide next instruction)
);

//Want PC,SP, mem addr, mem data in, mem data out outputs?

//Define machine width
parameter CPU_BIT_WIDTH = 32;

//Few registers for the whole cpu
reg [CPU_BIT_WIDTH-1:0] pc_current;
reg COMPARE; //Global compare flag
reg [CPU_BIT_WIDTH-1:0] next_open_mem; //Next free location in data memory
reg [CPU_BIT_WIDTH-1:0] current_sframe_addr;

//Define inputs and outputs
input clk;
input [CPU_BIT_WIDTH-1:0] inst;
input inst_ready;
//Outputs
output inst_complete;
output [CPU_BIT_WIDTH-1:0] pc_next;

//Define input types
wire clk;
wire [CPU_BIT_WIDTH-1:0] inst;
wire inst_ready;
//Output types
reg inst_complete;
reg [CPU_BIT_WIDTH-1:0] pc_next;

//Main cpu states
parameter STATE_BITS = 2;
parameter IDLE_STATE=0;
parameter FETCH_STATE=1;
parameter EXECUTE_STATE=2;
parameter INSTRUCTION_INVALID=3; //Must go through instruction invalid state 
//to prove that a new instruction is present

//State registers
reg[STATE_BITS-1:0] current_state;
//reg[STATE_BITS-1:0] next_state;

//Function to give next state
function [STATE_BITS-1:0] get_next_state; input [STATE_BITS-1:0] state;
	//Fetch, next is execute
	if(state == FETCH_STATE) begin
		get_next_state = EXECUTE_STATE;
	end
	//Execute next invalid
	else if(state == EXECUTE_STATE) begin
		get_next_state = INSTRUCTION_INVALID;
	end
	//Invalid next is fetch
	else if(state == INSTRUCTION_INVALID) begin
		get_next_state = FETCH_STATE;
	end
	//Where are we?
	else begin
		get_next_state = IDLE_STATE;
	end
endfunction

//Initial state for simulation
initial begin
	//Start in fetch
	current_state = FETCH_STATE;
	//Start with 0 pc
	pc_current = 0;
	pc_next = 0;
	inst_complete = 1;
	next_open_mem = 0;
	current_sframe_addr = 0;
end

//Register to hold operand and constant during fetch stage
parameter OP_CODE_BITS = 5; //5 bit op codes
reg[OP_CODE_BITS-1:0] current_op_code;
parameter CONST_INST_BITS = CPU_BIT_WIDTH - OP_CODE_BITS; //27 bit constants possible
reg[CONST_INST_BITS-1:0] current_constant;

//Function to get op code from full instruction
function [OP_CODE_BITS-1:0] get_op_code; input [CPU_BIT_WIDTH-1:0] instr;
	//Return just the opcode from the instruction
	get_op_code = instr[CPU_BIT_WIDTH-1:CPU_BIT_WIDTH-OP_CODE_BITS];
endfunction

//Function to get op code from full instruction
function [CONST_INST_BITS-1:0] get_constant; input [CPU_BIT_WIDTH-1:0] instr;
	//Return just the opcode from the instruction
	get_constant = instr[CONST_INST_BITS-1:0];
endfunction

//Registers to interface with the stack
reg[CPU_BIT_WIDTH-1:0] stack_data_in;
wire[CPU_BIT_WIDTH-1:0] stack_data_out;
wire[CPU_BIT_WIDTH-1:0] stack_sp;
wire stack_full;
reg stack_reset;
reg stack_clk;
reg stack_push;
reg stack_pop;
//Stack instantiation
stack cpu_stack(
	.data_in(stack_data_in),
	.data_out(stack_data_out),
	.sp(stack_sp),
	.full(stack_full),
	.reset(stack_reset),
	.clk(clk), //Tie stack clk to cpu clock
	.push(stack_push),
	.pop(stack_pop)
);

//Tasks can including timing information - functions cannot
//Helper task to work with stack
task pop_stack; output [CPU_BIT_WIDTH-1:0] data;
begin
	//'Wait' for positive edge to trigger read
	@(posedge clk);
	//Set pop to high
	stack_pop = 1;
	stack_push = 0;
	$display("	CPU Internal: Stack pop: set read signals");
	//Wait for posedge again to do read inside stack, turn off pop signals
	@(posedge clk);
	stack_pop = 0;
	stack_push = 0;
	$display("	CPU Internal: Stack pop: output available, signals reset");
	//Wait for negative edge to actually read
	@(negedge clk);
	data = stack_data_out;
	$display("	CPU Internal: Stack pop: ouput value readt");
end
endtask

task push_stack; input [CPU_BIT_WIDTH-1:0] data;
begin
	//'Wait' for positive edge to trigger write
	@(posedge clk);
	//Set push to high
	stack_pop = 0;
	stack_push = 1;
	stack_data_in = data;
	$display("	CPU Internal: Stack push: set write signals");
	//Wait for next positive edge for write to go through
	@(posedge clk);
	stack_pop = 0;
	stack_push = 0;
	$display("	CPU Internal: Stack push: written, reset write signals");
	//Don't need to wait any longer since we don't need that value outside the stack
end
endtask

//Memory instantiation
//Registers to interface with the ram
reg ram_we;
reg[31 : 0] ram_addr;
reg[31 : 0] ram_data_in;
wire [31 : 0] ram_data_out;
//Stack instantiation
ram data_ram(
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
	$display("	CPU Internal: Ram read: set read signals");
	//Wait for posedge again to do read inside ram, default state is read so don't turn off
	@(posedge clk);
	$display("	CPU Internal: Ram read: output available, no signals to reset");
	//Wait for negative edge to actually read
	@(negedge clk);
	data = ram_data_out;
	$display("	CPU Internal: Ram read: ouput value read");
end
endtask

task write_ram; input [CPU_BIT_WIDTH-1:0] addr; input [CPU_BIT_WIDTH-1:0] data;
begin
	//Keep track of the largest used memory location
	//Assumes contiguous memory usage
	//Next open addr is one after largest used
	if( addr >= next_open_mem) begin
		next_open_mem = addr + 1;
	end

	//'Wait' for positive edge to trigger write
	@(posedge clk);
	//Set write to high and supply data,address
	//4 bit write enable
	ram_we = 4'b1111;
	ram_data_in = data;
	ram_addr = addr;
	$display("	CPU Internal: Ram write: set write signals");
	//Wait for next positive edge for write to go through, reset signals
	@(posedge clk);
	ram_we = 0;
	$display("	CPU Internal: Ram write: written, reset write signals");
	//Don't need to wait any longer since we don't need that value outside the ram
end
endtask


//Task to do the execution state
task do_execute_state; input [OP_CODE_BITS-1:0] op_code; input [CONST_INST_BITS-1:0] constant;
//Temp variables
reg[CPU_BIT_WIDTH-1:0] tmp0;
reg[CPU_BIT_WIDTH-1:0] tmp1;
reg[CPU_BIT_WIDTH-1:0] tmp2;
reg[CPU_BIT_WIDTH-1:0] tmp3;
reg[CPU_BIT_WIDTH-1:0] tmp4;

integer i;
begin
		//Choose which operation to run
		if(op_code == 1) begin
			//Stack constant
			//Auto zero pads to left
			push_stack(constant);
		end
		else if(op_code == 2) begin
			//Stack load
			//Pop stack for address, stack address contents
			pop_stack(tmp0); //Address in tmp0
			read_ram(tmp0,tmp1); //Contents in tmp1
			push_stack(tmp1); //Stack contents
		end
		else if(op_code == 3) begin
			//Stack store
			//Pop for address, pop for data, store data at address
			pop_stack(tmp0); //Address in tmp0
			pop_stack(tmp1); //Data in tmp1
			write_ram(tmp0,tmp1);
		end
		else if(op_code == 4) begin
			//Stack compare
			//Pop twice and compare ==
			pop_stack(tmp0);
			pop_stack(tmp1);
			if(tmp0 == tmp1) begin
				COMPARE = 1;
			end
			else begin
				COMPARE = 0;
			end
		end
		else if(op_code == 5) begin
			//Stack set less than
			//Pop twice and compare first pop < second pop
			pop_stack(tmp0);
			pop_stack(tmp1);
			if(tmp0 < tmp1) begin
				COMPARE = 1;
			end
			else begin
				COMPARE = 0;
			end
		end
		else if(op_code == 6) begin
			//Jump
			//Pop address, change PC to that value
			pop_stack(tmp0); //Address in tmp0
			//PC is always increments so do one less than address desired
			pc_current = tmp0 -1;
		end
		else if(op_code == 7) begin
			//Jump if compare zero
			pop_stack(tmp0); //Address in tmp0
			if(COMPARE ==0) begin
				//PC is always increments so do one less than address desired
				pc_current = tmp0 -1;
			end
		end
		else if(op_code == 8) begin
			//Jump if compare not zero
			pop_stack(tmp0); //Address in tmp0
			if(COMPARE !=0) begin
				//PC is always increments so do one less than address desired
				pc_current = tmp0 -1;
			end
		end
		else if(op_code == 9) begin
			//Subroutine call
			//User has pushed args,#args,jump addr onto stack
			//Now tmp0 gets jump addr
			pop_stack(tmp0);
			$display("scall jmp addr: %d", tmp0);
			//Then get the number of args
			pop_stack(tmp1);
			$display("scall #args: %d", tmp1);
			//Save next open mem in tmp
			//Cheap way of doing this is to push then pop the stack
			//Otherwise the ordering of instructions here is not consistent
			push_stack(next_open_mem);
			pop_stack(tmp2);
			//tmp2 = next_open_mem;
			//Starting at that location load the return address
			//Which is one after the current pc
			write_ram(tmp2, pc_current +1);
			$display("scall return addr: %d", pc_current +1);
			//Then the number of args
			write_ram(tmp2+1, tmp1);
			//Then each arg
			for( i=0; i < tmp1; i = i +1) begin
				//Pop the arg from the stack
				pop_stack(tmp3);
				$display("scall arg%d: %d",i, tmp3);
				//Put this arg in memory
				write_ram(tmp2+2 + i, tmp3);
			end
			//Finally
			//Push onto the stack the value of the stack frame start
			//which is the next free spot in memory we saved earlier
			push_stack(tmp2);
			$display("scall sframe addr: %d", tmp2);
			//Also save in globals
			current_sframe_addr = tmp2;
			//Then change the PC to the next jump address
			//PC is always increments so do one less than address desired
			pc_current = tmp0 -1;
		end
		else if(op_code == 10) begin
			//Subroutine return
			//This assumes everything else has been removed from the stack
			//that may have been created locally by the subroutine
			//except for the return value
			//Get the return value from the stack and put in tmp3
			pop_stack(tmp3);
			$display("srtn ret val: %d", tmp3);
			//Pop the stack frame address and store in tmp0
			pop_stack(tmp0);
			$display("srtn sframe addr: %d", tmp0);
			//Use this to store the return address in tmp1
			read_ram(tmp0, tmp1);
			$display("srtn return addr: %d", tmp1);
			//Then get the number of args and put in tmp2
			read_ram(tmp0+1,tmp2);
			$display("srtn #args: %d", tmp2);
			//Reset the next open mem to be this stack frame since we are done here
			//Cheap way of doing this is to push then pop the stack
			//Otherwise the ordering of instructions here is not consistent
			push_stack(tmp0);
			pop_stack(next_open_mem);
			//next_open_mem = tmp0;
			$display("srtn new next open mem: %d", next_open_mem);		
			//And go to the return address
			//PC is always increments so do one less than address desired
			pc_current = tmp1 -1;
			//Pop the stack again to get the next stack frame addr
			//since we are done with this one now
			pop_stack(tmp4);
			current_sframe_addr = tmp4;
			$display("srtn new sframe addr: %d", tmp4);
		end
		else if(op_code == 11) begin
			//Stack load argument address
			//Use current_sframe_addr to get the argument address
			//Arguments start at 2 after the frame start so
			//Start + 2 gives first arg + constant for arg index
			//Put that on stack as address
			$display("slla local addr %d translate to global addr %d", constant, current_sframe_addr + 2 + constant);
			push_stack(current_sframe_addr + 2 + constant);
		end
		else if(op_code == 12) begin
			//Allocate
			//Not called with param
			//Allocate one space by pushing zeros
			//TODO?
			push_stack(0);
		end
		else if(op_code == 13) begin
			//Deallocate
			//Just pop and do nothing with value
			//TODO?
			pop_stack(tmp0);
		end
		else if(op_code == 14) begin
			//Stack load local address
			//Stack address of specified local variable
			//TODO			
		end
		else if(op_code == 15) begin
			//Add
			//Pop two operands, perform add, stack result
			pop_stack(tmp0);
			pop_stack(tmp1);
			$display("adding %d+%d",tmp0,tmp1);
			push_stack(tmp0 + tmp1);
		end
		else if(op_code == 16) begin
			//Subtract
			pop_stack(tmp0);//First
			pop_stack(tmp1); //Second
			$display("subtracting %d-%d",tmp0,tmp1);
			push_stack(tmp0 - tmp1);
		end
		else if(op_code == 17) begin
			//Multiply
			pop_stack(tmp0);
			pop_stack(tmp1);
			push_stack(tmp0 * tmp1);
		end
		else begin
			//Assume noop - do nothing
		end
end
endtask

//Always run at positive edge of clk
always @ (posedge clk) begin
	//State machine for fectch/decode and execute stages
	//Execute stage is variable length
	if(current_state == FETCH_STATE) begin
		//Only continue if a valid instruction exists
		if(inst_ready == 1) begin
			$display("CPU Internal: FETCH STATE - INST READY");
			//Get the operand and constant for this instruction
			current_op_code = get_op_code(inst);
			current_constant = get_constant(inst);
			
			//Go to next state
			current_state = get_next_state(current_state);
			
			//Fetch stage assume instruction not complete
			inst_complete = 0;
			
			//Next state is now current state
			pc_current = pc_next;
			$display("CPU Internal: Copy PC next to current: Current: %d, Next: %d",pc_current, pc_next);
		end
		else begin
			$display("CPU Internal: FETCH STATE - INSTR NOT READY");
		end
	end
	else if(current_state == EXECUTE_STATE) begin
		$display("CPU Internal: EXECUTE STATE");
		do_execute_state(current_op_code, current_constant);
		
		//Set next state
		current_state = get_next_state(current_state);
		
		//End of execute stage assume done now
		inst_complete = 1;
		
		//Increment PC (branching takes always increment into account)
		pc_next = pc_current + 1;
		$display("CPU Internal: Increment PC: Current: %d, Next: %d",pc_current, pc_next);
	end
	else if(current_state == INSTRUCTION_INVALID) begin
		//Must wait for instruction ready to go low
		//This signals that a new instruction is being prepared
		if(inst_ready == 0) begin
			$display("CPU Internal: INSTRUCTION INVALIDATED");
			//Go to next state
			current_state = get_next_state(current_state);
		end
		else begin
			//Not yet invalidated
			//Just wait
			$display("CPU Internal: INSTRUCTION NOT YET INVALIDATED - WAITING");
		end
	end
	else begin
		//IDLE state - do nothing
	end
end //End clk posedge always
endmodule




//General Notes
//Clock process
//Always means run whenever condition is true

//Always cannot drive wires only reg and integers
// <= to drive registers, parallel, non blocking
// = to drive int, sequential, blocking
//assign statements are permanent mappings (can do some logic too)
//Functions can return a value, tasks cannot
//Functions cannot have delay, tasks can
//Test benches are easier