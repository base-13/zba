const std = @import("std");
const is = @import("instruction_set.zig");

const log = std.log.scoped(.decoder);

fn getNBits(instr: u32, start: u5, n: u5, T: type) T {
    return @intCast((instr >> start) & ((@as(u32, 1) << n) - 1));
}

const InstrDecodeError = error{InvalidInstruction};

fn decodeCondition(instr: u32) InstrDecodeError!is.Condition {
    const cond = getNBits(instr, 28, 4, u4);

    if (cond == 0b1111) return InstrDecodeError.InvalidInstruction;

    return @enumFromInt(cond);
}

fn decodeDataProcInstr(instr: u32) InstrDecodeError!is.DataProcInstr {
    if (getNBits(instr, 26, 2, u2) != 0) return InstrDecodeError.InvalidInstruction;

    const imm_flag = getNBits(instr, 25, 1, u1) == 1;

    var op2: is.DataProcInstrOps.Operand2 = undefined;

    if (imm_flag) {
        op2 = .{
            .imm_operand = .{
                .rotate = getNBits(instr, 8, 4, u4),
                .imm = getNBits(instr, 0, 8, u8),
            },
        };
    } else {
        var shift: is.DataProcInstrOps.Operand2RegShift = undefined;

        if (getNBits(instr, 4, 1, u1) == 1) {
            if (getNBits(instr, 7, 1, u1) != 0) return InstrDecodeError.InvalidInstruction;

            shift = .{ .rs = getNBits(instr, 8, 4, u4) };
        } else {
            shift = .{ .shift_amount = getNBits(instr, 7, 5, u5) };
        }

        op2 = .{
            .reg_operand = .{
                .shift = shift,
                .shift_type = @enumFromInt(getNBits(instr, 5, 2, u2)),
                .rm = getNBits(instr, 0, 4, u4),
            },
        };
    }

    const opcode: is.DataProcInstrOps.Opcode = @enumFromInt(getNBits(instr, 21, 4, u4));
    const set_cond_flag = switch (opcode) {
        .TEQ, .TST, .CMP, .CMN => true,
        else => getNBits(instr, 20, 1, u1) == 1,
    };

    return .{
        .imm_flag = imm_flag,
        .opcode = opcode,
        .set_cond_flag = set_cond_flag,
        .rn = getNBits(instr, 16, 4, u4),
        .rd = getNBits(instr, 12, 4, u4),
        .op2 = op2,
    };
}

fn decodeBranchWithLinkInstr(instr: u32) InstrDecodeError!is.BranchWithLink {
    if (getNBits(instr, 25, 3, u3) != 0b101)
        return InstrDecodeError.InvalidInstruction;

    return .{
        .link = getNBits(instr, 24, 1, u1) == 1,
        .offset = @bitCast(getNBits(instr, 0, 24, u24)),
    };
}

fn decodeMultiplyInstr(instr: u32) InstrDecodeError!is.MultiplyInstr {
    if (getNBits(instr, 22, 6, u6) != 0) return InstrDecodeError.InvalidInstruction;
    if (getNBits(instr, 4, 4, u4) != 0b1001) return InstrDecodeError.InvalidInstruction;

    const rd = getNBits(instr, 16, 4, u4);
    const rn = getNBits(instr, 12, 4, u4);
    const rs = getNBits(instr, 8, 4, u4);
    const rm = getNBits(instr, 0, 4, u4);

    if (rd == rm)
        log.warn("Invalid registers: Rd and Rm must be different", .{});
    if (rd == 15 or rn == 15 or rs == 15 or rm == 15)
        log.warn("Invalid registers: R15 can't be used", .{});

    return .{
        .acc_flag = getNBits(instr, 21, 1, u1) == 1,
        .set_cond_flag = getNBits(instr, 20, 1, u1) == 1,
        .rd = rd,
        .rn = rn,
        .rs = rs,
        .rm = rm,
    };
}

fn decodeMultiplyLongInstr(instr: u32) InstrDecodeError!is.MultiplyLongInstr {
    if (getNBits(instr, 23, 5, u5) != 1) return InstrDecodeError.InvalidInstruction;
    if (getNBits(instr, 4, 4, u4) != 0b1001) return InstrDecodeError.InvalidInstruction;

    const rd_high = getNBits(instr, 16, 4, u4);
    const rd_low = getNBits(instr, 12, 4, u4);
    const rs = getNBits(instr, 8, 4, u4);
    const rm = getNBits(instr, 0, 4, u4);

    if (rd_high == rd_low or rd_high == rm or rd_low == rm)
        log.warn("Invalid registers: RdHi, RdLo, Rm must be different", .{});
    if (rd_high == 15 or rd_low == 15 or rs == 15 or rm == 15)
        log.warn("Invalid registers: R15 can't be used", .{});

    return .{
        .signed = getNBits(instr, 22, 1, u1) == 1,
        .acc_flag = getNBits(instr, 21, 1, u1) == 1,
        .set_cond_flag = getNBits(instr, 20, 1, u1) == 1,
        .rd_high = rd_high,
        .rd_low = rd_low,
        .rs = rs,
        .rm = rm,
    };
}

pub fn decode(instr: u32) InstrDecodeError!is.Instr {
    const cond = try decodeCondition(instr);
    var fields: is.Fields = undefined;

    const multiply_bitmask = 0b0000_111111_00000000000000_1111_0000;
    const multiply_test = 0b0000_000000_00000000000000_1001_0000;

    const multiply_long_bitmask = 0b0000_11111_000000000000000_1111_0000;
    const multiply_long_test = 0b0000_00001_000000000000000_1001_0000;

    const data_proc_bitmask = 0b0000_11_00000000000000000000000000;
    const data_proc_test = 0b0000_00_00000000000000000000000000;

    const branch_with_link_bitmask = 0b0000_111_0000000000000000000000000;
    const branch_with_link_test = 0b0000_101_0000000000000000000000000;

    if (instr & multiply_bitmask == multiply_test)
        fields = .{ .multiply = try decodeMultiplyInstr(instr) }
    else if (instr & multiply_long_bitmask == multiply_long_test)
        fields = .{ .multiply_long = try decodeMultiplyLongInstr(instr) }
    else if (instr & data_proc_bitmask == data_proc_test)
        fields = .{ .data_proc = try decodeDataProcInstr(instr) }
    else if (instr & branch_with_link_bitmask == branch_with_link_test)
        fields = .{ .branch_with_link = try decodeBranchWithLinkInstr(instr) }
    else
        return InstrDecodeError.InvalidInstruction;

    return .{
        .cond = cond,
        .fields = fields,
    };
}
