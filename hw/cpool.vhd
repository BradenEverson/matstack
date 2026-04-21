-- compiler-generated constant pool!
library ieee;
use ieee.std_logic_1164.all;
use work.tensor.all;

entity CPOOL is
    port (
        CLK     : in  std_logic;
        EN      : in  std_logic;
        ADDR    : in  integer range 0 to CPOOL_SIZE - 1;
        DATA    : out tensor_t;
        VALID   : out std_logic
    );
end entity;

architecture ROM of CPOOL is
begin
    process(CLK)
    begin
        if rising_edge(CLK) then
            VALID <= '0';
            if EN = '1' then
                VALID <= '1';
                case ADDR is
		--ConstantPool[0]: shape={ 1 } data={ 1 }
		when 0 =>
			DATA.meta.n_dims <= 1;
			DATA.meta.n_elems <= 1;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (1,0,0,0);
			DATA.meta.strides <= (1,0,0,0);
			DATA.data(0) <= x"3F800000"; -- 1.00
			DATA.data(1 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[1]: shape={ 1 } data={ 2 }
		when 1 =>
			DATA.meta.n_dims <= 1;
			DATA.meta.n_elems <= 1;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (1,0,0,0);
			DATA.meta.strides <= (1,0,0,0);
			DATA.data(0) <= x"40000000"; -- 2.00
			DATA.data(1 to MAX_ELEMENTS - 1) <= (others => x"00000000");

                when others =>
                        DATA <= (
                            meta => (
                                shape   => (others => 0),
                                strides => (others => 0),
                                n_dims  => 0,
                                n_elems => 0,
                                offset  => 0
                            ),
                            data => (others => x"00000000")
                        );
                end case;
            end if;
        end if;
    end process;
end architecture;
