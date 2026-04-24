//! Program for taking a compiled bytecode and generating valid VHDL IROM and CPOOL
//! files for dropping into the hw architecture

const std = @import("std");
const matstack = @import("matstack");

const MAX_HW_DIM: usize = 4;
const MAX_HW_ELEMS: usize = 256;
const MAX_CPOOL: usize = 64;

const header_consts =
    \\-- compiler generated instruction constants. The opcode enum changes a lot so this is better than hardcoding :)
    \\library ieee;
    \\use ieee.std_logic_1164.all;
    \\package INSTRUCTIONS is
    \\
;

const footer_consts =
    \\end package INSTRUCTIONS;
;

const header_cpool =
    \\-- compiler-generated constant pool!
    \\library ieee;
    \\use ieee.std_logic_1164.all;
    \\use work.tensor.all;
    \\
    \\entity CPOOL is
    \\    port (
    \\        CLK     : in  std_logic;
    \\        EN      : in  std_logic;
    \\        ADDR    : in  integer range 0 to CPOOL_SIZE - 1;
    \\        DATA    : out tensor_t;
    \\        VALID   : out std_logic
    \\    );
    \\end entity;
    \\
    \\architecture ROM of CPOOL is
    \\begin
    \\    process(CLK)
    \\    begin
    \\        if rising_edge(CLK) then
    \\            VALID <= '0';
    \\            if EN = '1' then
    \\                VALID <= '1';
    \\                case ADDR is
;

const footer_cpool =
    \\                when others =>
    \\                        DATA <= (
    \\                            meta => (
    \\                                shape   => (others => 0),
    \\                                strides => (others => 0),
    \\                                n_dims  => 0,
    \\                                n_elems => 0,
    \\                                offset  => 0
    \\                            ),
    \\                            data => (others => x"00000000")
    \\                        );
    \\                end case;
    \\            end if;
    \\        end if;
    \\    end process;
    \\end architecture;
;

const header_irom =
    \\-- compiler generated IROM :D
    \\
    \\library ieee;
    \\use ieee.std_logic_1164.all;
    \\use work.tensor.all;
    \\
    \\entity IROM is
    \\    port (
    \\        ADDR    : in std_logic_vector(31 downto 0);
    \\        Q       : out std_logic_vector(15 downto 0)
    \\    );
    \\end entity;
    \\
    \\architecture MULTIPLEXER of IROM is
    \\begin
    \\  with ADDR select
    \\      Q <=
;

const footer_irom =
    \\end architecture;
