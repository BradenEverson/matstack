-- The top level architecture!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tensor.all;
use work.instructions.all;

entity HW is
    port (
        CLK  : 	in  std_logic;
        RST  : 	in  std_logic;
        HALT : 	out std_logic;
		  SLIDERS: 	in std_logic_vector(9 downto 0);
		  SEG0 : 	out std_logic_vector(7 downto 0);
		  SEG1 : 	out std_logic_vector(7 downto 0);
		  SEG2 : 	out std_logic_vector(7 downto 0);
		  SEG3 : 	out std_logic_vector(7 downto 0);
		  SEG4 : 	out std_logic_vector(7 downto 0);
		  SEG5 : 	out std_logic_vector(7 downto 0);
		  LEDS : 	out std_logic_vector(9 downto 0);
		  
        curr_pc          : out std_logic_vector(31 downto 0);
        instr            : out std_logic_vector(15 downto 0);
        TENSOR_OUT       : out std_logic_vector(31 downto 0);
        ERR              : out std_logic;
        OP               : out std_logic_vector(1 downto 0);
        CONST_DATA       : out std_logic_vector(31 downto 0);
        STACK_READY_STATE: out std_logic
    );
end entity;

architecture PIPELINE of HW is
    type state_t is (
        S_FETCH,
        S_DECODE,
        S_CPOOL_REQ,
        S_CPOOL_WAIT,
        S_STACK_PUSH,
        S_STACK_PUSH_WAIT,
        S_STACK_POP_A,
        S_STACK_POP_B,
        S_WAIT_POP_A,
        S_WAIT_POP_B,
        S_EXECUTE,
        S_WAIT_EXEC,
        S_WRITEBACK,
        S_WAIT_WB,
        S_WAIT_WB_HOLD,
        S_LOAD_REG,
        S_STORE_REG,
        S_WAIT_STORE,
        S_HALT
    );

    signal state   : state_t := S_FETCH;
    signal pc      : unsigned(31 downto 0) := (others => '0');

    signal ir      : std_logic_vector(15 downto 0);
    signal opcode  : std_logic_vector(7 downto 0);
    signal operand : std_logic_vector(7 downto 0);

    signal irom_addr : std_logic_vector(31 downto 0);
    signal irom_q    : std_logic_vector(15 downto 0);

    signal cpool_en    : std_logic := '0';
    signal cpool_addr  : integer range 0 to CPOOL_SIZE - 1 := 0;
    signal cpool_data  : tensor_t;
    signal cpool_valid : std_logic;

    signal stack_op    : std_logic_vector(1 downto 0) := "00";
    signal stack_push  : tensor_t;
    signal stack_pop   : tensor_t;
    signal stack_ready : std_logic;
    signal stack_valid : std_logic;
    signal stack_err   : std_logic;

    type scratch_area_t is array(0 to SCRATCH_AREA) of tensor_t;
    signal scratch_area : scratch_area_t;

    signal operand_a : tensor_t;
    signal operand_b : tensor_t;

    signal alu_result  : tensor_t;
    signal alu_start   : std_logic := '0';
    signal alu_done    : std_logic;
	 signal tensor_out_reg : std_logic_vector(31 downto 0);

	 	 
	 signal scratch_tensor_0: std_logic_vector(31 downto 0);
