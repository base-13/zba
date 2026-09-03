const std = @import("std");

const len_types = @import("length_types.zig");
const Length = len_types.Length;
const LengthType = len_types.LengthType;

const log = std.log.scoped(.io);

pub const IORegistersType = [0x700000]u8;

fn isWriteable(addr: u32) bool {
    return switch (addr) {
        0x6...0x7,
        0x4e...0x4f,
        0x56...0x5f,
        0x66...0x67,
        0x6a...0x6b,
        0x6e...0x6f,
        0x76...0x77,
        0x7a...0x7b,
        0x7e...0x7f,
        0x86...0x87,
        0x8a...0x8f,
        0xa8...0xaf,
        0xe0...0xff,
        0x110...0x11f,
        0x12c...0x131,
        0x136...0x13f,
        0x142...0x14f,
        0x15a...0x1ff,
        0x206...0x207,
        0x20a...0x2ff,
        0x302...0x6fffff,
        => false,
        else => true,
    };
}

fn isReadable(addr: u32) bool {
    return switch (addr) {
        0x10...0x47,
        0x4c...0x4f,
        0x54...0x5f,
        0x66...0x67,
        0x6a...0x6b,
        0x6e...0x6f,
        0x76...0x77,
        0x7a...0x7b,
        0x7e...0x7f,
        0x86...0x87,
        0x8a...0x8f,
        0xa0...0xb9,
        0xbc...0xc5,
        0xc8...0xd1,
        0xd4...0xdd,
        0xe0...0xff,
        0x110...0x11f,
        0x12c...0x12f,
        0x136...0x13f,
        0x142...0x14f,
        0x15a...0x1ff,
        0x206...0x207,
        0x20a...0x2ff,
        0x301...0x6fffff,
        => false,
        else => true,
    };
}

const IOR_STARTING_ADDR = 0x4000000;

/// Writes `value` to given address(starting from 0x4000000).
///
/// if `force` is `true` it ignores if register is writeable or not
/// **Note:** This function doesn't check bounds on value it is writing
pub fn writeIOR(ior: *IORegistersType, addr: u32, value: u32, comptime length: Length, force: bool) void {
    const rel_addr = addr - IOR_STARTING_ADDR;

    var buf: [@intFromEnum(length)]u8 = @splat(0);

    std.mem.writeInt(LengthType(length), &buf, @truncate(value), .little);

    for (buf, 0..) |byte, i| {
        const byte_addr = rel_addr + @as(u32, @intCast(i));

        if (isWriteable(byte_addr) or force)
            ior[byte_addr] = byte
        else
            log.err("Attempted write to invalid IOR at {X}", .{IOR_STARTING_ADDR + byte_addr});
    }
}

/// Reads the register at given address(starting from 0x4000000), invalid or write-only registers read 0.
///
/// if `force` is `true` it ignores if register is writeable or not
/// **Note:** This function doesn't check bounds on value it is reading
pub fn readIOR(ior: *IORegistersType, addr: u32, comptime length: Length, force: bool) LengthType(length) {
    const rel_addr = addr - IOR_STARTING_ADDR;

    const read_size = @intFromEnum(length);

    var buf: [read_size]u8 = @splat(0);

    for (0..read_size) |i| {
        const byte_addr = rel_addr + @as(u32, @intCast(i));

        if (isReadable(byte_addr) or force)
            buf[i] = ior[byte_addr]
        else
            log.err("Attempted read to invalid IOR at {X}", .{IOR_STARTING_ADDR + byte_addr});
    }

    return std.mem.readInt(LengthType(length), &buf, .little);
}

