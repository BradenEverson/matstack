const std = @import("std");
const matstack = @import("matstack");
const VirtualMachine = matstack.VirtualMachine;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const io = init.io;

    const alloc = arena.allocator();

    var args = init.minimal.args.iterate();
    _ = args.next();

    if (args.next()) |file_path| {
        const bytecode = try std.Io.Dir.cwd().readFileAlloc(
            io,
            file_path,
            alloc,
            .unlimited,
        );
        errdefer alloc.free(bytecode);

        var vm = try VirtualMachine.tryParse(alloc, bytecode);
        while (!(try vm.step(arena.allocator()))) {}
    } else {
        std.debug.print("Missing bytecode file!!!\n", .{});
        std.process.exit(1);
    }
}
