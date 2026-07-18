const std = @import("std");
const is = @import("instruction_set.zig");
const cpu_state = @import("../cpu_state.zig");
const memory = @import("../../memory.zig");

const log = std.log.scoped(.exec);

fn rotateRight(x: u32, n: u32) u32 {
    const shift: u5 = @intCast(n);

    const inv: u5 = @intCast((32 - n) & 31);

    return (x >> shift) | (x << inv);
}

pub fn checkCondition(instr: is.Instr, registers: *cpu_state.Reigsters) bool {
    const zero = registers.cpsr.zero_flag;
    const carry = registers.cpsr.carry_flag;
    const neg = registers.cpsr.neg_flag;
    const overflow = registers.cpsr.overflow_flag;

    return switch (instr.cond) {
        .EQ => zero,
        .NE => !zero,
        .CS => carry,
        .CC => !carry,
        .MI => neg,
        .PL => !neg,
        .VS => overflow,
        .VC => !overflow,
        .HI => carry and !zero,
        .LS => !carry and zero,
        .GE => neg == overflow,
        .LT => neg != overflow,
        .GT => !zero and neg == overflow,
        .LE => neg or neg != overflow,
        .AL => true,
    };
}

fn calcRegOffset(offset_operand: is.OffsetOperand.Operand, registers: *cpu_state.Reigsters) struct { u32, ?bool } {
    var offset: u32 = undefined;
    var shifter_carry: ?bool = null;

    const rm_content = registers.get(offset_operand.reg_operand.rm);

    var shift: u32 = undefined;
    var to_shift = true;

    switch (offset_operand.reg_operand.shift) {
        .shift_amount => |shift_amount| shift = shift_amount,
        .rs => |rs| {
            shift = registers.get(rs) & 0xFF;

            if (shift == 0) to_shift = false;
        },
    }

    if (to_shift) {
        switch (offset_operand.reg_operand.shift_type) {
            .LogicalLeft => {
                if (shift == 0) {
                    offset = rm_content;
                } else if (shift == 32) {
                    shifter_carry = false;
                    offset = 0;
                } else if (shift > 32) {
                    shifter_carry = rm_content & 1 == 1;
                    offset = 0;
                } else {
                    shifter_carry = (rm_content >> @intCast(32 - shift)) & 1 == 1;
                    offset = rm_content << @intCast(shift);
                }
            },
            .LogicalRight => {
                if (shift == 0 or shift == 32) {
                    shifter_carry = rm_content >> 31 == 1;
                    offset = 0;
                } else if (shift > 32) {
                    shifter_carry = false;
                    offset = 0;
                } else {
                    shifter_carry = (rm_content >> @intCast(32 - shift)) & 1 == 1;
                    offset = rm_content >> @intCast(shift);
                }
            },
            .ArithmeticRight => {
                if (shift == 0 or shift > 31) {
                    shifter_carry = rm_content >> 31 == 1;
                    offset = 0xFFFF_FFFF * (rm_content >> 31);
                } else {
                    shifter_carry = (rm_content >> @intCast(shift - 1)) & 1 == 1;

                    const rm_signed: i32 = @bitCast(rm_content);
                    offset = @bitCast(rm_signed >> @intCast(shift));
                }
            },
            .RotateRight => {
                while (shift > 32) : (shift -= 32) {}

                if (shift == 0) {
                    shifter_carry = rm_content & 1 == 1;
                    offset = if (registers.cpsr.carry_flag) (rm_content >> 1) | 0x8000_0000 else rm_content >> 1;
                }
                if (shift == 32) {
                    shifter_carry = rm_content >> 1 == 1;
                    offset = rm_content;
                } else {
                    shifter_carry = (rm_content >> @intCast(shift - 1)) & 1 == 1;
                    offset = rotateRight(rm_content, shift);
                }
            },
        }
    } else {
        offset = rm_content;
    }

    return .{ offset, shifter_carry };
}

