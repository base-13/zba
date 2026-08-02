const std = @import("std");
const is = @import("instruction_set.zig");

const log = std.log.scoped(.decoder);

fn getNBits(instr: u32, start: u5, n: u5, T: type) T {
    return @intCast((instr >> start) & ((@as(u32, 1) << n) - 1));
}

pub const InstrDecodeError = error{InvalidInstruction};

fn decodeCondition(instr: u32) InstrDecodeError!is.Condition {
    const cond = getNBits(instr, 28, 4, u4);

    if (cond == 0b1111) return InstrDecodeError.InvalidInstruction;

    return @enumFromInt(cond);
}

fn decodeRegOffset(offset: u12) InstrDecodeError!is.OffsetOperand.Operand {
    var op2: is.OffsetOperand.Operand = undefined;

    var shift: is.OffsetOperand.RegOffsetShift = undefined;

    if (getNBits(offset, 4, 1, u1) == 1) {
        if (getNBits(offset, 7, 1, u1) != 0) return InstrDecodeError.InvalidInstruction;

        shift = .{ .rs = getNBits(offset, 8, 4, u4) };
    } else {
        shift = .{ .shift_amount = getNBits(offset, 7, 5, u5) };
    }

    op2 = .{
        .reg_operand = .{
            .shift = shift,
            .shift_type = @enumFromInt(getNBits(offset, 5, 2, u2)),
            .rm = getNBits(offset, 0, 4, u4),
        },
    };

    return op2;
}

