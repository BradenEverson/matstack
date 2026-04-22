-- The ALU!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tensor.all;
use work.instructions.all;

library ieee_proposed;
use ieee_proposed.float_pkg.all;

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
    type alu_state_t is (
        S_IDLE,
        S_ADD,
        S_MUL,
        S_MATMUL,
        S_DONE
    );

    signal state      : alu_state_t := S_IDLE;
    signal counter    : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal result_reg : tensor_t;

    signal mm_i  : integer range 0 to 15 := 0;
    signal mm_j  : integer range 0 to 15 := 0;
    signal mm_ki : integer range 0 to 15 := 0;
    signal mm_M  : integer range 0 to 15 := 0;
    signal mm_K  : integer range 0 to 15 := 0;
    signal mm_N  : integer range 0 to 15 := 0;

    signal a_row_base : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal a_ptr      : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal b_col_base : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal b_ptr      : integer range 0 to MAX_ELEMENTS - 1 := 0;
    signal c_ptr      : integer range 0 to MAX_ELEMENTS - 1 := 0;

    signal mm_acc : float32;

begin
    DONE   <= '1' when state = S_DONE else '0';
    RESULT <= result_reg;

    process(CLK, RST)
        variable f_a, f_b, f_res : float32;
        variable f_prod          : float32;
    begin
        if RST = '0' then
            state      <= S_IDLE;
            counter    <= 0;
        elsif rising_edge(CLK) then
            case state is
                when S_IDLE =>
                    if START = '1' then
                        counter <= 0;
                        case OP is
                            when INSTR_ADD =>
                                result_reg.meta <= A.meta;
                                state <= S_ADD;

                            when INSTR_MUL =>
                                result_reg.meta <= A.meta;
                                state <= S_MUL;

                            when INSTR_MATMUL =>
                                mm_M <= A.meta.shape(0);
                                mm_K <= A.meta.shape(1);
                                mm_N <= B.meta.shape(1);

                                result_reg.meta.shape(0) <= A.meta.shape(0);
                                result_reg.meta.shape(1) <= B.meta.shape(1);
                                result_reg.meta.n_dims   <= 2;
                                result_reg.meta.n_elems  <= A.meta.shape(0) * B.meta.shape(1);
                                result_reg.meta.offset   <= 0;
										  
                                result_reg.meta.strides(0) <= B.meta.shape(1);
                                result_reg.meta.strides(1) <= 1;

                                mm_i <= 0;
                                mm_j <= 0;
                                mm_ki <= 0;

                                a_row_base <= A.meta.offset;
                                a_ptr      <= A.meta.offset;
                                b_col_base <= B.meta.offset;
                                b_ptr      <= B.meta.offset;
                                c_ptr      <= 0;

                                mm_acc <= to_float(0);
                                state  <= S_MATMUL;

                            when others =>
                                state <= S_IDLE;
                        end case;
                    end if;

                when S_MATMUL =>
						 f_a    := to_float(A.data(a_ptr));
						 f_b    := to_float(B.data(b_ptr));
						 f_prod := f_a * f_b;

						 if mm_ki = A.meta.shape(1) - 1 then
							  result_reg.data(c_ptr) <= to_slv(mm_acc + f_prod);
							  c_ptr  <= c_ptr + 1;
							  mm_acc <= to_float(0);
							  mm_ki  <= 0;

							  a_ptr <= a_row_base;

							  if mm_j = B.meta.shape(1) - 1 then
									mm_j       <= 0;
									b_col_base <= B.meta.offset;
									b_ptr      <= B.meta.offset;

									if mm_i = A.meta.shape(0) - 1 then
										 state <= S_DONE;
									else
										 mm_i       <= mm_i + 1;
										 a_row_base <= a_row_base + A.meta.strides(0);
										 a_ptr      <= a_row_base + A.meta.strides(0);
									end if;
							  else
									mm_j       <= mm_j + 1;
									b_col_base <= b_col_base + B.meta.strides(1);
									b_ptr      <= b_col_base + B.meta.strides(1);
							  end if;

						 else
							  mm_acc <= mm_acc + f_prod;
							  mm_ki  <= mm_ki + 1;
							  a_ptr  <= a_ptr + A.meta.strides(1);
							  b_ptr  <= b_ptr + B.meta.strides(0);
						 end if;

                when S_ADD =>
                    f_a := to_float(A.data(counter));
                    f_b := to_float(B.data(counter));
                    f_res := f_a + f_b;
                    result_reg.data(counter) <= to_slv(f_res);

                    if counter = A.meta.n_elems - 1 then
                        state   <= S_DONE;
                        counter <= 0;
                    else
                        counter <= counter + 1;
                    end if;

                when S_MUL =>
                    f_a := to_float(A.data(counter));
                    f_b := to_float(B.data(counter));
                    f_res := f_a * f_b;
                    result_reg.data(counter) <= to_slv(f_res);

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
