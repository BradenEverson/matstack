-- The ALU!

library ieee;
use ieee.std_logic_1164.all;
use work.tensor.all;

entity TENSOR_ALU is
    port (
        CLK    : in  std_logic;
        RST    : in  std_logic;
        OP     : in  std_logic_vector(7 downto 0);
        A      : in  tensor_t;
        B      : in  tensor_t;
        START  : in  std_logic;
        RESULT : out tensor_t;
        DONE   : out std_logic
    );
end entity;

architecture STRUCTURAL of TENSOR_ALU is
begin
	
end architecture;
