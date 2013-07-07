library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fifo2fifo is
--Two FIFOs, IN fifo and OUT fifo
PORT (
	 --Signals commmon to both fifos
	 clk_slow : IN STD_LOGIC; --switch based clock
	 clk_fast : IN STD_LOGIC; --Internal MHz clock
    rst : IN STD_LOGIC;
	 
	 --First fifo
	 --Just an input, output is internal
    din_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    
	 --Second fifo
	 --Input is internal output is external
    dout_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	 
	 --Mode for debugging
	 mode_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
  );
end fifo2fifo;


architecture Behavioral of fifo2fifo is
--Just one generated fifo entity
COMPONENT fifo_8w_16d
  PORT (
    clk : IN STD_LOGIC;
    rst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    data_count : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;

--Internal signals for first fifo
signal dout_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal full_in : STD_LOGIC;
signal empty_in : STD_LOGIC;
signal data_count_in : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal wr_en_in : STD_LOGIC;
signal rd_en_in : STD_LOGIC;
--Internal signals for second fifo
signal din_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal wr_en_out : STD_LOGIC;
signal rd_en_out : STD_LOGIC;
signal full_out : STD_LOGIC;
signal empty_out : STD_LOGIC;
signal data_count_out : STD_LOGIC_VECTOR(3 DOWNTO 0);

--Internal signals
--Signals for keeping track of physical clk switches
signal prev_clk_slow : STD_LOGIC;
 -- FIFO_IN read (slow) 0 , full transfer speed (fast) 1, FIFO_out read (slow) 2, 3 idle/complete
signal mode : natural := 0; 
signal bit_iterator: natural :=0; --Serial transfer iteration counter
--Flags to keep fifos in sync
signal fifo_in_output_ready : STD_LOGIC :='0';
signal fifo_out_input_ready : STD_LOGIC :='0';

--Begin architecture
begin
--The in fifo port mapped
FIFO_IN : fifo_8w_16d
  PORT MAP (
    clk => clk_fast,
    rst => rst,
    din => din_in,
    wr_en => wr_en_in,
    rd_en => rd_en_in,
    dout => dout_in,
    full => full_in,
    empty => empty_in,
    data_count => data_count_in
  );
--The out fifo port mapped, gets fast clock
FIFO_OUT : fifo_8w_16d
  PORT MAP (
    clk => clk_fast,
    rst => rst,
    din => din_out,
    wr_en => wr_en_out,
    rd_en => rd_en_out,
    dout => dout_out,
    full => full_out,
    empty => empty_out,
    data_count => data_count_out
  );
  
  
--Process for each fast clock cycle (internal)
fast_clk:process(clk_fast)
begin
--Only run on rising edge
if(rising_edge(clk_fast)) then
	--Change mode once depth of 4 has been reached
	if(data_count_in = "0100") then
		report "Mode changed to fast";
		mode <= 1;
		mode_out <= "01";
	elsif( data_count_out = "0100") then
	--Change back to slow 2 for reading fifo_out values
		mode <= 2;
		mode_out <= "10";
	elsif( mode = 2 and empty_out ='1') then
		--Coming from fifo_out read, now done, switch to idle
		mode <= 3;
		mode_out <= "11";
	end if;

	--Check what mode we are in
	if(mode = 0) then
		--Slow mode
		--Check for 'slow' clk of physical switches
		if(clk_slow = '1' and prev_clk_slow = '0') then
			--Rising edge of slow clock (and fast clk)
			report "Slow clk rising edge - Writing into first FIFO on next clock cycle";
			--Write data into the first fifo by enabling write
			wr_en_in <= '1';
			--Do not read from first fifo, disable read
			rd_en_in <= '0';
			--Do not read or write second fifo
			wr_en_out <= '0';
			rd_en_out <= '0';
			--Note the write into the fifo occurs on the next clock
		else
			--Not a rising edge of slow clock
			--Do not write or read from either fifo
			wr_en_in <= '0';
			rd_en_in <= '0';
			wr_en_out <= '0';
			rd_en_out <= '0';
		end if;
		
	elsif( mode = 2) then
		--Slow fifo_out mode
		--Check for 'slow' clk of physical switches
		if(clk_slow = '1' and prev_clk_slow = '0') then
			--Rising edge of slow clock (and fast clk)
			report "Slow clk rising edge - reading from fifo_out on next clock cycle";
			--Do not write data into the first fifo
			wr_en_in <= '0';
			--Do not write data into the second fifo
			wr_en_out <= '0';
			--Do not read from first fifo, disable read
			rd_en_in <= '0';
			--Read from the second fifo
			rd_en_out <= '1';
			--Note the write into the fifo occurs on the next clock
		else
			--Not a rising edge of slow clock
			--Do not write or read from either fifo
			wr_en_in <= '0';
			rd_en_in <= '0';
			wr_en_out <= '0';
			rd_en_out <= '0';
		end if;
		
	elsif( mode = 1) then
		report "Fast mode - rising edge using internal clock";
		
		--Check if ready to copy serially
		if(fifo_in_output_ready = '1') then
			report "fifo_in not read on this cycle but IS ready";
			--Fifo_in not read on this cycle
			fifo_in_output_ready <= '1';
			
			--If it wasn't read on this cycle then
			--it was read last cycle - ok to serial copy
			--Copy single bit over
			report "copy single bit";
			din_out(bit_iterator) <= dout_in(bit_iterator);
			--If this was the last bit to transfer
			if(bit_iterator >= 7) then
				--Reset count
				bit_iterator<=0;
				--Fifo out: input is now ready
				report "Serial copy complete, fifo_out input is ready";
				fifo_out_input_ready <= '1';
				report "Setting fifo_out to write next cycle";
				wr_en_out <= '1';
				rd_en_out <= '0';
				
				--Current fifo_in read value is no longer valid
				report "fifo_in ouput not ready, reading new val next cycle";
				fifo_in_output_ready <= '0';
				
				--Set to fifo_in read next time
				wr_en_in <= '0';
				rd_en_in <= '1';
			else
				--Just increment
				bit_iterator <= bit_iterator +1;
				report "Serial copy continues, fifo_out input is not ready";
				fifo_out_input_ready <= '0';
				--Set to fifo_in not read next time
				wr_en_in <= '0';
				rd_en_in <= '0';
			end if;
			
		elsif(wr_en_in = '0' and rd_en_in = '1') then
			report "fifo_in read on this cycle, ready for next cycle";
			--Fifo_in was read on this cycle
			fifo_in_output_ready <= '1';
			
			--Set not to read on next cycle
			wr_en_in <= '0';
			rd_en_in <= '0';
		else
			report "Fifo_in not read this cycle and not ready";
			--Not read this cycle and not ready
			--Set to ready next time
			--Set to fifo_in read next time
			report "Setting fifo_in to read next cycle";
			wr_en_in <= '0';
			rd_en_in <= '1';
		end if;
		
		
		
		--Manage fifo_out state
		if(fifo_out_input_ready = '1' and not(wr_en_out = '1' and rd_en_out = '0')) then
			report "fifo_out not written on this cycle but IS ready";
			--Fifo_out not read on this cycle
			fifo_out_input_ready <= '1';
			report "set fifo_out to write next cycle";
			wr_en_out <= '1';
			rd_en_out <= '0';
			
		elsif(wr_en_out = '1' and rd_en_out = '0') then
			report "fifo_out written on this cycle, do not write next cycle";
			--Set not to write on next cycle
			wr_en_out <= '0';
			rd_en_out <= '0';
			--Fifo_out was written on this cycle
			report "fifo_out mark input as not ready for next cycle";
			fifo_out_input_ready <= '0';
			
		else
			report "Fifo_out not written this cycle and not ready";
			--Fine, do nothing
		end if;
		
	else --Mode 3
		--Idle mode, do nothin
		wr_en_in <= '0';
		rd_en_in <= '0';
		wr_en_out <= '0';
		rd_en_out <= '0';
		
	end if;
	--Store current clk value as previous for next run
	prev_clk_slow <= clk_slow;
	
end if;
end process fast_clk;

--End architecture
end Behavioral;

