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
		--ConstantPool[0]: shape={ 1 } data={ 0.01 }
		when 0 =>
			DATA.meta.n_dims <= 1;
			DATA.meta.n_elems <= 1;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (1,0,0,0);
			DATA.meta.strides <= (1,0,0,0);
			DATA.data(0) <= x"3C23D70A"; -- 0.01
			DATA.data(1 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[1]: shape={ 2, 1 } data={ -10, 1 }
		when 1 =>
			DATA.meta.n_dims <= 2;
			DATA.meta.n_elems <= 2;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (2,1,0,0);
			DATA.meta.strides <= (1,1,0,0);
			DATA.data(0) <= x"C1200000"; -- -10.00
			DATA.data(1) <= x"3F800000"; -- 1.00
			DATA.data(2 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[2]: shape={ 2, 1 } data={ 10, 5 }
		when 2 =>
			DATA.meta.n_dims <= 2;
			DATA.meta.n_elems <= 2;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (2,1,0,0);
			DATA.meta.strides <= (1,1,0,0);
			DATA.data(0) <= x"41200000"; -- 10.00
			DATA.data(1) <= x"40A00000"; -- 5.00
			DATA.data(2 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[3]: shape={ 3, 2 } data={ 1, 0, 0, 1, 0, 0 }
		when 3 =>
			DATA.meta.n_dims <= 2;
			DATA.meta.n_elems <= 6;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (3,2,0,0);
			DATA.meta.strides <= (2,1,0,0);
			DATA.data(0) <= x"3F800000"; -- 1.00
			DATA.data(1) <= x"00000000"; -- 0.00
			DATA.data(2) <= x"00000000"; -- 0.00
			DATA.data(3) <= x"3F800000"; -- 1.00
			DATA.data(4) <= x"00000000"; -- 0.00
			DATA.data(5) <= x"00000000"; -- 0.00
			DATA.data(6 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[4]: shape={ 2, 3 } data={ 0, -1, 2, 1, 3, -5 }
		when 4 =>
			DATA.meta.n_dims <= 2;
			DATA.meta.n_elems <= 6;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (2,3,0,0);
			DATA.meta.strides <= (3,1,0,0);
			DATA.data(0) <= x"00000000"; -- 0.00
			DATA.data(1) <= x"BF800000"; -- -1.00
			DATA.data(2) <= x"40000000"; -- 2.00
			DATA.data(3) <= x"3F800000"; -- 1.00
			DATA.data(4) <= x"40400000"; -- 3.00
			DATA.data(5) <= x"C0A00000"; -- -5.00
			DATA.data(6 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[5]: shape={ 3, 1 } data={ 1, 2, 3 }
		when 5 =>
			DATA.meta.n_dims <= 2;
			DATA.meta.n_elems <= 3;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (3,1,0,0);
			DATA.meta.strides <= (1,1,0,0);
			DATA.data(0) <= x"3F800000"; -- 1.00
			DATA.data(1) <= x"40000000"; -- 2.00
			DATA.data(2) <= x"40400000"; -- 3.00
			DATA.data(3 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[6]: shape={ 2, 1 } data={ -10, 10 }
		when 6 =>
			DATA.meta.n_dims <= 2;
			DATA.meta.n_elems <= 2;
			DATA.meta.offset <= 0;
			DATA.meta.shape <= (2,1,0,0);
			DATA.meta.strides <= (1,1,0,0);
			DATA.data(0) <= x"C1200000"; -- -10.00
			DATA.data(1) <= x"41200000"; -- 10.00
			DATA.data(2 to MAX_ELEMENTS - 1) <= (others => x"00000000");

		--ConstantPool[7]: shape={ 1 } data={ 2 }
		when 7 =>
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
