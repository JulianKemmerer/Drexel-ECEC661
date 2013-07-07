library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

--Generic N bit entity
entity n_signed_mult is
  generic (N: natural:=4); --Number of bits
  port (
        x1 : in std_logic_vector(N-1 downto 0);
        x2 : in std_logic_vector(N-1 downto 0);
        --Signed means only N-1 bits are used for the value
        --With N-1 bits, the maximum value is 2^(N-1) -1
        --The maximum result of multiplication is (2^(N-1)-1)^2
        --That maximum result requires log2( (2^(N-1)-1)^2 ) bits + 1 bit for signed
        z: out std_logic_vector(integer( ceil( log2( real( ((2**(N-1))-1)**2 ) ) ) ) downto 0);       
        ck: in std_logic
        );
end n_signed_mult;


architecture behav of n_signed_mult is
begin
  process(ck) --Run on every ck change
    --Temp variables
    variable x1_int:integer;
    variable x2_int:integer;
    variable z_int:integer;
    
  begin
    --Run on rising edge
    if(ck='1' and ck'event) then
      --Convert the inputs to integers
      x1_int:= to_integer(signed(x1));
      x2_int:= to_integer(signed(x2));
      
      --Do the multiplication
      z_int:= x1_int*x2_int;
      
      --Convert z_int to an output signal
      z <= std_logic_vector(to_signed(z_int, z'length));
    end if;
  end process;
end architecture behav;