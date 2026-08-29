const std = @import("std");
const cpu = @import("cpu/cpu.zig");
const builtin = @import("builtin");

var recved_sigint = false;

fn installSigintHandler() !void {
    const Handler = struct {
        fn handler(_: c_int) callconv(.c) void {
            recved_sigint = true;
        }
    };

    if (comptime builtin.os.tag == .windows) {
        const winapi = struct {
            const SigHandler = fn (signum: c_int) callconv(.c) void;
            extern fn signal(signum: c_int, ?*const SigHandler) callconv(.c) void;
        };
        winapi.signal(
            2, // SIGINT
            &Handler.handler,
        );
    } else {
        const action = std.posix.Sigaction{
            .handler = .{ .handler = Handler.handler },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };

        try std.posix.sigaction(std.posix.SIG.INT, &action, null);
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    var stdout_writer_interface = &stdout_writer.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buf);
    var stdin_reader_interface = &stdin_reader.interface;

    try stdout_writer_interface.print("binary path: ", .{});
    try stdout_writer_interface.flush();
    const bytes_read = try stdin_reader_interface.takeDelimiter('\n') orelse unreachable;
    const file_path = std.mem.trim(u8, bytes_read, "\r");

    const file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    defer file.close(io);

    const file_stats = try file.stat(io);
    const file_size = file_stats.size;

    const allocator = init.arena.allocator();

    var file_buf: [1024]u8 = undefined;
    var file_reader = file.reader(io, &file_buf);
    var file_reader_interface = &file_reader.interface;

    try installSigintHandler();

    const bios = try file_reader_interface.readAlloc(allocator, file_size);
    cpu.setBIOS(bios);

    while (!recved_sigint) {
        try cpu.poll(io, false);
    }

    try cpu.poll(io, true);
}
