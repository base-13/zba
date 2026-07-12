const std = @import("std");
const io = @import("io.zig");

const log = std.log.scoped(.memory);

fn write32(region: []u8, addr: u32, value: u32) void {
    std.mem.writeInt(u32, region[addr..][0..4], value, .little);
}

fn read32(region: []u8, addr: u32, value: u32) u32 {
    return std.mem.readInt(u32, region[addr..][0..4], value, .little);
}

pub const MemoryMap = struct {
    bios: [16 * 1024]u8, // 16 KiB

    i_wram: [32 * 1024]u8, // 32 KiB
    e_wram: [256 * 1024]u8, // 256 KiB
    vram: [96 * 1024]u8, // 96 KiB

    bg_palette: [512]u8, // 512 B
    obj_palette: [512]u8, // 512 B
    oam: [1024]u8, // 1 KiB

    rom: [32 * 1024 ** 2]u8, // 32 MiB

    sram: [64 * 1024]u8, // 64 KiB

    io_registers: io.IORegisters,

    pub fn write(self: *MemoryMap, addr: u32, value: u32) void {
        switch (addr) {
            0x00000000...0x00003FFF => write32(&self.bios, addr, value),
            0x02000000...0x0203FFFF => write32(&self.i_wram, addr - 0x02000000, value),
            0x03000000...0x03007FFF => write32(&self.e_wram, addr - 0x03000000, value),
            0x04000000...0x040003FE => log.warn("Write to IOR at {x} to be implemented later", .{addr}),
            0x05000000...0x050001FF => write32(&self.bg_palette, addr - 0x05000000, value),
            0x05000200...0x050003FF => write32(&self.obj_palette, addr - 0x05000200, value),
            0x06000000...0x06017FFF => write32(&self.vram, addr - 0x06000000, value),
            0x07000000...0x070003FF => write32(&self.oam, addr - 0x07000000, value),
            0x08000000...0x0DFFFFFF => {
                const rom_addr = (addr - 0x08000000) % self.rom.len;

                write32(&self.rom, rom_addr, value);
            },
            0x0E000000...0x0E00FFFF => write32(&self.sram, addr - 0x0E000000, value),
            else => log.err("Attempted to write illegal memory address {x}", .{addr}),
        }
    }

    pub fn read(self: *MemoryMap, addr: u32) u32 {
        return read_blk: switch (addr) {
            0x00000000...0x00003FFF => break :read_blk read32(&self.bios, addr),
            0x02000000...0x0203FFFF => break :read_blk read32(&self.i_wram, addr - 0x02000000),
            0x03000000...0x03007FFF => break :read_blk read32(&self.e_wram, addr - 0x03000000),
            0x04000000...0x040003FE => {
                log.warn("Read IOR at {x} to be implemented later", .{addr});
                break :read_blk 0;
            },
            0x05000000...0x050001FF => break :read_blk read32(&self.bg_palette, addr - 0x05000000),
            0x05000200...0x050003FF => break :read_blk read32(&self.obj_palette, addr - 0x05000200),
            0x06000000...0x06017FFF => break :read_blk read32(&self.vram, addr - 0x06000000),
            0x07000000...0x070003FF => break :read_blk read32(&self.oam, addr - 0x07000000),
            0x08000000...0x0DFFFFFF => {
                const rom_addr = (addr - 0x08000000) % self.rom.len;

                break :read_blk read32(&self.rom, rom_addr);
            },
            0x0E000000...0x0E00FFFF => break :read_blk read32(&self.sram, addr - 0x0E000000),
            else => {
                log.err("Attempted to read illegal memory address {x}", .{addr});
                break :read_blk 0;
            },
        };
    }
};