pub fn execDataProc(instr: is.DataProcInstr, registers: *cpu_state.Reigsters) void {
    var cpsr = &registers.cpsr;

    const rd = instr.rd;
    const rn_content = registers.get(instr.rn);
    var alu_carry: ?bool = null;
    var zero: ?bool = null;
    var overflow: ?bool = null;
    var negative: ?bool = null;
    var op2: u32 = undefined;
    var shifter_carry: ?bool = null;

    if (instr.imm_flag) {
        const imm = instr.op2.rotated_imm_operand.imm;
        const rotate: u32 = @intCast(instr.op2.rotated_imm_operand.rotate);

        op2 = rotateRight(imm, rotate * 2);
    } else {
        const offset_result = calcRegOffset(instr.op2, registers);
        op2 = offset_result[0];
        shifter_carry = offset_result[1];
    }

    switch (instr.opcode) {
        .AND => {
            const result = rn_content & op2;
            registers.set(rd, result);

            negative = result >> 31 == 1;
            zero = result == 0;
        },
        .EOR => {
            const result = rn_content ^ op2;
            registers.set(rd, result);

            negative = result >> 31 == 1;
            zero = result == 0;
        },
        .SUB => {
            const result = @subWithOverflow(rn_content, op2);
            registers.set(rd, result[0]);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 0;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);

            overflow = @subWithOverflow(rn_content_signed, op2_signed)[1] == 1;
        },
        .RSB => {
            const result = @subWithOverflow(op2, rn_content);
            registers.set(rd, result[0]);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 0;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);

            overflow = @subWithOverflow(op2_signed, rn_content_signed)[1] == 1;
        },
        .ADD => {
            const result = @addWithOverflow(rn_content, op2);
            registers.set(rd, result[0]);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 1;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);

            overflow = @addWithOverflow(rn_content_signed, op2_signed)[1] == 1;
        },
        .ADC => {
            const carry_in: u32 = @intFromBool(cpsr.carry_flag);

            const sum1 = @addWithOverflow(rn_content, op2);
            const result = @addWithOverflow(sum1[0], carry_in);
            registers.set(rd, result[0]);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 1 or sum1[1] == 1;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);
            const carry_in_signed: i32 = @bitCast(carry_in);

            const sum1_signed = @addWithOverflow(rn_content_signed, op2_signed);
            const result_signed = @addWithOverflow(sum1_signed[0], carry_in_signed);

            overflow = sum1_signed[1] == 1 or result_signed[1] == 1;
        },
        .SBC => {
            const carry_in: u32 = @intFromBool(cpsr.carry_flag);

            const sum1 = @subWithOverflow(rn_content, op2);
            const result = @subWithOverflow(sum1[0], carry_in);
            registers.set(rd, result[0]);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 0 or sum1[1] == 0;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);
            const carry_in_signed: i32 = @bitCast(carry_in);

            const sum1_signed = @subWithOverflow(rn_content_signed, op2_signed);
            const result_signed = @subWithOverflow(sum1_signed[0], carry_in_signed);

            overflow = sum1_signed[1] == 1 or result_signed[1] == 1;
        },
        .RSC => {
            const carry_in: u32 = @intFromBool(cpsr.carry_flag);

            const sum1 = @subWithOverflow(op2, rn_content);
            const result = @subWithOverflow(sum1[0], carry_in);
            registers.set(rd, result[0]);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 0 or sum1[1] == 0;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);
            const carry_in_signed: i32 = @bitCast(carry_in);

            const sum1_signed = @subWithOverflow(op2_signed, rn_content_signed);
            const result_signed = @subWithOverflow(sum1_signed[0], carry_in_signed);

            overflow = sum1_signed[1] == 1 or result_signed[1] == 1;
        },
        .TST => {
            const result = rn_content & op2;
            negative = result >> 31 == 1;
            zero = result == 0;

            registers.set(rd, result);
        },
        .TEQ => {
            const result = rn_content ^ op2;
            negative = result >> 31 == 1;
            zero = result == 0;

            registers.set(rd, result);
        },
        .CMP => {
            const result = @subWithOverflow(rn_content, op2);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 0;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);

            overflow = @subWithOverflow(rn_content_signed, op2_signed)[1] == 1;
        },
        .CMN => {
            const result = @addWithOverflow(rn_content, op2);

            negative = result[0] >> 31 == 1;
            alu_carry = result[1] == 1;
            zero = result[0] == 0;

            const rn_content_signed: i32 = @bitCast(rn_content);
            const op2_signed: i32 = @bitCast(op2);

            overflow = @addWithOverflow(rn_content_signed, op2_signed)[1] == 1;
        },
        .ORR => {
            const result = rn_content | op2;
            negative = result >> 31 == 1;
            zero = result == 0;

            registers.set(rd, result);
        },
        .MOV => {
            const result = op2;
            negative = result >> 31 == 1;
            zero = result == 0;

            registers.set(rd, result);
        },
        .BIC => {
            const result = rn_content & ~op2;
            negative = result >> 31 == 1;
            zero = result == 0;

            registers.set(rd, result);
        },
        .MVN => {
            const result = ~op2;
            negative = result >> 31 == 1;
            zero = result == 0;

            registers.set(rd, result);
        },
    }

    if (instr.set_cond_flag) {
        if (alu_carry == null) {
            if (shifter_carry != null) cpsr.carry_flag = shifter_carry.?;
        } else cpsr.carry_flag = alu_carry.?;

        if (zero != null) cpsr.zero_flag = zero.?;

        if (overflow != null) cpsr.overflow_flag = overflow.?;

        if (negative != null) cpsr.neg_flag = negative.?;
    }
}

pub fn execBranchWithLink(instr: is.BranchWithLink, registers: *cpu_state.Reigsters) void {
    const current_pc = registers.get(15);

    const bit_mask: u32 = ~@as(u32, 0b11);
    if (instr.link)
        registers.set(14, current_pc & bit_mask);

    const new_pc = @as(i32, @bitCast(current_pc)) + (@as(i26, instr.offset) << 2);
    registers.setPC(@bitCast(new_pc));
}

