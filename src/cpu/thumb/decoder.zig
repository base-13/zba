const is = @import("../instruction_set.zig");
const getNBits = @import("../utils.zig").getNBits;

pub const InstrDecodeError = error{InvalidInstruction};

fn decodeMoveRegisterTInstr(instr: u16) InstrDecodeError!is.MoveRegisterTInstr {
    const opcode: is.MoveRegisterTInstrOpcode = @enumFromInt(getNBits(instr, 11, 2, u2));

    if (opcode == .Invalid)
        return InstrDecodeError.InvalidInstruction;

    return .{
        .opcode = opcode,
        .offset = getNBits(instr, 6, 5, u5),
        .rs = getNBits(instr, 3, 3, u3),
        .rd = getNBits(instr, 0, 3, u3),
    };
}

fn decodeAddSubTInstr(instr: u16) is.AddSubTInstr {
    return .{
        .imm_flag = getNBits(instr, 10, 1, u1) == 1,
        .sub = getNBits(instr, 9, 1, u1) == 1,
        .op2 = getNBits(instr, 6, 3, u3),
        .rs = getNBits(instr, 3, 3, u3),
        .rd = getNBits(instr, 0, 3, u3),
    };
}

pub fn decode(instr: u16) InstrDecodeError!is.ThumbInstr {
    var decoded_instr: is.ThumbInstr = undefined;

    const software_interrupt_bitmask = 0b11111111_00000000;
    const software_interrupt_test = 0b11011111_00000000;

    const add_sub_bitmask = 0b11111_00000000000;
    const add_sub_test = 0b00011_00000000000;

    const move_register_bitmask = 0b111_0000000000000;
    const move_register_test = 0b000_0000000000000;

    if (instr & software_interrupt_bitmask == software_interrupt_test)
        decoded_instr = .{ .software_interrupt = .{} }
    else if (instr & add_sub_bitmask == add_sub_test)
        decoded_instr = .{ .add_sub = decodeAddSubTInstr(instr) }
    else if (instr & move_register_bitmask == move_register_test)
        decoded_instr = .{ .move_register = try decodeMoveRegisterTInstr(instr) }
    else
        return InstrDecodeError.InvalidInstruction;

    return decoded_instr;
}