pub const IORegisters = struct {
    // LCD
    pub const DISPCNT: u32 = 0x4000000;
    pub const DISPSTAT: u32 = 0x4000004;
    pub const VCOUNT: u32 = 0x4000006;
    pub const BG0CNT: u32 = 0x4000008;
    pub const BG1CNT: u32 = 0x400000A;
    pub const BG2CNT: u32 = 0x400000C;
    pub const BG3CNT: u32 = 0x400000E;
    pub const BG0HOFS: u32 = 0x4000010;
    pub const BG0VOFS: u32 = 0x4000012;
    pub const BG1HOFS: u32 = 0x4000014;
    pub const BG1VOFS: u32 = 0x4000016;
    pub const BG2HOFS: u32 = 0x4000018;
    pub const BG2VOFS: u32 = 0x400001A;
    pub const BG3HOFS: u32 = 0x400001C;
    pub const BG3VOFS: u32 = 0x400001E;
    pub const BG2PA: u32 = 0x4000020;
    pub const BG2PB: u32 = 0x4000022;
    pub const BG2PC: u32 = 0x4000024;
    pub const BG2PD: u32 = 0x4000026;
    pub const BG2X: u32 = 0x4000028;
    pub const BG2Y: u32 = 0x400002C;
    pub const BG3PA: u32 = 0x4000030;
    pub const BG3PB: u32 = 0x4000032;
    pub const BG3PC: u32 = 0x4000034;
    pub const BG3PD: u32 = 0x4000036;
    pub const BG3X: u32 = 0x4000038;
    pub const BG3Y: u32 = 0x400003C;
    pub const WIN0H: u32 = 0x4000040;
    pub const WIN1H: u32 = 0x4000042;
    pub const WIN0V: u32 = 0x4000044;
    pub const WIN1V: u32 = 0x4000046;
    pub const WININ: u32 = 0x4000048;
    pub const WINOUT: u32 = 0x400004A;
    pub const MOSAIC: u32 = 0x400004C;
    pub const BLDCNT: u32 = 0x4000050;
    pub const BLDALPHA: u32 = 0x4000052;
    pub const BLDY: u32 = 0x4000054;

    // Sound
    pub const SOUND1CNT_L: u32 = 0x4000060;
    pub const SOUND1CNT_H: u32 = 0x4000062;
    pub const SOUND1CNT_X: u32 = 0x4000064;
    pub const SOUND2CNT_L: u32 = 0x4000068;
    pub const SOUND2CNT_H: u32 = 0x400006C;
    pub const SOUND3CNT_L: u32 = 0x4000070;
    pub const SOUND3CNT_H: u32 = 0x4000072;
    pub const SOUND3CNT_X: u32 = 0x4000074;
    pub const SOUND4CNT_L: u32 = 0x4000078;
    pub const SOUND4CNT_H: u32 = 0x400007C;
    pub const SOUNDCNT_L: u32 = 0x4000080;
    pub const SOUNDCNT_H: u32 = 0x4000082;
    pub const SOUNDCNT_X: u32 = 0x4000084;
    pub const SOUNDBIAS: u32 = 0x4000088;
    pub const WAVE_RAM: u32 = 0x4000090;
    pub const FIFO_A: u32 = 0x40000A0;
    pub const FIFO_B: u32 = 0x40000A4;

    // DMA
    pub const DMA0SAD: u32 = 0x40000B0;
    pub const DMA0DAD: u32 = 0x40000B4;
    pub const DMA0CNT_L: u32 = 0x40000B8;
    pub const DMA0CNT_H: u32 = 0x40000BA;
    pub const DMA1SAD: u32 = 0x40000BC;
    pub const DMA1DAD: u32 = 0x40000C0;
    pub const DMA1CNT_L: u32 = 0x40000C4;
    pub const DMA1CNT_H: u32 = 0x40000C6;
    pub const DMA2SAD: u32 = 0x40000C8;
    pub const DMA2DAD: u32 = 0x40000CC;
    pub const DMA2CNT_L: u32 = 0x40000D0;
    pub const DMA2CNT_H: u32 = 0x40000D2;
    pub const DMA3SAD: u32 = 0x40000D4;
    pub const DMA3DAD: u32 = 0x40000D8;
    pub const DMA3CNT_L: u32 = 0x40000DC;
    pub const DMA3CNT_H: u32 = 0x40000DE;

    // Timer
    pub const TM0CNT_L: u32 = 0x4000100;
    pub const TM0CNT_H: u32 = 0x4000102;
    pub const TM1CNT_L: u32 = 0x4000104;
    pub const TM1CNT_H: u32 = 0x4000106;
    pub const TM2CNT_L: u32 = 0x4000108;
    pub const TM2CNT_H: u32 = 0x400010A;
    pub const TM3CNT_L: u32 = 0x400010C;
    pub const TM3CNT_H: u32 = 0x400010E;

    // Serial 1
    pub const SIODATA32: u32 = 0x4000120;
    pub const SIOMULTI0: u32 = 0x4000120;
    pub const SIOMULTI1: u32 = 0x4000122;
    pub const SIOMULTI2: u32 = 0x4000124;
    pub const SIOMULTI3: u32 = 0x4000126;
    pub const SIOCNT: u32 = 0x4000128;
    pub const SIOMLT_SEND: u32 = 0x400012A;
    pub const SIODATA8: u32 = 0x400012A;

    // Keypad
    pub const KEYINPUT: u32 = 0x4000130;
    pub const KEYCNT: u32 = 0x4000132;

    // Serial 2
    pub const RCNT: u32 = 0x4000134;
    pub const JOYCNT: u32 = 0x4000140;
    pub const JOY_RECV: u32 = 0x4000150;
    pub const JOY_TRANS: u32 = 0x4000154;
    pub const JOYSTAT: u32 = 0x4000158;

    // Interrupt, Waitstate, and Power-Down Control
    pub const IE: u32 = 0x4000200;
    pub const IF: u32 = 0x4000202;
    pub const WAITCNT: u32 = 0x4000204;
    pub const IME: u32 = 0x4000208;
    pub const POSTFLG: u32 = 0x4000300;
    pub const HALTCNT: u32 = 0x4000301;
};
