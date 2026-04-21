-- Tensor description

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package TENSOR is

    constant MAX_DIMS     : integer := 4;
    constant MAX_ELEMENTS : integer := 128;
    constant STACK_SIZE   : integer := 32;
    constant SCRATCH_AREA : integer := 32;
	 constant CPOOL_SIZE   : integer := 16;

    type shape_t   is array(0 to MAX_DIMS - 1)     of integer range 0 to 255;
    type strides_t is array(0 to MAX_DIMS - 1)     of integer range 0 to 255;

    type tensor_meta_t is record
        shape   : shape_t;
        strides : strides_t;
        n_dims  : integer range 0 to MAX_DIMS;
        n_elems : integer range 0 to MAX_ELEMENTS;
        offset  : integer range 0 to MAX_ELEMENTS;
    end record;

    type tensor_data_t is array(0 to MAX_ELEMENTS - 1)
        of std_logic_vector(31 downto 0);

    type tensor_t is record
        meta : tensor_meta_t;
        data : tensor_data_t;
    end record;

end package;
