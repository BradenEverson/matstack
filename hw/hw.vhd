-- The top level architecture!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tensor.all;

entity HW is
    port (
        CLK : in std_logic;
        RST : in std_logic;
		SEL : in std_logic_vector(6 downto 0);
		TENSOR: out std_logic_vector(31 downto 0)
    );
end entity;

architecture STRUCTURAL of HW is

    signal stack_op      : std_logic_vector(1 downto 0) := "00";
    signal stack_push_in : tensor_t;
    signal stack_pop_out : tensor_t;
    signal stack_ready   : std_logic;
    signal stack_valid   : std_logic;
    signal stack_err     : std_logic;
	 
	signal cpool_tensor	 : tensor_t;
	signal cpool_valid 	 : std_logic;
	signal en : std_logic;
	 
begin
	CPOOL: entity work.CPOOL
		port map (
		  CLK	=> CLK,
		  EN	=> RST,
          ADDR => to_integer(unsigned(sel)),
          DATA => cpool_tensor,
          VALID => cpool_valid
		);

	U_STACK : entity work.STACK
	  port map (
			CLK     => CLK,
			RST     => RST,
			OP      => stack_op,
			PUSH => stack_push_in,
			POP => stack_pop_out,
			READY   => stack_ready,
			VALID   => stack_valid,
			ERR     => stack_err
	  );
	  
	  
    TENSOR <= cpool_tensor.data(0);
end architecture;
