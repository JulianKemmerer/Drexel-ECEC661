library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL;

--Entity from pdf (missing type_sel input, unneeded)
entity array_sorter is
  generic (N: natural:=4);
  port (
        x : in std_logic_vector(N-1 downto 0);
        z: out std_logic_vector(N-1 downto 0);
        reset, scan_mode, ck: in std_logic
        );
        --Number of elements to sort
        constant numElements:integer:=4;
        --Create a type which is an array of N bit values
        type mem_array is array(0 to numElements-1) of std_logic_vector(N-1 downto 0);
end array_sorter;

architecture behav of array_sorter is
  --Signal of mem_array type to store values
  signal mem:mem_array;
  signal stepType:integer;
  
begin
  CLKPROC:process(ck) --run on every clock change
    --Temp variables for comparison, store both binary and integer values
    variable val_int:integer; 
    variable val_right_int:integer;
    variable val_sig:std_logic_vector(N-1 downto 0);
    variable val_right_sig:std_logic_vector(N-1 downto 0);
    
  begin --begin description of process
    if ck = '1' and ck'event then --if rising edge of clock
      
      --If in reset mode
      if(reset = '1') then
        --Reset all values
        stepType <= 0;
        --Loop through memory to erase all values
        for i in 0 to numElements-1 loop
          mem(i) <= "0000";
        end loop;
      
     --else if in scan mode
      elsif(scan_mode = '1') then
        --Mimic shift register
        --Place old value on output
        z <= mem(numElements-1);
        --Start from the end and shift
        for i in numElements-2 downto 0 loop
          mem(i+1) <= mem(i);
        end loop;
        --Place new value in mem(0)
        mem(0)<=x;
        --Reset stepType (incase reset hasn't been run yet)
        stepType <= 0;
      
      else --Sort mode   
        --Loop through each element
        for i in 0 to numElements-1 loop
          --Depending on step type (1 or 0) this will select only even or odd indices
          if(i mod 2 = stepType) then
            --This will allow only alternating even and odd indices
            --Compare value at iterator to value at right
            --Get value at iterator (always valid)
            val_sig := mem(i);
            val_int := to_integer(unsigned(mem(i)));
            --Get value to right (not always valid)
            --If this is the last element in array then there is no right
            if(i = (numElements-1) ) then
              --Assign maximum values for imaginary right value
              val_right_sig := (others => '1'); --All ones in binary
              val_right_int := to_integer(unsigned(val_right_sig)); --Value of that assigned above
            else
              --If not then use the value that does exist to the right
              val_right_sig := mem(i+1);
              val_right_int := to_integer(unsigned(mem(i+1)));
            end if;
            
            --Compare the values
            --If value to right is less than current val, swap
            if(val_right_int < val_int) then
              mem(i) <= val_right_sig;
              mem(i+1) <= val_sig;
            end if; --End even or odd index if
          end if; --End stepType if
          
          --Toggle stepType
          if(stepType = 0) then
            stepType <= 1;
          else
            stepType <= 0;
          end if; --End toggle if
          
        end loop; --End loop through elements
        
      end if; --End mode select if
      
    end if; --End the clock event if
    
  end process CLKPROC; --End the clock process  
  
end architecture behav; --End arch
