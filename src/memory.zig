const std = @import("std");
const io = @import("io.zig");

const len_types = @import("length_types.zig");
const Length = len_types.Length;
const LengthType = len_types.LengthType;

const log = std.log.scoped(.memory);

fn writel(region: []u8, addr: u32, value: u32, comptime length: Length) void {
    // switch (length) {
    //     .Byte => std.mem.writeInt(u8, region[addr..][0..1], @truncate(value), .little),
    //     .HalfWord => std.mem.writeInt(u16, region[addr..][0..2], @truncate(value), .little),
    //     .Word => std.mem.writeInt(u32, region[addr..][0..4], value, .little),
    // }
    std.mem.writeInt(
        LengthType(length),
        region[addr..][0..@intFromEnum(length)],
        @truncate(value),
        .little,
    );
}

fn readl(region: []u8, addr: u32, comptime length: Length) LengthType(length) {
    // return switch (length) {
    //     .Byte => std.mem.readInt(u8, region[addr..][0..1], .little),
    //     .HalfWord => std.mem.readInt(u16, region[addr..][0..2], .little),
    //     .Word => std.mem.readInt(u32, region[addr..][0..4], .little),
    // };
    return std.mem.readInt(
        LengthType(length),
        region[addr..][0..@intFromEnum(length)],
        .little,
    );
}

pub const MemoryMap = struct {
    bios: [16 * 1024]u8 = @splat(0), // 16 KiB

    i_wram: [32 * 1024]u8 = @splat(0), // 32 KiB
    e_wram: [256 * 1024]u8 = @splat(0), // 256 KiB
    vram: [96 * 1024]u8 = @splat(0), // 96 KiB

    bg_palette: [512]u8 = @splat(0), // 512 B
    obj_palette: [512]u8 = @splat(0), // 512 B
    oam: [1024]u8 = @splat(0), // 1 KiB

    rom: [32 * 1024 * 1024]u8 = @splat(0), // 32 MiB

    sram: [64 * 1024]u8 = @splat(0), // 64 KiB

    io_registers: io.IORegistersType = @splat(0),

    pub fn write(self: *MemoryMap, addr: u32, value: u32, comptime length: Length) void {
        switch (addr) {
            0x02000000...0x0203FFFF => writel(&self.i_wram, addr - 0x02000000, value, length),
            0x03000000...0x03007FFF => writel(&self.e_wram, addr - 0x03000000, value, length),
            0x04000000...0x040003FE => io.writeIOR(&self.io_registers, addr, value, length, false),
            0x05000000...0x050001FF => writel(&self.bg_palette, addr - 0x05000000, value, length),
            0x05000200...0x050003FF => writel(&self.obj_palette, addr - 0x05000200, value, length),
            0x06000000...0x06017FFF => writel(&self.vram, addr - 0x06000000, value, length),
            0x07000000...0x070003FF => writel(&self.oam, addr - 0x07000000, value, length),
            0x0E000000...0x0E00FFFF => writel(&self.sram, addr - 0x0E000000, value, length),
            else => log.err("Attempted to write illegal memory address {X}", .{addr}),
        }
    }

    pub fn read(self: *MemoryMap, addr: u32, comptime length: Length) LengthType(length) {
        return reader_blk: switch (addr) {
            0x00000000...0x00003FFF => break :reader_blk readl(&self.bios, addr, length),
            0x02000000...0x0203FFFF => break :reader_blk readl(&self.i_wram, addr - 0x02000000, length),
            0x03000000...0x03007FFF => break :reader_blk readl(&self.e_wram, addr - 0x03000000, length),
            0x04000000...0x040003FE => break :reader_blk io.readIOR(&self.io_registers, addr, length, false),
            0x05000000...0x050001FF => break :reader_blk readl(&self.bg_palette, addr - 0x05000000, length),
            0x05000200...0x050003FF => break :reader_blk readl(&self.obj_palette, addr - 0x05000200, length),
            0x06000000...0x06017FFF => break :reader_blk readl(&self.vram, addr - 0x06000000, length),
            0x07000000...0x070003FF => break :reader_blk readl(&self.oam, addr - 0x07000000, length),
            0x08000000...0x0DFFFFFF => {
                const rom_addr: u32 = @intCast((addr - 0x08000000) % self.rom.len);

                break :reader_blk readl(&self.rom, rom_addr, length);
            },
            0x0E000000...0x0E00FFFF => break :reader_blk readl(&self.sram, addr - 0x0E000000, length),
            else => {
                log.err("Attempted to read illegal memory address {X}", .{addr});
                break :reader_blk 0;
            },
        };
    }

    pub fn hWriteIOR(self: *MemoryMap, addr: u32, value: u32, comptime length: Length) void {
        io.writeIOR(&self.io_registers, addr, value, length, true);
    }

    pub fn hReadIOR(self: *MemoryMap, addr: u32, comptime length: Length) LengthType(length) {
        return io.readIOR(&self.io_registers, addr, length, true);
    }
};
