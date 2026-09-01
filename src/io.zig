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

// these are meant to be used by memory unit and CPU

/// Writes `value` to IORs at addr starting from 0, doesn't do anything if register is invalid or read-only
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

/// Reads value of IORs at addr starting from 0, reads 0 if register is invalid or write-only
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

// these are meant to be used by other units such as PPU, Audio unit etc

/// Writes `value` to given register, it is not meant for use by MMU
///
/// **Note:** This function ignores if register is writeable or not
/// **Note:** This function doesn't check bounds on value it is writing
pub fn setIOR(ior: *IORegistersType, reg: IORegisters, value: u32, comptime length: Length) LengthType(length) {
    setIORByAddr(ior, @intFromEnum(reg), value, length);
}

/// Reads the given register, it is not meant for use by MMU
///
/// **Note:** This function ignores if register is readable or not
/// **Note:** This function doesn't check bounds on value it is reading
pub fn getIOR(ior: *IORegistersType, reg: IORegisters, comptime length: Length) LengthType(length) {
    return getIORByAddr(ior, @intFromEnum(reg), length);
}

/// Writes `value` to given address(starting from 0x4000000), it is not meant for use by MMU
///
/// **Note:** This function ignores if register is writeable or not
/// **Note:** This function doesn't check bounds on value it is writing
pub fn setIORByAddr(ior: *IORegistersType, addr: u32, value: u32, comptime length: Length) LengthType(length) {
    const rel_addr = addr - 0x4000000;

    var buf: [@intFromEnum(length)]u8 = @splat(0);

    std.mem.writeInt(LengthType(length), &buf, @truncate(value), .little);

    for (buf, 0..) |byte, i| {
        const byte_addr = rel_addr + @as(u32, @intCast(i));

        ior[byte_addr] = byte;
    }
}

/// Reads the register at given address(starting from 0x4000000), it is not meant for use by MMU
///
/// **Note:** This function ignores if register is readable or not
/// **Note:** This function doesn't check bounds on value it is reading
pub fn getIORByAddr(ior: *IORegistersType, addr: u32, comptime length: Length) LengthType(length) {
    const rel_addr = addr - 0x4000000;

    const read_size = @intFromEnum(length);

    var buf: [read_size]u8 = @splat(0);

    for (0..read_size) |i| {
        const byte_addr = rel_addr + @as(u32, @intCast(i));

        buf[i] = ior[byte_addr];
    }

    return std.mem.readInt(LengthType(length), &buf, .little);
}

pub const IORegisters = enum(u32) {
    // LCD
    DISPCNT = 0x4000000,
    DISPSTAT = 0x4000004,
    VCOUNT = 0x4000006,
    BG0CNT = 0x4000008,
    BG1CNT = 0x400000A,
    BG2CNT = 0x400000C,
    BG3CNT = 0x400000E,
    BG0HOFS = 0x4000010,
    BG0VOFS = 0x4000012,
    BG1HOFS = 0x4000014,
    BG1VOFS = 0x4000016,
    BG2HOFS = 0x4000018,
    BG2VOFS = 0x400001A,
    BG3HOFS = 0x400001C,
    BG3VOFS = 0x400001E,
    BG2PA = 0x4000020,
    BG2PB = 0x4000022,
    BG2PC = 0x4000024,
    BG2PD = 0x4000026,
    BG2X = 0x4000028,
    BG2Y = 0x400002C,
    BG3PA = 0x4000030,
    BG3PB = 0x4000032,
    BG3PC = 0x4000034,
    BG3PD = 0x4000036,
    BG3X = 0x4000038,
    BG3Y = 0x400003C,
    WIN0H = 0x4000040,
    WIN1H = 0x4000042,
    WIN0V = 0x4000044,
    WIN1V = 0x4000046,
    WININ = 0x4000048,
    WINOUT = 0x400004A,
    MOSAIC = 0x400004C,
    BLDCNT = 0x4000050,
    BLDALPHA = 0x4000052,
    BLDY = 0x4000054,

    // Sound
    SOUND1CNT_L = 0x4000060,
    SOUND1CNT_H = 0x4000062,
    SOUND1CNT_X = 0x4000064,
    SOUND2CNT_L = 0x4000068,
    SOUND2CNT_H = 0x400006C,
    SOUND3CNT_L = 0x4000070,
    SOUND3CNT_H = 0x4000072,
    SOUND3CNT_X = 0x4000074,
    SOUND4CNT_L = 0x4000078,
    SOUND4CNT_H = 0x400007C,
    SOUNDCNT_L = 0x4000080,
    SOUNDCNT_H = 0x4000082,
    SOUNDCNT_X = 0x4000084,
    SOUNDBIAS = 0x4000088,
    WAVE_RAM = 0x4000090,
    FIFO_A = 0x40000A0,
    FIFO_B = 0x40000A4,

    // DMA
    DMA0SAD = 0x40000B0,
    DMA0DAD = 0x40000B4,
    DMA0CNT_L = 0x40000B8,
    DMA0CNT_H = 0x40000BA,
    DMA1SAD = 0x40000BC,
    DMA1DAD = 0x40000C0,
    DMA1CNT_L = 0x40000C4,
    DMA1CNT_H = 0x40000C6,
    DMA2SAD = 0x40000C8,
    DMA2DAD = 0x40000CC,
    DMA2CNT_L = 0x40000D0,
    DMA2CNT_H = 0x40000D2,
    DMA3SAD = 0x40000D4,
    DMA3DAD = 0x40000D8,
    DMA3CNT_L = 0x40000DC,
    DMA3CNT_H = 0x40000DE,

    // Timer
    TM0CNT_L = 0x4000100,
    TM0CNT_H = 0x4000102,
    TM1CNT_L = 0x4000104,
    TM1CNT_H = 0x4000106,
    TM2CNT_L = 0x4000108,
    TM2CNT_H = 0x400010A,
    TM3CNT_L = 0x400010C,
    TM3CNT_H = 0x400010E,

    // Serial 1
    SIODATA32 = 0x4000120,
    SIOMULTI0 = 0x4000120,
    SIOMULTI1 = 0x4000122,
    SIOMULTI2 = 0x4000124,
    SIOMULTI3 = 0x4000126,
    SIOCNT = 0x4000128,
    SIOMLT_SEND = 0x400012A,
    SIODATA8 = 0x400012A,

    // Keypad
    KEYINPUT = 0x4000130,
    KEYCNT = 0x4000132,

    // Serial 2
    RCNT = 0x4000134,
    JOYCNT = 0x4000140,
    JOY_RECV = 0x4000150,
    JOY_TRANS = 0x4000154,
    JOYSTAT = 0x4000158,

    // Interrupt, Waitstate, and Power-Down Control
    IE = 0x4000200,
    IF = 0x4000202,
    WAITCNT = 0x4000204,
    IME = 0x4000208,
    POSTFLG = 0x4000300,
    HALTCNT = 0x4000301,
};
