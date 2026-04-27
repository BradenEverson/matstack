const std = @import("std");
const matstack = @import("matstack");
const VirtualMachine = matstack.VirtualMachine;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var args = init.minimal.args.iterate();
    _ = args.next();

    if (args.next()) |file_path| {
        const bytecode = try std.Io.Dir.cwd().readFileAlloc(
            io,
            file_path,
            alloc,
            .unlimited,
        );
        defer alloc.free(bytecode);

        var vm = try VirtualMachine.tryParse(alloc, bytecode);
        defer vm.deinit(alloc);

        while (!(try vm.step(alloc))) {}
    } else {
        std.debug.print("Missing bytecode file!!!\n", .{});
        std.process.exit(1);
    }
}
