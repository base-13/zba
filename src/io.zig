const std = @import("std");

const len_types = @import("length_types.zig");
const Length = len_types.Length;
const LengthType = len_types.LengthType;

const log = std.log.scoped(.io);

pub const IORegistersType = [0x700000]u8;

fn isWriteable(addr: u32) bool {
    return switch (addr) {
        0x6...0x8,
        0x4e...0x50,
        0x56...0x60,
        0x66...0x68,
        0x6a...0x6c,
        0x6e...0x70,
        0x76...0x78,
        0x7a...0x7c,
        0x7e...0x80,
        0x86...0x88,
        0x8a...0x90,
        0xa8...0xb0,
        0xe0...0x100,
        0x110...0x120,
        0x12c...0x132,
        0x136...0x140,
        0x142...0x150,
        0x15a...0x200,
        0x206...0x208,
        0x20a...0x300,
        0x302...0x700000,
        => false,
        else => true,
    };
}

fn isReadable(addr: u32) bool {
    return switch (addr) {
        0x10...0x48,
        0x4c...0x50,
        0x54...0x60,
        0x66...0x68,
        0x6a...0x6c,
        0x6e...0x70,
        0x76...0x78,
        0x7a...0x7c,
        0x7e...0x80,
        0x86...0x88,
        0x8a...0x90,
        0xa0...0xba,
        0xbc...0xc6,
        0xc8...0xd2,
        0xd4...0xde,
        0xe0...0x100,
        0x110...0x120,
        0x12c...0x130,
        0x136...0x140,
        0x142...0x150,
        0x15a...0x200,
        0x206...0x208,
        0x20a...0x300,
        0x301...0x700000,
        => false,
        else => true,
    };
}

pub fn writeIOR(ior: *IORegistersType, addr: u32, value: u32, comptime length: Length) void {
    var buf: [@intFromEnum(length)]u8 = @splat(0);

    std.mem.writeInt(LengthType(length), &buf, @truncate(value), .little);

    for (buf, 0..) |byte, i| {
        const byte_addr = addr + @as(u32, @intCast(i));

        if (isWriteable(byte_addr))
            ior[byte_addr] = byte
        else
            log.warn("Attempted write to invalid IOR at {X}", .{byte_addr});
    }
}

pub fn readIOR(ior: *IORegistersType, addr: u32, comptime length: Length) LengthType(length) {
    const read_size = @intFromEnum(length);

    var buf: [read_size]u8 = @splat(0);

    for (0..read_size) |i| {
        const byte_addr = addr + @as(u32, @intCast(i));

        if (isReadable(byte_addr))
            buf[i] = ior[byte_addr]
        else
            log.warn("Attempted read to invalid IOR at {X}", .{byte_addr});
    }

    return std.mem.readInt(LengthType(length), &buf, .little);
}