fn decodeDataProcInstr(instr: u32) InstrDecodeError!is.DataProcInstr {
    const imm_flag = getNBits(instr, 25, 1, u1) == 1;
    var op2: is.OffsetOperand.Operand = undefined;

    if (imm_flag) {
        op2 = .{
            .rotated_imm_operand = .{
                .rotate = getNBits(instr, 8, 4, u4),
                .imm = getNBits(instr, 0, 8, u8),
            },
        };
    } else {
        op2 = try decodeRegOffset(getNBits(instr, 0, 12, u12));
    }

    const opcode: is.DataProcInstrOpcode = @enumFromInt(getNBits(instr, 21, 4, u4));
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

fn decodeBranchWithLinkInstr(instr: u32) is.BranchWithLink {
    return .{
        .link = getNBits(instr, 24, 1, u1) == 1,
        .offset = @bitCast(getNBits(instr, 0, 24, u24)),
    };
}

fn decodeMultiplyInstr(instr: u32) is.MultiplyInstr {
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

fn decodeMultiplyLongInstr(instr: u32) is.MultiplyLongInstr {
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

fn decodePSRTransferInstr(instr: u32) InstrDecodeError!is.PSRTransferInstr {
    const mrs_bitmask = 0b0000_11111_0_111111_0000_111111111111;
    const mrs_test = 0b0000_00010_0_001111_0000_000000000000;

    const cpsr = getNBits(instr, 22, 1, u1) == 0;

    if (instr & mrs_bitmask == mrs_test) {
        const rd = getNBits(instr, 12, 4, u4);
        if (rd == 15) log.warn("Invalid registers: R15 can't be used", .{});

        return .{
            .cpsr = cpsr,
            .type = .{ .mrs = .{ .rd = rd } },
        };
    } else {
        const imm_flag = getNBits(instr, 25, 1, u1) == 1;

        const update_cond_fields = getNBits(instr, 19, 1, u1) == 1;
        const update_ext_fields = getNBits(instr, 18, 1, u1) == 1;
        const update_status_fields = getNBits(instr, 17, 1, u1) == 1;
        const update_control_fields = getNBits(instr, 16, 1, u1) == 1;

        if (update_ext_fields)
            log.warn("PSR_x bits are reserved, they will not be updated", .{});
        if (update_status_fields)
            log.warn("PSR_s bits are reserved, they will not be updated", .{});

        if (imm_flag)
            return .{
                .cpsr = cpsr,
                .update_control_fields = update_control_fields,
                .update_cond_fields = update_cond_fields,
                .type = .{ .msr = .{
                    .imm_flag = imm_flag,
                    .rotate = getNBits(instr, 8, 4, u4),
                    .imm = getNBits(instr, 0, 8, u8),
                } },
            }
        else {
            if (getNBits(instr, 4, 8, u8) != 0)
                return InstrDecodeError.InvalidInstruction;

            const rm = getNBits(instr, 0, 4, u4);
            if (rm == 15) log.warn("Invalid registers: R15 can't be used", .{});

            return .{
                .cpsr = cpsr,
                .update_control_fields = update_control_fields,
                .update_cond_fields = update_cond_fields,
                .type = .{ .msr = .{
                    .imm_flag = imm_flag,
                    .rm = rm,
                } },
            };
        }
    }
}

fn decodeSingleDataSwapInstr(instr: u32) is.SingleDataSwapInstr {
    const rn = getNBits(instr, 16, 4, u4);
    const rd = getNBits(instr, 12, 4, u4);
    const rm = getNBits(instr, 0, 4, u4);

    if ((rn == 15) or
        (rd == 15) or
        (rm == 15))
        log.warn("Invalid registers: R15 can't be used", .{});

    return .{
        .swap_byte = getNBits(instr, 22, 1, u1) == 1,
        .rn = rn,
        .rd = rd,
        .rm = rm,
    };
}

fn decodeSingleDataTransferInstr(instr: u32) InstrDecodeError!is.SingleDataTransferInstr {
    const imm_flag = getNBits(instr, 25, 1, u1) == 1;
    var op2: is.OffsetOperand.Operand = undefined;

    if (imm_flag)
        op2 = try decodeRegOffset(getNBits(instr, 0, 12, u12))
    else
        op2 = .{ .imm_operand = getNBits(instr, 0, 12, u12) };

    return .{
        .imm_flag = imm_flag,
        .pre_index = getNBits(instr, 24, 1, u1) == 1,
        .add_offset = getNBits(instr, 23, 1, u1) == 1,
        .transfer_byte = getNBits(instr, 22, 1, u1) == 1,
        .write_back = getNBits(instr, 21, 1, u1) == 1,
        .load = getNBits(instr, 20, 1, u1) == 1,
        .rn = getNBits(instr, 16, 4, u4),
        .rd = getNBits(instr, 12, 4, u4),
        .op2 = op2,
    };
}

fn decodeHAndSDataTransferInstr(instr: u32) InstrDecodeError!is.HAndSDataTransferInstr {
    const imm_flag = getNBits(instr, 22, 1, u1) == 1;
    var op2: is.OffsetOperand.HAndSDataTransferOperand = undefined;

    if (imm_flag) {
        const offset = (getNBits(instr, 8, 4, u8) << 4) | getNBits(instr, 0, 4, u4);
        op2 = .{ .offset = offset };
    } else {
        op2 = .{ .rm = getNBits(instr, 0, 4, u4) };
    }

    const sh = getNBits(instr, 5, 2, u2);
    if (sh == 0b00) return InstrDecodeError.InvalidInstruction;

    return .{
        .pre_index = getNBits(instr, 24, 1, u1) == 1,
        .add_offset = getNBits(instr, 23, 1, u1) == 1,
        .imm_flag = imm_flag,
        .write_back = getNBits(instr, 21, 1, u1) == 1,
        .load = getNBits(instr, 20, 1, u1) == 1,
        .rn = getNBits(instr, 16, 4, u4),
        .rd = getNBits(instr, 12, 4, u4),
        .sh = sh,
        .op2 = op2,
    };
}

fn decodeBlockDataTransferInstr(instr: u32) is.BlockDataTransferInstr {
    var r_list: [16]bool = undefined;

    for (0..16) |i|
        r_list[i] = getNBits(instr, @intCast(i), 1, u1) == 1;

    return .{
        .pre_index = getNBits(instr, 24, 1, u1) == 1,
        .add_offset = getNBits(instr, 23, 1, u1) == 1,
        .force_user = getNBits(instr, 22, 1, u1) == 1,
        .write_back = getNBits(instr, 21, 1, u1) == 1,
        .load = getNBits(instr, 20, 1, u1) == 1,
        .rn = getNBits(instr, 16, 4, u4),
        .r_list = r_list,
    };
}

fn checkPSRTransferInstr(instr: u32) bool {
    const mrs_bitmask = 0b0000_11111_0_111111_0000_111111111111;
    const mrs_test = 0b0000_00010_0_001111_0000_000000000000;

    const msr_bitmask = 0b0000_11_0_11_0_11_0000_1111_00000000_0000;
    const msr_test = 0b0000_00_0_10_0_10_0000_1111_00000000_0000;

    return (instr & mrs_bitmask == mrs_test) or (instr & msr_bitmask == msr_test);
}

pub fn decode(instr: u32) InstrDecodeError!is.Instr {
    const cond = try decodeCondition(instr);
    var fields: is.Fields = undefined;

    const multiply_bitmask = 0b0000_111111_00000000000000_1111_0000;
    const multiply_test = 0b0000_000000_00000000000000_1001_0000;

    const multiply_long_bitmask = 0b0000_11111_000000000000000_1111_0000;
    const multiply_long_test = 0b0000_00001_000000000000000_1001_0000;

    const single_data_swap_bitmask = 0b0000_11111_0_11_00000000_1111_1111_0000;
    const single_data_swap_test = 0b0000_00010_0_00_00000000_0000_1001_0000;

    const data_proc_bitmask = 0b0000_11_00000000000000000000000000;
    const data_proc_test = 0b0000_00_00000000000000000000000000;

    const single_data_transfer_bitmask = 0b0000_11_00000000000000000000000000;
    const single_data_transfer_test = 0b0000_01_00000000000000000000000000;

    const branch_with_link_bitmask = 0b0000_111_0000000000000000000000000;
    const branch_with_link_test = 0b0000_101_0000000000000000000000000;

    const block_data_transfer_bitmask = 0b0000_111_0000000000000000000000000;
    const block_data_transfer_test = 0b0000_100_0000000000000000000000000;

    const software_interrupt_bitmask = 0b0000_1111_000000000000000000000000;
    const software_interrupt_test = 0b0000_1111_000000000000000000000000;

    const h_and_s_data_transfer_bitmask = 0b0000_111_00000000000000000_1_00_1_0000;
    const h_and_s_data_transfer_test = 0b0000_000_00000000000000000_1_00_1_0000;

    if (instr & software_interrupt_bitmask == software_interrupt_test)
        fields = .{ .software_interrupt = .{} }
    else if (instr & multiply_bitmask == multiply_test)
        fields = .{ .multiply = decodeMultiplyInstr(instr) }
    else if (instr & multiply_long_bitmask == multiply_long_test)
        fields = .{ .multiply_long = decodeMultiplyLongInstr(instr) }
    else if (instr & single_data_swap_bitmask == single_data_swap_test)
        fields = .{ .single_data_swap = decodeSingleDataSwapInstr(instr) }
    else if (instr & h_and_s_data_transfer_bitmask == h_and_s_data_transfer_test)
        fields = .{ .h_and_s_data_transfer = try decodeHAndSDataTransferInstr(instr) }
    else if (checkPSRTransferInstr(instr))
        fields = .{ .psr_transfer = try decodePSRTransferInstr(instr) }
    else if (instr & data_proc_bitmask == data_proc_test)
        fields = .{ .data_proc = try decodeDataProcInstr(instr) }
    else if (instr & single_data_transfer_bitmask == single_data_transfer_test)
        fields = .{ .single_data_transfer = try decodeSingleDataTransferInstr(instr) }
    else if (instr & branch_with_link_bitmask == branch_with_link_test)
        fields = .{ .branch_with_link = decodeBranchWithLinkInstr(instr) }
    else if (instr & block_data_transfer_bitmask == block_data_transfer_test)
        fields = .{ .block_data_transfer = decodeBlockDataTransferInstr(instr) }
    else
        return InstrDecodeError.InvalidInstruction;

    return .{
        .cond = cond,
        .fields = fields,
    };
}
