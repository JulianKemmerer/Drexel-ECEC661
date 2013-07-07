library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--Wrapper for around the ram4_16 entity
entity myram is
port (
	clka: IN std_logic;
	wea: IN std_logic_VECTOR(0 downto 0);
	addra: IN std_logic_VECTOR(3 downto 0);
	dina: IN std_logic_VECTOR(3 downto 0);
	douta: OUT std_logic_VECTOR(3 downto 0));
end myram;

--Architecture for wrapper
architecture Behavioral of myram is

--Component declaration
COMPONENT ram4_16
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;

begin

--Port map our wrapper to the IP core
u1 : ram4_16 port map 
(
		clka => clka,
		wea => wea,
		addra => addra,
		dina => dina,
		douta => douta		
);

end Behavioral;
