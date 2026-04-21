-- compiler generated IROM :D

library ieee;
use ieee.std_logic_1164.all;
use work.tensor.all;

entity IROM is
    port (
        ADDR    : in std_logic_vector(31 downto 0);
        Q       : out std_logic_vector(15 downto 0)
    );
end entity;

architecture MULTIPLEXER of IROM is
begin
  with ADDR select
      Q <= x"1300" when x"00000000",
	     x"1301" when x"00000001",
	     x"0100" when x"00000002",
	     x"1400" when others;
end architecture;
