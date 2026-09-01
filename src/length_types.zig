const std = @import("std");

pub const Length = enum(u3) {
    Byte = 1,
    HalfWord = 2,
    Word = 4,
};

pub fn LengthType(comptime length: Length) type {
    return switch (length) {
        .Byte => u8,
        .HalfWord => u16,
        .Word => u32,
    };
}
