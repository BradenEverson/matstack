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
      Q <= x"1500" when x"00000000", -- .{ .cmd = .LOAD_CONST, .extra = 0 } 
	     x"1600" when x"00000001", -- .{ .cmd = .LOAD_I, .extra = 0 } 
	     x"1501" when x"00000002", -- .{ .cmd = .LOAD_CONST, .extra = 1 } 
	     x"1601" when x"00000003", -- .{ .cmd = .LOAD_I, .extra = 1 } 
	     x"1502" when x"00000004", -- .{ .cmd = .LOAD_CONST, .extra = 2 } 
	     x"1602" when x"00000005", -- .{ .cmd = .LOAD_I, .extra = 2 } 
	     x"1503" when x"00000006", -- .{ .cmd = .LOAD_CONST, .extra = 3 } 
	     x"1603" when x"00000007", -- .{ .cmd = .LOAD_I, .extra = 3 } 
	     x"1504" when x"00000008", -- .{ .cmd = .LOAD_CONST, .extra = 4 } 
	     x"1604" when x"00000009", -- .{ .cmd = .LOAD_I, .extra = 4 } 
	     x"1505" when x"0000000A", -- .{ .cmd = .LOAD_CONST, .extra = 5 } 
	     x"1605" when x"0000000B", -- .{ .cmd = .LOAD_I, .extra = 5 } 
	     x"1506" when x"0000000C", -- .{ .cmd = .LOAD_CONST, .extra = 6 } 
	     x"1606" when x"0000000D", -- .{ .cmd = .LOAD_I, .extra = 6 } 
	     x"1803" when x"0000000E", -- .{ .cmd = .STORE_I, .extra = 3 } 
	     x"1801" when x"0000000F", -- .{ .cmd = .STORE_I, .extra = 1 } 
	     x"0600" when x"00000010", -- .{ .cmd = .MATMUL, .extra = 0 } 
	     x"1805" when x"00000011", -- .{ .cmd = .STORE_I, .extra = 5 } 
	     x"0100" when x"00000012", -- .{ .cmd = .ADD, .extra = 0 } 
	     x"1607" when x"00000013", -- .{ .cmd = .LOAD_I, .extra = 7 } 
	     x"1807" when x"00000014", -- .{ .cmd = .STORE_I, .extra = 7 } 
	     x"0800" when x"00000015", -- .{ .cmd = .RELU, .extra = 0 } 
	     x"1608" when x"00000016", -- .{ .cmd = .LOAD_I, .extra = 8 } 
	     x"1804" when x"00000017", -- .{ .cmd = .STORE_I, .extra = 4 } 
	     x"1808" when x"00000018", -- .{ .cmd = .STORE_I, .extra = 8 } 
	     x"0600" when x"00000019", -- .{ .cmd = .MATMUL, .extra = 0 } 
	     x"1806" when x"0000001A", -- .{ .cmd = .STORE_I, .extra = 6 } 
	     x"0100" when x"0000001B", -- .{ .cmd = .ADD, .extra = 0 } 
	     x"1609" when x"0000001C", -- .{ .cmd = .LOAD_I, .extra = 9 } 
	     x"1802" when x"0000001D", -- .{ .cmd = .STORE_I, .extra = 2 } 
	     x"1809" when x"0000001E", -- .{ .cmd = .STORE_I, .extra = 9 } 
	     x"0300" when x"0000001F", -- .{ .cmd = .SUB, .extra = 0 } 
	     x"1507" when x"00000020", -- .{ .cmd = .LOAD_CONST, .extra = 7 } 
	     x"0E00" when x"00000021", -- .{ .cmd = .POW, .extra = 0 } 
	     x"1400" when x"00000022", -- .{ .cmd = .SUM, .extra = 0 } 
	     x"1507" when x"00000023", -- .{ .cmd = .LOAD_CONST, .extra = 7 } 
	     x"0500" when x"00000024", -- .{ .cmd = .DIV, .extra = 0 } 
	     x"160A" when x"00000025", -- .{ .cmd = .LOAD_I, .extra = 10 } 
	     x"1800" when x"00000026", -- .{ .cmd = .STORE_I, .extra = 0 } 
	     x"1803" when x"00000027", -- .{ .cmd = .STORE_I, .extra = 3 } 
	     x"1507" when x"00000028", -- .{ .cmd = .LOAD_CONST, .extra = 7 } 
	     x"0E00" when x"00000029", -- .{ .cmd = .POW, .extra = 0 } 
	     x"1400" when x"0000002A", -- .{ .cmd = .SUM, .extra = 0 } 
	     x"0400" when x"0000002B", -- .{ .cmd = .MUL, .extra = 0 } 
	     x"160B" when x"0000002C", -- .{ .cmd = .LOAD_I, .extra = 11 } 
	     x"1800" when x"0000002D", -- .{ .cmd = .STORE_I, .extra = 0 } 
	     x"1804" when x"0000002E", -- .{ .cmd = .STORE_I, .extra = 4 } 
	     x"1507" when x"0000002F", -- .{ .cmd = .LOAD_CONST, .extra = 7 } 
	     x"0E00" when x"00000030", -- .{ .cmd = .POW, .extra = 0 } 
	     x"1400" when x"00000031", -- .{ .cmd = .SUM, .extra = 0 } 
	     x"0400" when x"00000032", -- .{ .cmd = .MUL, .extra = 0 } 
	     x"160C" when x"00000033", -- .{ .cmd = .LOAD_I, .extra = 12 } 
	     x"180B" when x"00000034", -- .{ .cmd = .STORE_I, .extra = 11 } 
	     x"180C" when x"00000035", -- .{ .cmd = .STORE_I, .extra = 12 } 
	     x"0100" when x"00000036", -- .{ .cmd = .ADD, .extra = 0 } 
	     x"160D" when x"00000037", -- .{ .cmd = .LOAD_I, .extra = 13 } 
	     x"180A" when x"00000038", -- .{ .cmd = .STORE_I, .extra = 10 } 
	     x"180D" when x"00000039", -- .{ .cmd = .STORE_I, .extra = 13 } 
	     x"0100" when x"0000003A", -- .{ .cmd = .ADD, .extra = 0 } 
	     x"160E" when x"0000003B", -- .{ .cmd = .LOAD_I, .extra = 14 } 
	     x"180E" when x"0000003C", -- .{ .cmd = .STORE_I, .extra = 14 } 
	     x"1D00" when x"0000003D", -- .{ .cmd = .DEBUG_PRINT, .extra = 0 } 
	     x"1E00" when others; -- halt
end architecture;
