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
	     x"1400" when x"00000001",
	     x"1301" when x"00000002",
	     x"1401" when x"00000003",
	     x"1302" when x"00000004",
	     x"1402" when x"00000005",
	     x"1303" when x"00000006",
	     x"1403" when x"00000007",
	     x"1304" when x"00000008",
	     x"1404" when x"00000009",
	     x"1305" when x"0000000A",
	     x"1405" when x"0000000B",
	     x"1306" when x"0000000C",
	     x"1406" when x"0000000D",
	     x"1603" when x"0000000E",
	     x"1601" when x"0000000F",
	     x"0600" when x"00000010",
	     x"1605" when x"00000011",
	     x"0100" when x"00000012",
	     x"1407" when x"00000013",
	     x"1607" when x"00000014",
	     x"0800" when x"00000015",
	     x"1408" when x"00000016",
	     x"1604" when x"00000017",
	     x"1608" when x"00000018",
	     x"0600" when x"00000019",
	     x"1606" when x"0000001A",
	     x"0100" when x"0000001B",
	     x"1409" when x"0000001C",
	     x"1602" when x"0000001D",
	     x"1609" when x"0000001E",
	     x"0300" when x"0000001F",
	     x"1307" when x"00000020",
	     x"0E00" when x"00000021",
	     x"1200" when x"00000022",
	     x"1307" when x"00000023",
	     x"0500" when x"00000024",
	     x"140A" when x"00000025",
	     x"1600" when x"00000026",
	     x"1603" when x"00000027",
	     x"1307" when x"00000028",
	     x"0E00" when x"00000029",
	     x"1200" when x"0000002A",
	     x"0400" when x"0000002B",
	     x"140B" when x"0000002C",
	     x"1600" when x"0000002D",
	     x"1604" when x"0000002E",
	     x"1307" when x"0000002F",
	     x"0E00" when x"00000030",
	     x"1200" when x"00000031",
	     x"0400" when x"00000032",
	     x"140C" when x"00000033",
	     x"160B" when x"00000034",
	     x"160C" when x"00000035",
	     x"0100" when x"00000036",
	     x"140D" when x"00000037",
	     x"160A" when x"00000038",
	     x"160D" when x"00000039",
	     x"0100" when x"0000003A",
	     x"140E" when x"0000003B",
	     x"160E" when x"0000003C",
	     x"1B00" when others;
end architecture;
