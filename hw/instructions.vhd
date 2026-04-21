-- compiler generated instruction constants. The opcode enum changes a lot so this is better than hardcoding :)
library ieee;
use ieee.std_logic_1164.all;
package INSTRUCTIONS is

	constant INSTR_NOP: std_logic_vector(7 downto 0) := x"00";
	constant INSTR_ADD: std_logic_vector(7 downto 0) := x"01";
	constant INSTR_INC: std_logic_vector(7 downto 0) := x"02";
	constant INSTR_SUB: std_logic_vector(7 downto 0) := x"03";
	constant INSTR_MUL: std_logic_vector(7 downto 0) := x"04";
	constant INSTR_DIV: std_logic_vector(7 downto 0) := x"05";
	constant INSTR_MATMUL: std_logic_vector(7 downto 0) := x"06";
	constant INSTR_TRANSPOSE: std_logic_vector(7 downto 0) := x"07";
	constant INSTR_RELU: std_logic_vector(7 downto 0) := x"08";
	constant INSTR_SOFTMAX: std_logic_vector(7 downto 0) := x"09";
	constant INSTR_CROSS_ENTROPY: std_logic_vector(7 downto 0) := x"0A";
	constant INSTR_DUP: std_logic_vector(7 downto 0) := x"0B";
	constant INSTR_SWAP: std_logic_vector(7 downto 0) := x"0C";
	constant INSTR_EXP: std_logic_vector(7 downto 0) := x"0D";
	constant INSTR_POW: std_logic_vector(7 downto 0) := x"0E";
	constant INSTR_LOG: std_logic_vector(7 downto 0) := x"0F";
	constant INSTR_ZEROS_LIKE: std_logic_vector(7 downto 0) := x"10";
	constant INSTR_SUM_REDUCE: std_logic_vector(7 downto 0) := x"11";
	constant INSTR_SUM: std_logic_vector(7 downto 0) := x"12";
	constant INSTR_LOAD_CONST: std_logic_vector(7 downto 0) := x"13";
	constant INSTR_LOAD_I: std_logic_vector(7 downto 0) := x"14";
	constant INSTR_CLONE_I: std_logic_vector(7 downto 0) := x"15";
	constant INSTR_STORE_I: std_logic_vector(7 downto 0) := x"16";
	constant INSTR_DROP: std_logic_vector(7 downto 0) := x"17";
	constant INSTR_BRANCH_ALWAYS: std_logic_vector(7 downto 0) := x"18";
	constant INSTR_BRANCH_EQ: std_logic_vector(7 downto 0) := x"19";
	constant INSTR_BRANCH_NE: std_logic_vector(7 downto 0) := x"1A";
	constant INSTR_DEBUG_PRINT: std_logic_vector(7 downto 0) := x"1B";

end package INSTRUCTIONS;
