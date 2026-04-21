-- The top level architecture!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tensor.all;
use work.instructions.all;

entity HW is
    port (
        CLK : in  std_logic;
        RST : in  std_logic;
        HALT : out std_logic;
		  curr_pc: out std_logic_vector(31 downto 0);
		  instr: out std_logic_vector(15 downto 0);
		  TENSOR_OUT: out std_logic_vector(31 downto 0)
    );
end entity;

architecture PIPELINE of HW is
    type state_t is (
        S_FETCH,
        S_DECODE,
        S_CPOOL_REQ,
        S_CPOOL_WAIT,
        S_STACK_PUSH,
        S_STACK_POP_A,
        S_STACK_POP_B,
        S_WAIT_POP_A,
        S_WAIT_POP_B,
        S_EXECUTE,
        S_WAIT_EXEC,
        S_WRITEBACK,
        S_WAIT_WB,
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
            A       => operand_a,
            B       => operand_b,
            START   => alu_start,
            RESULT  => alu_result,
            DONE    => alu_done
        );

    process(CLK, RST)
    begin
        if RST = '0' then
            state    <= S_FETCH;
            pc       <= (others => '0');
            stack_op <= "00";
            cpool_en <= '0';
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

                        when INSTR_ADD	=> -- TODO: all the ALU ops here
                            state <= S_STACK_POP_A;

                        when INSTR_DEBUG_PRINT => -- use as a halt for now
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
                        if opcode = INSTR_RELU then -- TODO include all unary ops here
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
                    if stack_ready = '1' then
                        stack_op <= "00";
                        state    <= S_FETCH;
                    end if;

                when S_HALT =>
                    null;

            end case;
        end if;
    end process;

    HALT <= '1' when state = S_HALT else '0';
	 
	 
	 curr_pc <= std_logic_vector(pc);
	 instr <= irom_q;
	 
	 TENSOR_OUT <= scratch_area(0).data(0);

end architecture PIPELINE;
