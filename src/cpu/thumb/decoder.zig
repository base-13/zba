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

fn decodeMovCmpAddSub8TInstr(instr: u16) is.MovCmpAddSub8TInstr {
    return .{
        .opcode = @enumFromInt(getNBits(instr, 11, 2, u2)),
        .rd = getNBits(instr, 8, 3, u3),
        .offset = getNBits(instr, 0, 8, u8),
    };
}

fn decodeALUOpsTInstr(instr: u16) is.ALUOpsTInstr {
    return .{
        .opcode = @enumFromInt(getNBits(instr, 6, 4, u4)),
        .rs = getNBits(instr, 3, 3, u3),
        .rd = getNBits(instr, 0, 3, u3),
    };
}

fn decodePCRelLoadTInstr(instr: u16) is.PCRelLoadTInstr {
    return .{
        .rd = getNBits(instr, 8, 3, u3),
        .offset = getNBits(instr, 0, 8, u8),
    };
}

fn decodeAddOffsetToSPTInstr(instr: u16) is.AddOffsetToSPTInstr {
    return .{
        .neg = getNBits(instr, 7, 1, u1) == 1,
        .offset = getNBits(instr, 0, 7, u7),
    };
}

fn decodeUnconditionalBranchTInstr(instr: u16) is.UnconditionalBranchTInstr {
    return .{ .offset = @bitCast(getNBits(instr, 0, 11, u11)) };
}

fn decodeSPRelLoadStoreTInstr(instr: u16) is.SPRelLoadStoreTInstr {
    return .{
        .load = getNBits(instr, 11, 1, u1) == 1,
        .rd = getNBits(instr, 8, 3, u3),
        .offset = getNBits(instr, 0, 8, u8),
    };
}

fn decodeConditionalBranchTInstr(instr: u16) is.InstrDecodeError!is.ConditionalBranchTInstr {
    const cond: is.Condition = @enumFromInt(getNBits(instr, 8, 4, u4));

    if (cond == .AL) return is.InstrDecodeError.InvalidInstruction;

    return .{
        .cond = cond,
        .offset = @bitCast(getNBits(instr, 0, 8, u8)),
    };
}

fn decodeLoadAddressTInstr(instr: u16) is.LoadAddressTInstr {
    return .{
        .sp = getNBits(instr, 11, 1, u1) == 1,
        .rd = getNBits(instr, 8, 3, u3),
        .offset = getNBits(instr, 0, 8, u8),
    };
}

fn decodePushPopTInstr(instr: u16) is.PushPopTInstr {
    var r_list: [8]bool = undefined;

    for (0..16) |i|
        r_list[i] = getNBits(instr, @intCast(i), 1, u1) == 1;

    return .{
        .load = getNBits(instr, 11, 1, u1) == 1,
        .pc_lr = getNBits(instr, 8, 1, u1) == 1,
        .r_list = r_list,
    };
}

fn decodeHiRegOpsAndBXTInstr(instr: u16) is.HiRegOpsAndBXTInstr {
    return .{
        .opcode = @enumFromInt(getNBits(instr, 8, 2, u2)),
        .h1 = getNBits(instr, 7, 1, u1) == 1,
        .h2 = getNBits(instr, 6, 1, u1) == 1,
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

    const mov_cmp_add_sub8_bitmask = 0b111_0000000000000;
    const mov_cmp_add_sub8_test = 0b001_0000000000000;

    const alu_ops_bitmask = 0b111111_0000000000;
    const alu_ops_test = 0b010000_0000000000;

    const pc_rel_load_bitmask = 0b11111_00000000000;
    const pc_rel_load_test = 0b01001_00000000000;

    const sp_rel_load_store_bitmask = 0b1111_000000000000;
    const sp_rel_load_store_test = 0b1001_000000000000;

    const add_offset_to_sp_bitmask = 0b11111111_00000000;
    const add_offset_to_sp_test = 0b10110000_00000000;

    const uncondtional_branch_bitmask = 0b11111_00000000000;
    const uncondtional_branch_test = 0b11100_00000000000;

    const conditional_branch_bitmask = 0b1111_000000000000;
    const conditional_branch_test = 0b1101_000000000000;

    const load_address_bitmask = 0b1111_000000000000;
    const load_address_test = 0b1010_000000000000;

    const push_pop_bitmask = 0b1111_0_11_000000000;
    const push_pop_test = 0b1011_0_10_000000000;

    const hi_reg_ops_and_bx_bitmask = 0b111111_0000000000;
    const hi_reg_ops_and_bx_test = 0b010001_0000000000;

    if (instr & software_interrupt_bitmask == software_interrupt_test)
        decoded_instr = .{ .software_interrupt = .{} }
    else if (instr & add_sub_bitmask == add_sub_test)
        decoded_instr = .{ .add_sub = decodeAddSubTInstr(instr) }
    else if (instr & move_register_bitmask == move_register_test)
        decoded_instr = .{ .move_register = try decodeMoveRegisterTInstr(instr) }
    else if (instr & mov_cmp_add_sub8_bitmask == mov_cmp_add_sub8_test)
        decoded_instr = .{ .mov_cmp_add_sub8 = decodeMovCmpAddSub8TInstr(instr) }
    else if (instr & alu_ops_bitmask == alu_ops_test)
        decoded_instr = .{ .alu_ops = decodeALUOpsTInstr(instr) }
    else if (instr & pc_rel_load_bitmask == pc_rel_load_test)
        decoded_instr = .{ .pc_rel_load = decodePCRelLoadTInstr(instr) }
    else if (instr & sp_rel_load_store_bitmask == sp_rel_load_store_test)
        decoded_instr = .{ .sp_rel_load_store = decodeSPRelLoadStoreTInstr(instr) }
    else if (instr & add_offset_to_sp_bitmask == add_offset_to_sp_test)
        decoded_instr = .{ .add_offset_to_sp = decodeAddOffsetToSPTInstr(instr) }
    else if (instr & uncondtional_branch_bitmask == uncondtional_branch_test)
        decoded_instr = .{ .unconditional_branch = decodeUnconditionalBranchTInstr(instr) }
    else if (instr & conditional_branch_bitmask == conditional_branch_test)
        decoded_instr = .{ .conditional_branch = try decodeConditionalBranchTInstr(instr) }
    else if (instr & load_address_bitmask == load_address_test)
        decoded_instr = .{ .load_address = decodeLoadAddressTInstr(instr) }
    else if (instr & push_pop_bitmask == push_pop_test)
        decoded_instr = .{ .push_pop = decodePushPopTInstr(instr) }
    else if (instr & hi_reg_ops_and_bx_bitmask == hi_reg_ops_and_bx_test)
        decoded_instr = .{ .hi_reg_ops_and_bx = decodeHiRegOpsAndBXTInstr(instr) }
    else
        return InstrDecodeError.InvalidInstruction;

    return decoded_instr;
}
