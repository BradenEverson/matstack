-- Stack-Like Structure backed by a Moore Machine

library ieee;
use ieee.std_logic_1164.all;
use work.tensor.all;

entity STACK is
port(	CLK: 	 in std_logic;
		RST: 	 in std_logic;
		
		-- 00: do nothing
		-- 01: push
		-- 10: pop
		-- 11: peek
		OP: 	 in std_logic_vector(1 downto 0);

		PUSH:	 in tensor_t;
		POP:	 out tensor_t;
		
		READY: out std_logic;
		VALID: out std_logic;
		ERR: 	 out std_logic); 
end entity STACK;

architecture MOORE of STACK is
	type stack_t is array(0 to STACK_SIZE-1) of tensor_t;
	type state_t is (IDLE, PUSHING, PUSH_DONE, POPPING, POP_DONE, FAULT);
			
	signal stack: stack_t;
	signal sp: integer range 0 to STACK_SIZE := 0;
	signal latch: tensor_t;		
	signal state: state_t := IDLE;
begin
	process(CLK, RST)

	begin
		if RST = '0' then
			state <= IDLE;
			sp <= 0;
		elsif rising_edge(CLK) then
			case state is	
				when IDLE =>
					  case OP is
							when "01" =>
								 if sp < STACK_SIZE then
									  stack(sp) <= PUSH;
									  state     <= PUSHING;
								 else
									  state <= FAULT;
								 end if;

							when "10" =>
								 if sp > 0 then
									  latch <= stack(sp - 1);
									  state <= POPPING;
								 else
									  state <= FAULT;
								 end if;

							when "11" =>
								 if sp > 0 then
									  latch <= stack(sp - 1);
									  state <= POP_DONE;
								 else
									  state <= FAULT;
								 end if;

							when others =>
								 null;
					  end case;

				 when PUSHING =>
					  sp    <= sp + 1;
					  state <= PUSH_DONE;

				 when PUSH_DONE =>
					  state <= IDLE;

				 when POPPING =>
					  sp    <= sp - 1;
					  state <= POP_DONE;

				 when POP_DONE =>
					  state <= IDLE;

				 when FAULT =>
					  null;
			end case;
		end if;
	end process;
	
	process(state, latch)
    begin
        READY <= '0';
        VALID <= '0';
        ERR <= '0';
        POP <= latch;

        case state is
            when IDLE       => READY <= '1';
            when PUSHING    => null;
            when PUSH_DONE  => READY <= '1';
            when POPPING    => null;
            when POP_DONE   => VALID <= '1';
            when FAULT      => ERR   <= '1';
        end case;
    end process;
end architecture;
