const std = @import("std");
const io = @import("io.zig");

const len_types = @import("length_types.zig");
const Length = len_types.Length;
const LengthType = len_types.LengthType;

const log = std.log.scoped(.memory);

fn writel(region: []u8, addr: u32, value: u32, comptime length: Length) void {
    const T = LengthType(length);
    const start: usize = @intCast(addr);
    const size: usize = @intFromEnum(length);

    if (start >= region.len)
        return;

    const write_len = @min(size, region.len - start);

    const v: T = @truncate(value);

    for (0..write_len) |i| {
        region[start + i] = @truncate(v >> @intCast(i * 8));
    }
}

fn readl(region: []u8, addr: u32, comptime length: Length) LengthType(length) {
    const T = LengthType(length);
    const start: usize = @intCast(addr);
    const size: usize = @intFromEnum(length);

    var read: T = 0;

    if (start >= region.len)
        return read;

    const read_len = @min(size, region.len - start);

    for (0..read_len) |i| {
        read |= @as(T, region[start + i]) << @intCast(i * 8);
    }

    return read;
}

pub const BIOS_SIZE = 16 * 1024; // 16 KiB
pub const I_WRAM_SIZE = 32 * 1024; // 32 KiB
pub const E_WRAM_SIZE = 256 * 1024; // 256 KiB
pub const VRAM_SIZE = 96 * 1024; // 96 KiB
pub const BG_PALETTE_SIZE = 512; // 512 B
pub const OBJ_PALETTE_SIZE = 512; // 512 B
pub const OAM_SIZE = 1024; // 1 KiB
pub const ROM_SIZE = 32 * 1024 * 1024; // 32 MiB
pub const SRAM_SIZE = 64 * 1024; // 64 KiB

pub const MemoryMap = struct {
    bios: [BIOS_SIZE]u8 = @splat(0),

    i_wram: [I_WRAM_SIZE]u8 = @splat(0),
    e_wram: [E_WRAM_SIZE]u8 = @splat(0),
    vram: [VRAM_SIZE]u8 = @splat(0),

    bg_palette: [BG_PALETTE_SIZE]u8 = @splat(0),
    obj_palette: [OBJ_PALETTE_SIZE]u8 = @splat(0),
    oam: [OAM_SIZE]u8 = @splat(0),

    rom: [ROM_SIZE]u8 = @splat(0),

    sram: [SRAM_SIZE]u8 = @splat(0),

    io_registers: io.IORegistersType = @splat(0),

    pub fn write(self: *MemoryMap, addr: u32, value: u32, comptime length: Length) void {
        switch (addr) {
            0x02000000...0x02FFFFFF => writel(&self.e_wram, (addr - 0x02000000) % E_WRAM_SIZE, value, length),
            0x03000000...0x03FFFFFF => writel(&self.i_wram, (addr - 0x03000000) % I_WRAM_SIZE, value, length),
            0x04000000...0x04700000 => io.writeIOR(&self.io_registers, addr, value, length, false),
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
            0x02000000...0x02FFFFFF => break :reader_blk readl(&self.e_wram, (addr - 0x02000000) % E_WRAM_SIZE, length),
            0x03000000...0x03FFFFFF => break :reader_blk readl(&self.i_wram, (addr - 0x03000000) % I_WRAM_SIZE, length),
            0x04000000...0x04700000 => break :reader_blk io.readIOR(&self.io_registers, addr, length, false),
            0x05000000...0x050001FF => break :reader_blk readl(&self.bg_palette, addr - 0x05000000, length),
            0x05000200...0x050003FF => break :reader_blk readl(&self.obj_palette, addr - 0x05000200, length),
            0x06000000...0x06017FFF => break :reader_blk readl(&self.vram, addr - 0x06000000, length),
            0x07000000...0x070003FF => break :reader_blk readl(&self.oam, addr - 0x07000000, length),
            0x08000000...0x0DFFFFFF => {
                const rom_addr: u32 = @intCast((addr - 0x08000000) % ROM_SIZE);

                break :reader_blk readl(&self.rom, rom_addr, length);
            },
            0x0E000000...0x0E00FFFF => break :reader_blk readl(&self.sram, addr - 0x0E000000, length),
            else => {
                log.err("Attempted to read illegal memory address {X}", .{addr});
                break :reader_blk 0;
            },
        };
    }

    // IOR DMA
    pub fn hWriteIOR(self: *MemoryMap, addr: u32, value: u32, comptime length: Length) void {
        io.writeIOR(&self.io_registers, addr, value, length, true);
    }

    pub fn hReadIOR(self: *MemoryMap, addr: u32, comptime length: Length) LengthType(length) {
        return io.readIOR(&self.io_registers, addr, length, true);
    }
};
