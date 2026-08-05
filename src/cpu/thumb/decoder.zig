const is = @import("../instruction_set.zig");

pub const InstrDecodeError = error{InvalidInstruction};

pub fn decode(instr: u16) InstrDecodeError!is.ThumbInstr {
    var decoded_instr: is.ThumbInstr = undefined;

    const software_interrupt_bitmask = 0b11111111_00000000;
    const software_interrupt_test = 0b11011111_00000000;

    if (instr & software_interrupt_bitmask == software_interrupt_test)
        decoded_instr = .{ .software_interrupt = .{} }
    else
        return InstrDecodeError.InvalidInstruction;

    return decoded_instr;
}
