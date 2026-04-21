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
		  OP	: in std_logic_vector(1 downto 0);
		  TENSOR: out std_logic_vector(31 downto 0);
		  STACK_READY: out std_logic;
		  STACK_VALID: out std_logic;
		  STACK_ERR: out std_logic
    );
end entity;

architecture STRUCTURAL of HW is

    signal stack_push_in : tensor_t;
    signal stack_pop_out : tensor_t;
    signal sr   : std_logic;
    signal sv   : std_logic;
    signal se   : std_logic;

    signal cpool_tensor  : tensor_t;
    signal cpool_valid   : std_logic;

begin
    U_CPOOL : entity work.CPOOL
        port map (
            CLK   => CLK,
            EN    => '1',
            ADDR  => to_integer(unsigned(SEL)),
            DATA  => cpool_tensor,
            VALID => cpool_valid
        );

    U_STACK : entity work.STACK
        port map (
            CLK   => CLK,
            RST   => RST,
            OP    => OP,
            PUSH  => stack_push_in,
            POP   => stack_pop_out,
            READY => sr,
            VALID => sv,
            ERR   => se
        );

    stack_push_in <= cpool_tensor;

    TENSOR      <= stack_pop_out.data(0);
    STACK_READY <= sr;
    STACK_VALID <= sv;
    STACK_ERR   <= se;
end architecture;
