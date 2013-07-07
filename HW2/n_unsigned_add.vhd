library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

--Generic N bit entity
entity n_unsigned_add is
  generic (N: natural:=4); --Number of bits
  port (
        x1 : in std_logic_vector(N-1 downto 0);
        x2 : in std_logic_vector(N-1 downto 0);
        --A max of N+1 bits are needed to represent two N bit addition
        --Make the output just N bits so that we can have an overflow flag (the N+1 bit)
        z: out std_logic_vector(N-1 downto 0);  
        overflow : out std_logic;     
        ck: in std_logic
        );
end n_unsigned_add;


architecture behav of n_unsigned_add is
begin
  process(ck) --Run on every ck change
    --Temp variables
    variable x1_int:integer;
    variable x2_int:integer;
    variable z_int:integer;
    --Extra bit for overflow
    variable z_sig:std_logic_vector(N downto 0);
    
  begin
    --Run on rising edge
    if(ck='1' and ck'event) then
      --Convert the inputs to integers
      x1_int:= to_integer(unsigned(x1));
      x2_int:= to_integer(unsigned(x2));
      
      --Do the addition
      z_int:= x1_int+x2_int;
      
      --Convert z_int to N+1 bit vector 
      z_sig := std_logic_vector(to_unsigned(z_int, z_sig'length));
      
      --If the fifth bit is high then overflow
      if(z_sig(N) = '1') then
        overflow <='1';
      else
        overflow <='0';
      end if;
      
      --Make the Z output just the first N bits
      z <= z_sig(N-1 downto 0);
      
    end if;
  end process;
end architecture behav;

