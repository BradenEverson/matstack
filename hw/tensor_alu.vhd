-- The ALU!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tensor.all;
use work.instructions.all;

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

    type alu_state_t is (S_IDLE, S_ADD, S_DONE);
    signal state   : alu_state_t := S_IDLE;
    signal counter : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal result_reg : tensor_t;

begin
    DONE   <= '1' when state = S_DONE else '0';
    RESULT <= result_reg;

    process(CLK, RST)
        variable sum : unsigned(31 downto 0);
    begin
        if RST = '0' then
            state   <= S_IDLE;
            counter <= 0;

        elsif rising_edge(CLK) then
            case state is

                when S_IDLE =>
                    if START = '1' then
                        result_reg.meta <= A.meta;
                        counter <= 0;
                        case OP is
                            when INSTR_ADD => state <= S_ADD;
                            when others    => state <= S_IDLE;
                        end case;
                    end if;

                when S_ADD =>
                    sum := unsigned(A.data(counter)) + unsigned(B.data(counter));
                    result_reg.data(counter) <= std_logic_vector(sum);

                    if counter = A.meta.n_elems - 1 then
                        state   <= S_DONE;
                        counter <= 0;
                    else
                        counter <= counter + 1;
                    end if;

                when S_DONE =>
                    state <= S_IDLE;

            end case;
        end if;
    end process;

end architecture STRUCTURAL;
