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

pub const BIOS_START = 0x00000000;
pub const E_WRAM_START = 0x02000000;
pub const I_WRAM_START = 0x03000000;
pub const IOR_START = 0x04000000;
pub const BG_PALETTE_START = 0x05000000;
pub const OBJ_PALETTE_START = 0x05000200;
pub const VRAM_START = 0x06000000;
pub const OAM_START = 0x07000000;
pub const SRAM_START = 0x0E000000;
pub const ROM_START = 0x08000000;

pub const BIOS_END = 0x00003FFF;
pub const E_WRAM_END = 0x02FFFFFF;
pub const I_WRAM_END = 0x03FFFFFF;
pub const IOR_END = 0x04700000;
pub const BG_PALETTE_END = 0x050001FF;
pub const OBJ_PALETTE_END = 0x050003FF;
pub const VRAM_END = 0x06017FFF;
pub const OAM_END = 0x070003FF;
pub const SRAM_END = 0x0E00FFFF;
pub const ROM_END = 0x0DFFFFFF;

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
            E_WRAM_START...E_WRAM_END => writel(&self.e_wram, (addr - 0x02000000) % E_WRAM_SIZE, value, length),
            I_WRAM_START...I_WRAM_END => writel(&self.i_wram, (addr - 0x03000000) % I_WRAM_SIZE, value, length),
            IOR_START...IOR_END => io.writeIOR(&self.io_registers, addr, value, length, false),
            BG_PALETTE_START...BG_PALETTE_END => writel(&self.bg_palette, addr - 0x05000000, value, length),
            OBJ_PALETTE_START...OBJ_PALETTE_END => writel(&self.obj_palette, addr - 0x05000200, value, length),
            VRAM_START...VRAM_END => writel(&self.vram, addr - 0x06000000, value, length),
            OAM_START...OAM_END => writel(&self.oam, addr - 0x07000000, value, length),
            SRAM_START...SRAM_END => writel(&self.sram, addr - 0x0E000000, value, length),
            else => log.err("Attempted to write illegal memory address {X}", .{addr}),
        }
    }

    pub fn read(self: *MemoryMap, addr: u32, comptime length: Length) LengthType(length) {
        return reader_blk: switch (addr) {
            BIOS_START...BIOS_END => break :reader_blk readl(&self.bios, addr, length),
            E_WRAM_START...E_WRAM_END => break :reader_blk readl(&self.e_wram, (addr - 0x02000000) % E_WRAM_SIZE, length),
            I_WRAM_START...I_WRAM_END => break :reader_blk readl(&self.i_wram, (addr - 0x03000000) % I_WRAM_SIZE, length),
            IOR_START...IOR_END => break :reader_blk io.readIOR(&self.io_registers, addr, length, false),
            BG_PALETTE_START...BG_PALETTE_END => break :reader_blk readl(&self.bg_palette, addr - 0x05000000, length),
            OBJ_PALETTE_START...OBJ_PALETTE_END => break :reader_blk readl(&self.obj_palette, addr - 0x05000200, length),
            VRAM_START...VRAM_END => break :reader_blk readl(&self.vram, addr - 0x06000000, length),
            OAM_START...OAM_END => break :reader_blk readl(&self.oam, addr - 0x07000000, length),
            ROM_START...ROM_END => {
                const rom_addr: u32 = @intCast((addr - 0x08000000) % ROM_SIZE);

                break :reader_blk readl(&self.rom, rom_addr, length);
            },
            SRAM_START...SRAM_END => break :reader_blk readl(&self.sram, addr - 0x0E000000, length),
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
