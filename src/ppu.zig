const rl = @import("raylib");
const cpu = @import("cpu/cpu.zig");

const IORegisters = @import("io.zig").IORegisters;

const BG_PALETTE: u32 = 0x05000000;
const VRAM: u32 = 0x06000000;

pub fn updateVCount(v_count: u8) void {
    cpu.getMemoryMap().hWriteIOR(IORegisters.VCOUNT, v_count, .HalfWord);
}

pub fn setVBlank(status: bool) void {
    const memory_map = cpu.getMemoryMap();

    const dispstat = memory_map.hReadIOR(IORegisters.DISPSTAT, .HalfWord);
    // set bit 0 of DISPSTAT
    memory_map.hWriteIOR(IORegisters.DISPSTAT, dispstat | @intFromBool(status), .HalfWord);
}

pub fn sendVBlankIRQ() void {
    const memory_map = cpu.getMemoryMap();

    // set bit 0 of IF if bit 3 of DISPSTAT is 1
    if (memory_map.hReadIOR(IORegisters.DISPSTAT, .HalfWord) & 0b100 == 0b100) {
        const if_value = memory_map.hReadIOR(IORegisters.IF, .HalfWord);

        memory_map.hWriteIOR(IORegisters.IF, if_value | 0b1, .HalfWord);
    }
}

fn raylibColorFromRGB555(r: u5, g: u5, b: u5) rl.Color {
    return .{
        .a = 255,
        .r = r * (255 / 31),
        .g = g * (255 / 31),
        .b = b * (255 / 31),
    };
}

// currently we are only rendering in mode 4
pub fn drawFrame() void {
    const memory_map = cpu.getMemoryMap();

    const dispcnt = memory_map.hReadIOR(IORegisters.DISPCNT, .Word);
    const page: u32 = (dispcnt >> 4) & 1;

    const framebuf_start_addr = VRAM + (0xA000 * page);

    for (0..160) |y| {
        for (0..240) |x| {
            var color: rl.Color = undefined;

            const vram_offset: u32 = @intCast(x + y);
            const palette_index = memory_map.read(framebuf_start_addr + vram_offset, .Byte);

            // palette index 0 is always transparent
            if (palette_index == 0) {
                color = .{
                    .a = 0,
                    .r = 0,
                    .g = 0,
                    .b = 0,
                };
            } else {
                const palette = memory_map.read(BG_PALETTE + 2 * palette_index, .HalfWord);

                color = raylibColorFromRGB555(
                    @truncate(palette),
                    @truncate(palette >> 5),
                    @truncate(palette >> 10),
                );
            }

            rl.drawPixel(@intCast(x), @intCast(y), color);
        }
    }
}
