const std = @import("std");
const cpu = @import("cpu/cpu.zig");
const builtin = @import("builtin");
const rl = @import("raylib");
const ppu = @import("./ppu.zig");

var recved_sigint = false;

const SCR_WIDTH = 240;
const SCR_HEIGHT = 160;

var stop_cpu_polling = std.atomic.Value(bool).init(false);

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

pub fn cpuPollWorker(io: std.Io) void {
    while (!stop_cpu_polling.load(.acquire))
        cpu.poll(io, false);

    cpu.poll(io, true);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    var stdout_writer_interface = &stdout_writer.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buf);
    var stdin_reader_interface = &stdin_reader.interface;

    // Read BIOS file
    try stdout_writer_interface.print("BIOS path: ", .{});
    try stdout_writer_interface.flush();

    const bios_path_bytes_read = try stdin_reader_interface.takeDelimiter('\n') orelse unreachable;

    const bios_file_path = std.mem.trim(u8, bios_path_bytes_read, "\r");

    const bios_file = try std.Io.Dir.cwd().openFile(io, bios_file_path, .{});
    defer bios_file.close(io);

    const bios_file_stats = try bios_file.stat(io);
    const bios_file_size = bios_file_stats.size;

    var bios_file_buf: [1024]u8 = undefined;
    var bios_file_reader = bios_file.reader(io, &bios_file_buf);
    var bios_file_reader_interface = &bios_file_reader.interface;

    const bios = try bios_file_reader_interface.readAlloc(allocator, bios_file_size);

    // Read ROM file
    try stdout_writer_interface.print("ROM path: ", .{});
    try stdout_writer_interface.flush();

    const rom_path_bytes_read = try stdin_reader_interface.takeDelimiter('\n') orelse unreachable;

    const rom_file_path = std.mem.trim(u8, rom_path_bytes_read, "\r");

    const rom_file = try std.Io.Dir.cwd().openFile(io, rom_file_path, .{});
    defer rom_file.close(io);

    const rom_file_stats = try rom_file.stat(io);
    const rom_file_size = rom_file_stats.size;

    var rom_file_buf: [1024]u8 = undefined;
    var rom_file_reader = rom_file.reader(io, &rom_file_buf);
    var rom_file_reader_interface = &rom_file_reader.interface;

    const rom = try rom_file_reader_interface.readAlloc(allocator, rom_file_size);

    // Intialize
    cpu.setBIOS(bios);
    cpu.setROM(rom);

    rl.initWindow(SCR_WIDTH, SCR_HEIGHT, "ZBA");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const cpu_polling_thread = try std.Thread.spawn(.{}, cpuPollWorker, .{io});

    var v_count: u8 = 0;

    while (!rl.windowShouldClose()) {
        if (v_count == 159) ppu.setVBlank(true);
        if (v_count == 0) ppu.setVBlank(false);

        rl.beginDrawing();
        defer rl.endDrawing();

        ppu.drawFrame();

        if (v_count < 227) {
            v_count += 1;
        } else {
            v_count = 0;
        }

        ppu.updateVCount(v_count);
    }

    std.debug.print("waiting for cpu thread to stop...\n", .{});

    stop_cpu_polling.store(true, .release);
    cpu_polling_thread.join();
}