pub fn execMultiply(instr: is.MultiplyInstr, registers: *cpu_state.Reigsters) void {
    const rs_content = registers.get(instr.rs);
    const rm_content = registers.get(instr.rm);
    const rn_content = registers.get(instr.rn);

    var result = rs_content *% rm_content;
    if (instr.acc_flag) result +%= rn_content;

    registers.set(instr.rd, result);

    if (instr.set_cond_flag) {
        registers.cpsr.zero_flag = result == 0;
        registers.cpsr.neg_flag = result >> 31 == 1;
    }
}

pub fn execMultiplyLong(instr: is.MultiplyLongInstr, registers: *cpu_state.Reigsters) void {
    const rs_content = registers.get(instr.rs);
    const rm_content = registers.get(instr.rm);
    const rd_high_content: u64 = @intCast(registers.get(instr.rd_high));
    const rd_low_content: u64 = @intCast(registers.get(instr.rd_low));

    var result: u64 = undefined;

    if (instr.signed) {
        const rs_content_signed: i32 = @bitCast(rs_content);
        const rm_content_signed: i32 = @bitCast(rm_content);

        result = @bitCast(@as(i64, rs_content_signed) * @as(i64, rm_content_signed));
    } else result = @as(u64, rs_content) * @as(u64, rm_content);

    if (instr.acc_flag)
        result +%= (rd_high_content << 32) | rd_low_content;

    registers.set(instr.rd_high, @truncate(result >> 32));
    registers.set(instr.rd_low, @truncate(result & 0xFFFF_FFFF));

    if (instr.set_cond_flag) {
        registers.cpsr.zero_flag = result == 0;
        registers.cpsr.neg_flag = result >> 63 == 1;
    }
}

pub fn execPSRTransfer(instr: is.PSRTransferInstr, registers: *cpu_state.Reigsters) void {
    if (!instr.cpsr)
        switch (registers.cpsr.mode) {
            .User, .System => |mode| {
                log.err("SPSR was attempted to be accessed in {} mode, NOP will be performed", .{mode});
                return;
            },
            else => {},
        };

    switch (instr.type) {
        .mrs => |mrs| {
            const psr = registers.getBinFromPSR(instr.cpsr);

            registers.set(mrs.rd, psr);
        },
        .msr => |msr| {
            var op: u32 = undefined;

            if (msr.imm_flag) {
                const rotate = msr.rotate.?;
                const imm = msr.imm.?;

                op = rotateRight(imm, rotate * 2);
            } else {
                op = registers.get(msr.rm.?);
            }

            if (op >> 5 & 1 == 1)
                log.warn("Attempt to set T bit via MSR will result in undefined behaviour", .{});

            registers.setPSRFromBin(
                op,
                instr.cpsr,
                instr.update_control_fields,
                instr.update_cond_fields,
            );
        },
    }
}

pub fn execSoftwareInterrupt(registers: *cpu_state.Reigsters) void {
    registers.svc.spsr = registers.cpsr;
    registers.cpsr.mode = .Supervisor;
    registers.cpsr.irq_disable = true;
    registers.set(14, registers.pc + 0x4);
    registers.setPC(0x8);
}

pub fn execSingleDataTransfer(
    instr: is.SingleDataTransferInstr,
    registers: *cpu_state.Reigsters,
    memory_map: *memory.MemoryMap,
) void {
    const rn_content = registers.get(instr.rn);
    var address: u32 = undefined;
    var modified_base: u32 = undefined;
    var offset: u32 = undefined;

    if (instr.imm_flag)
        offset = calcRegOffset(instr.op2, registers)[0]
    else
        offset = instr.op2.imm_operand;

    if (instr.add_offset)
        modified_base = rn_content +% offset
    else
        modified_base = rn_content -% offset;

    if (instr.pre_index) {
        address = modified_base;

        if (instr.write_back)
            registers.set(instr.rn, modified_base);
    } else {
        address = rn_content;
        registers.set(instr.rn, modified_base);
    }

    if (instr.load) {
        const value = memory_map.read(address);

        if (instr.transfer_byte)
            registers.set(instr.rd, value & 0xFF)
        else
            registers.set(instr.rd, value);
    } else {
        const value = registers.get(instr.rd);

        if (instr.transfer_byte)
            memory_map.write(address, value & 0xFF)
        else
            memory_map.write(address, value);
    }
}

pub fn execSingleDataSwap(
    instr: is.SingleDataSwapInstr,
    registers: *cpu_state.Reigsters,
    memory_map: *memory.MemoryMap,
) void {
    const addr = registers.get(instr.rn);

    var old_value = memory_map.read(addr);
    var new_value = registers.get(instr.rd);

    if (instr.swap_byte) {
        old_value = old_value & 0xFF;
        new_value = new_value & 0xFF;
    }

    registers.set(instr.rm, old_value);
    memory_map.write(addr, new_value);
}