;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const io = init.io;

    const alloc = arena.allocator();

    var args = init.minimal.args.iterate();
    _ = args.next();

    var source: []u8 = undefined;

    if (args.next()) |file_path| {
        source = try std.Io.Dir.cwd().readFileAlloc(
            io,
            file_path,
            alloc,
            .unlimited,
        );
    } else {
        std.debug.print("Missing bytecode!!!\n", .{});
        std.process.exit(1);
    }

    errdefer alloc.free(source);

    const vm = try matstack.VirtualMachine.tryParse(alloc, source);

    std.debug.print("{} constants\n", .{vm.constant_pool.len});
    std.debug.print("{} instructions\n", .{vm.instructions.len});

    if (vm.constant_pool.len >= MAX_CPOOL) {
        std.debug.print("Constant Pool in the Hardware can only store up to 64 tensors :(\n", .{});
        std.process.exit(1);
    }

    var file = try std.Io.Dir.cwd().createFile(io, "cpool.vhd", .{});

    var buffer: [1024]u8 = undefined;
    var writer = file.writerStreaming(io, &buffer);
    var write = &writer.interface;

    try writer.flush();

    try write.print("{s}\n", .{header_cpool});
    try writer.flush();

    // Construct the constant pool

    for (vm.constant_pool, 0..) |cpool_entry, i| {
        if (cpool_entry.shape.len > MAX_HW_DIM) {
            std.debug.print("Tensor on HW can only have at most 4 dimensions :(\n", .{});
            std.process.exit(1);
        }
        if (cpool_entry.data.len > MAX_HW_ELEMS) {
            std.debug.print("Tensor on HW can only have at most 256 elems :(\n", .{});
            std.process.exit(1);
        }

        try write.print("\t\t--ConstantPool[{}]: shape={any} data={any}\n", .{ i, cpool_entry.shape, cpool_entry.data });
        try write.print("\t\twhen {} =>\n", .{i});
        try write.print("\t\t\tDATA.meta.n_dims <= {};\n", .{cpool_entry.shape.len});
        try write.print("\t\t\tDATA.meta.n_elems <= {};\n", .{cpool_entry.data.len});
        try write.print("\t\t\tDATA.meta.offset <= {};\n", .{cpool_entry.offset});
        try writer.flush();

        try write.print("\t\t\tDATA.meta.shape <= (", .{});
        for (0..3) |j| {
            if (j >= cpool_entry.shape.len) {
                try write.print("0,", .{});
            } else {
                try write.print("{},", .{cpool_entry.shape[j]});
            }
        }

        if (3 >= cpool_entry.shape.len) {
            try write.print("0);\n", .{});
        } else {
            try write.print("{});\n", .{cpool_entry.shape[3]});
        }
        try writer.flush();

        try write.print("\t\t\tDATA.meta.strides <= (", .{});
        for (0..3) |j| {
            if (j >= cpool_entry.strides.len) {
                try write.print("0,", .{});
            } else {
                try write.print("{},", .{cpool_entry.strides[j]});
            }
        }

        if (3 >= cpool_entry.strides.len) {
            try write.print("0);\n", .{});
        } else {
            try write.print("{});\n", .{cpool_entry.strides[3]});
        }
        try writer.flush();

        for (cpool_entry.data, 0..) |data, j| {
            const byte: u32 = @bitCast(data);
            try write.print("\t\t\tDATA.data({}) <= x\"{X:0>8}\"; -- {:.2}\n", .{ j, byte, data });
            try writer.flush();
        }

        try write.print("\t\t\tDATA.data({} to MAX_ELEMENTS - 1) <= (others => x\"00000000\");\n", .{cpool_entry.data.len});
        try writer.flush();

        try write.print("\n", .{});
        try writer.flush();
    }

    // Write the instructions into an IROM file

    try write.print("{s}\n", .{footer_cpool});
    try writer.flush();

    file.close(io);

    file = try std.Io.Dir.cwd().createFile(io, "irom.vhd", .{});

    writer = file.writerStreaming(io, &buffer);
    write = &writer.interface;

    try writer.flush();

    try write.print("{s}", .{header_irom});
    try writer.flush();

    for (vm.instructions, 0..) |instr, i| {
        if (i > 0)
            try write.print("\t    ", .{});
        try write.print(" x\"{X:0>2}{X:0>2}\"", .{ @intFromEnum(instr.cmd), instr.extra });
        try write.print(" when x\"{X:0>8}\", -- {any} \n", .{ i, instr });
    }

    try write.print("\t    ", .{});
    try write.print(" x\"{X:0>2}{X:0>2}\" when others; -- halt\n", .{ @intFromEnum(matstack.Instruction.Command.HALT), 0 });
    try write.print("{s}\n", .{footer_irom});
    try writer.flush();

    file.close(io);

    // Write the instructions as VHDL constants

    file = try std.Io.Dir.cwd().createFile(io, "instructions.vhd", .{});
    defer file.close(io);

    writer = file.writerStreaming(io, &buffer);
    write = &writer.interface;

    try writer.flush();

    try write.print("{s}\n", .{header_consts});
    try writer.flush();

    inline for (@typeInfo(matstack.Instruction.Command).@"enum".fields) |instr| {
        try write.print("\tconstant INSTR_{s}: std_logic_vector(7 downto 0) := x\"{X:0>2}\";\n", .{ instr.name, instr.value });
    }

    try write.print("\n{s}\n", .{footer_consts});
    try writer.flush();
}
