//! Program for taking a compiled bytecode and generating valid VHDL IROM and CPOOL
//! files for dropping into the hw architecture

const std = @import("std");
const matstack = @import("matstack");

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
}