begin

    irom_addr <= std_logic_vector(pc);

    U_IROM : entity work.IROM
        port map (ADDR => irom_addr, Q => irom_q);

    U_CPOOL : entity work.CPOOL
        port map (
            CLK   => CLK,
            EN    => cpool_en,
            ADDR  => cpool_addr,
            DATA  => cpool_data,
            VALID => cpool_valid
        );

    U_STACK : entity work.STACK
        port map (
            CLK   => CLK,
            RST   => RST,
            OP    => stack_op,
            PUSH  => stack_push,
            POP   => stack_pop,
            READY => stack_ready,
            VALID => stack_valid,
            ERR   => stack_err
        );

    U_ALU : entity work.TENSOR_ALU
        port map (
            CLK     => CLK,
            RST     => RST,
            OP      => opcode,
            A       => operand_b,
            B       => operand_a,
            START   => alu_start,
            RESULT  => alu_result,
            DONE    => alu_done
        );

    process(CLK, RST)
    begin
        if RST = '0' then
            state     <= S_FETCH;
            pc        <= (others => '0');
            stack_op  <= "00";
            cpool_en  <= '0';
            alu_start <= '0';

        elsif rising_edge(CLK) then
            stack_op  <= "00";
            cpool_en  <= '0';
            alu_start <= '0';

            case state is

                when S_FETCH =>
                    state <= S_DECODE;

                when S_DECODE =>
                    ir      <= irom_q;
                    opcode  <= irom_q(15 downto 8);
                    operand <= irom_q(7 downto 0);
                    pc      <= pc + 1;
                    state   <= S_FETCH;

                    case irom_q(15 downto 8) is

                        when INSTR_LOAD_CONST =>
                            state <= S_CPOOL_REQ;

                        when INSTR_LOAD_I =>
                            state <= S_STORE_REG;

                        when INSTR_STORE_I =>
                            state <= S_LOAD_REG;

                        when INSTR_ADD | INSTR_MUL | 
										INSTR_MATMUL | INSTR_POW |
										INSTR_RELU | INSTR_SUM =>
                            state <= S_STACK_POP_A;

                        when INSTR_DEBUG_PRINT =>
                            state <= S_HALT;

                        when others =>
                            state <= S_FETCH;

                    end case;

                when S_CPOOL_REQ =>
                    cpool_en   <= '1';
                    cpool_addr <= to_integer(unsigned(operand));
                    state      <= S_CPOOL_WAIT;

                when S_CPOOL_WAIT =>
                    cpool_en <= '1';
                    if cpool_valid = '1' then
                        stack_push <= cpool_data;
                        stack_op   <= "01";
                        state      <= S_STACK_PUSH;
                    end if;

                when S_STACK_PUSH =>
                    stack_op <= "01";
                    state    <= S_STACK_PUSH_WAIT;

                when S_STACK_PUSH_WAIT =>
                    if stack_ready = '1' then
                        stack_op <= "00";
                        state    <= S_FETCH;
                    end if;

                when S_STORE_REG =>
                    stack_op <= "10";
                    state    <= S_WAIT_STORE;

                when S_WAIT_STORE =>
                    stack_op <= "00";
                    if stack_valid = '1' then
                        scratch_area(to_integer(unsigned(operand))) <= stack_pop;
                        state <= S_FETCH;
                    end if;

                when S_LOAD_REG =>
                    stack_push <= scratch_area(to_integer(unsigned(operand)));
                    stack_op   <= "01";
                    state      <= S_STACK_PUSH;

                when S_STACK_POP_A =>
                    stack_op <= "10";
                    state    <= S_WAIT_POP_A;

                when S_WAIT_POP_A =>
                    stack_op <= "00";
                    if stack_valid = '1' then
                        operand_a <= stack_pop;
                        if opcode = INSTR_SUM then
									 operand_b <= stack_pop;
                            state <= S_EXECUTE;
                        else
                            state <= S_STACK_POP_B;
                        end if;
                    end if;

                when S_STACK_POP_B =>
                    stack_op <= "10";
                    state    <= S_WAIT_POP_B;

                when S_WAIT_POP_B =>
                    stack_op <= "00";
                    if stack_valid = '1' then
                        operand_b <= stack_pop;
                        state     <= S_EXECUTE;
                    end if;

                when S_EXECUTE =>
                    alu_start <= '1';
                    state     <= S_WAIT_EXEC;

                when S_WAIT_EXEC =>
                    if alu_done = '1' then
                        state <= S_WRITEBACK;
                    end if;

                when S_WRITEBACK =>
                    stack_push <= alu_result;
                    stack_op   <= "01";
                    state      <= S_WAIT_WB;

                when S_WAIT_WB =>
                    stack_op <= "01";
                    state    <= S_WAIT_WB_HOLD;

                when S_WAIT_WB_HOLD =>
                    if stack_ready = '1' then
                        stack_op <= "00";
                        state    <= S_FETCH;
                    end if;

                when S_HALT =>
						  tensor_out_reg <= scratch_area(to_integer(unsigned(SLIDERS(9 downto 5))))
														.data(to_integer(unsigned(SLIDERS(4 downto 0))));
            end case;
        end if;
    end process;

    HALT              <= '1' when state = S_HALT else '0';
    curr_pc           <= std_logic_vector(pc);
    instr             <= irom_q;
    OP                <= stack_op;
    ERR               <= stack_err;
    CONST_DATA        <= stack_push.data(0);
    STACK_READY_STATE <= stack_ready;

	 TENSOR_OUT <= tensor_out_reg;
	 
	 LEDS <= "0000000000";

	 process(tensor_out_reg)
	 begin
		 case tensor_out_reg(31 downto 28) is 
			  when "0000" => SEG5 <= "11000000"; -- 0
			  when "0001" => SEG5 <= "11111001"; -- 1
			  when "0010" => SEG5 <= "10100100"; -- 2
			  when "0011" => SEG5 <= "10110000"; -- 3
			  when "0100" => SEG5 <= "10011001"; -- 4
			  when "0101" => SEG5 <= "10010010"; -- 5
			  when "0110" => SEG5 <= "10000010"; -- 6
			  when "0111" => SEG5 <= "11111000"; -- 7
			  when "1000" => SEG5 <= "10000000"; -- 8
			  when "1001" => SEG5 <= "10010000"; -- 9
			  when "1010" => SEG5 <= "10001000"; -- A
			  when "1011" => SEG5 <= "10000011"; -- B
			  when "1100" => SEG5 <= "10100111"; -- C
			  when "1101" => SEG5 <= "10100001"; -- D
			  when "1110" => SEG5 <= "10000110"; -- E
			  when "1111" => SEG5 <= "10001110"; -- F		
			  when others => SEG5 <= "11111111"; -- blank
		 end case;

		 case tensor_out_reg(27 downto 24) is 
			  when "0000" => SEG4 <= "11000000"; -- 0
			  when "0001" => SEG4 <= "11111001"; -- 1
			  when "0010" => SEG4 <= "10100100"; -- 2
			  when "0011" => SEG4 <= "10110000"; -- 3
			  when "0100" => SEG4 <= "10011001"; -- 4
			  when "0101" => SEG4 <= "10010010"; -- 5
			  when "0110" => SEG4 <= "10000010"; -- 6
			  when "0111" => SEG4 <= "11111000"; -- 7
			  when "1000" => SEG4 <= "10000000"; -- 8
			  when "1001" => SEG4 <= "10010000"; -- 9
			  when "1010" => SEG4 <= "10001000"; -- A
			  when "1011" => SEG4 <= "10000011"; -- B
			  when "1100" => SEG4 <= "10100111"; -- C
			  when "1101" => SEG4 <= "10100001"; -- D
			  when "1110" => SEG4 <= "10000110"; -- E
			  when "1111" => SEG4 <= "10001110"; -- F		
			  when others => SEG4 <= "11111111"; -- blank
		 end case;

		 case tensor_out_reg(23 downto 20) is 
			  when "0000" => SEG3 <= "11000000"; -- 0
			  when "0001" => SEG3 <= "11111001"; -- 1
			  when "0010" => SEG3 <= "10100100"; -- 2
			  when "0011" => SEG3 <= "10110000"; -- 3
			  when "0100" => SEG3 <= "10011001"; -- 4
			  when "0101" => SEG3 <= "10010010"; -- 5
			  when "0110" => SEG3 <= "10000010"; -- 6
			  when "0111" => SEG3 <= "11111000"; -- 7
			  when "1000" => SEG3 <= "10000000"; -- 8
			  when "1001" => SEG3 <= "10010000"; -- 9
			  when "1010" => SEG3 <= "10001000"; -- A
			  when "1011" => SEG3 <= "10000011"; -- B
			  when "1100" => SEG3 <= "10100111"; -- C
			  when "1101" => SEG3 <= "10100001"; -- D
			  when "1110" => SEG3 <= "10000110"; -- E
			  when "1111" => SEG3 <= "10001110"; -- F		
			  when others => SEG3 <= "11111111"; -- blank
		 end case;

		 case tensor_out_reg(19 downto 16) is 
			  when "0000" => SEG2 <= "11000000"; -- 0
			  when "0001" => SEG2 <= "11111001"; -- 1
			  when "0010" => SEG2 <= "10100100"; -- 2
			  when "0011" => SEG2 <= "10110000"; -- 3
			  when "0100" => SEG2 <= "10011001"; -- 4
			  when "0101" => SEG2 <= "10010010"; -- 5
			  when "0110" => SEG2 <= "10000010"; -- 6
			  when "0111" => SEG2 <= "11111000"; -- 7
			  when "1000" => SEG2 <= "10000000"; -- 8
			  when "1001" => SEG2 <= "10010000"; -- 9
			  when "1010" => SEG2 <= "10001000"; -- A
			  when "1011" => SEG2 <= "10000011"; -- B
			  when "1100" => SEG2 <= "10100111"; -- C
			  when "1101" => SEG2 <= "10100001"; -- D
			  when "1110" => SEG2 <= "10000110"; -- E
			  when "1111" => SEG2 <= "10001110"; -- F		
			  when others => SEG2 <= "11111111"; -- blank
		 end case;

		 case tensor_out_reg(15 downto 12) is 
			  when "0000" => SEG1 <= "11000000"; -- 0
			  when "0001" => SEG1 <= "11111001"; -- 1
			  when "0010" => SEG1 <= "10100100"; -- 2
			  when "0011" => SEG1 <= "10110000"; -- 3
			  when "0100" => SEG1 <= "10011001"; -- 4
			  when "0101" => SEG1 <= "10010010"; -- 5
			  when "0110" => SEG1 <= "10000010"; -- 6
			  when "0111" => SEG1 <= "11111000"; -- 7
			  when "1000" => SEG1 <= "10000000"; -- 8
			  when "1001" => SEG1 <= "10010000"; -- 9
			  when "1010" => SEG1 <= "10001000"; -- A
			  when "1011" => SEG1 <= "10000011"; -- B
			  when "1100" => SEG1 <= "10100111"; -- C
			  when "1101" => SEG1 <= "10100001"; -- D
			  when "1110" => SEG1 <= "10000110"; -- E
			  when "1111" => SEG1 <= "10001110"; -- F		
			  when others => SEG1 <= "11111111"; -- blank
		 end case;

		 case tensor_out_reg(11 downto 8) is 
			  when "0000" => SEG0 <= "11000000"; -- 0
			  when "0001" => SEG0 <= "11111001"; -- 1
			  when "0010" => SEG0 <= "10100100"; -- 2
			  when "0011" => SEG0 <= "10110000"; -- 3
			  when "0100" => SEG0 <= "10011001"; -- 4
			  when "0101" => SEG0 <= "10010010"; -- 5
			  when "0110" => SEG0 <= "10000010"; -- 6
			  when "0111" => SEG0 <= "11111000"; -- 7
			  when "1000" => SEG0 <= "10000000"; -- 8
			  when "1001" => SEG0 <= "10010000"; -- 9
			  when "1010" => SEG0 <= "10001000"; -- A
			  when "1011" => SEG0 <= "10000011"; -- B
			  when "1100" => SEG0 <= "10100111"; -- C
			  when "1101" => SEG0 <= "10100001"; -- D
			  when "1110" => SEG0 <= "10000110"; -- E
			  when "1111" => SEG0 <= "10001110"; -- F		
			  when others => SEG0 <= "11111111"; -- blank
		 end case;
    end process;

end architecture PIPELINE;
