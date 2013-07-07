library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

--Generic N bit entity
entity n_signed_add is
  generic (N: natural:=4); --Number of bits
  port (
        x1 : in std_logic_vector(N-1 downto 0);
        x2 : in std_logic_vector(N-1 downto 0);
        --Only N-1 bits are used for values
        --So a max of N-1 bits are needed to represent a signed add + 1 bit for sign
        z : out std_logic_vector(N-1 downto 0);  
        overflow : out std_logic;     
        ck : in std_logic
        );
end n_signed_add;


architecture behav of n_signed_add is
begin
  process(ck) --Run on every ck change
    --Temp variables
    variable x1_int:integer;
    variable x2_int:integer;
    variable z_int:integer;
    --Extra bit for overflow
    variable z_sig:std_logic_vector(N-1 downto 0);
    
  begin
    --Run on rising edge
    if(ck='1' and ck'event) then
      --Convert the inputs to integers
      x1_int:= to_integer(signed(x1));
      x2_int:= to_integer(signed(x2));
      
      --Do the addition
      z_int:= x1_int+x2_int;
      
      --Convert z_int to bit vector
      z_sig := std_logic_vector(to_signed(z_int, z_sig'length));
      
      --Determine if this is pos + pos, pos + neg , ...etc. 
      if(x1_int < 0) then
        if(x2_int <0) then
          --X2 is neg, X1 is neg
          --This result should be negative
          --If the N-1 bit is 0 then the result is positive meaning overflow
          if(z_sig(N-1) = '0') then
            overflow <= '1';
          else
            overflow <= '0';
          end if;
        else
          --X2 is pos, X1 is neg
          --No overflow can occur here
          overflow <= '0';
        end if;
      else
        if(x2_int <0) then
          --X2 is neg, X1 is pos
          --No overflow can occur here
          overflow <= '0';
        else
          --X2 is pos, X1 is pos
          --This result should be positive
          --If the N-1 bit is 1 then the result is negative meaning overflow
          if(z_sig(N-1) = '1') then
            overflow <= '1';
          else
            overflow <= '0';
          end if;
        end if;
      end if;
      
      --Make the Z output just part of the z_ig
      z <= z_sig(N-1 downto 0);  
    end if;
  end process;
end architecture behav;



