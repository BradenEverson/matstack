-- Stack-Like Structure backed by a Moore Machine

library ieee;
use ieee.std_logic_1164.all;
use work.tensor.all;

entity STACK is
    port (
        CLK   : in  std_logic;
        RST   : in  std_logic;

        -- 00: NOP
		  -- 01: PUSH
		  -- 10: POP
		  -- 11: PEEK
        OP    : in  std_logic_vector(1 downto 0);
        PUSH  : in  tensor_t;
        POP   : out tensor_t;

        READY : out std_logic;
        VALID : out std_logic;
        ERR   : out std_logic
    );
end entity STACK;

architecture MOORE of STACK is
    type stack_data_t is array(0 to STACK_SIZE - 1, 0 to MAX_ELEMENTS - 1)
        of std_logic_vector(31 downto 0);

    type stack_meta_t is array(0 to STACK_SIZE - 1) of tensor_meta_t;

    type state_t is (
        IDLE,
        PUSHING,
        PUSH_DONE,
        POPPING,
        POP_DONE,
        FAULT
    );

    signal state    : state_t := IDLE;
    signal sp       : integer range 0 to STACK_SIZE := 0;
    signal stack_data : stack_data_t;
    signal stack_meta : stack_meta_t;
    signal elem_idx : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal copy_count : integer range 0 to MAX_ELEMENTS := 0;
	 
    signal latch_meta : tensor_meta_t;
    signal latch_data : tensor_data_t;

begin
    process(CLK, RST)
    begin
        if RST = '0' then
            state    <= IDLE;
            sp       <= 0;
            elem_idx <= 0;

        elsif rising_edge(CLK) then
            case state is
                when IDLE =>
                    case OP is

                        when "01" =>
                            if sp < STACK_SIZE then
                                stack_meta(sp) <= PUSH.meta;
                                copy_count     <= PUSH.meta.n_elems;
                                elem_idx       <= 0;
                                state          <= PUSHING;
                            else
                                state <= FAULT;
                            end if;

                        when "10" =>
                            if sp > 0 then
                                latch_meta <= stack_meta(sp - 1);
                                copy_count <= stack_meta(sp - 1).n_elems;
                                elem_idx   <= 0;
                                state      <= POPPING;
                            else
                                state <= FAULT;
                            end if;

                        when "11" =>
                            if sp > 0 then
                                latch_meta <= stack_meta(sp - 1);
                                copy_count <= stack_meta(sp - 1).n_elems;
                                elem_idx   <= 0;
                                state      <= POPPING;
                            else
                                state <= FAULT;
                            end if;

                        when others =>
                            null;

                    end case;
                when PUSHING =>
                    stack_data(sp, elem_idx) <= PUSH.data(elem_idx);

                    if elem_idx = copy_count - 1 then
                        state <= PUSH_DONE;
                    else
                        elem_idx <= elem_idx + 1;
                    end if;
                when PUSH_DONE =>
                    sp    <= sp + 1;
                    state <= IDLE;
                when POPPING =>
                    if elem_idx = copy_count then
                        if OP = "11" then
                            state <= POP_DONE;
                        else
                            sp    <= sp - 1;
                            state <= POP_DONE;
                        end if;
                    else
                        elem_idx <= elem_idx + 1;
                    end if;
						  
                when POP_DONE =>
                    state <= IDLE;

                when FAULT =>
                    null;

            end case;
        end if;
    end process;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if state = POPPING then
                latch_data(elem_idx) <= stack_data(sp - 1, elem_idx);
            end if;
        end if;
    end process;

    process(state, latch_meta, latch_data)
    begin
        READY        <= '0';
        VALID        <= '0';
        ERR          <= '0';
        POP.meta     <= latch_meta;
        POP.data     <= latch_data;

        case state is
            when IDLE       => READY <= '1';
            when PUSHING    => null;
            when PUSH_DONE  => READY <= '1';
            when POPPING    => null;
            when POP_DONE   => VALID <= '1';
            when FAULT      => ERR   <= '1';
        end case;
    end process;

end architecture MOORE;
