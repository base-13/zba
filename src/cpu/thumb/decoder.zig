const is = @import("../instruction_set.zig");

pub const InstrDecodeError = error{InvalidInstruction};

pub fn decode(instr: u16) InstrDecodeError!is.ThumbInstr {
    _ = instr;
    return .{};
}
