const is = @import("../instruction_set.zig");
const exec_arm = @import("../arm/exec.zig");
const cpu_state = @import("../cpu_state.zig");
const memory = @import("../../memory.zig");

pub fn execMoveRegister(instr: is.MoveRegisterTInstr, registers: *cpu_state.Registers) bool {
    var value: u32 = undefined;
    const rs_content = registers.get(instr.rs);

    switch (instr.opcode) {
        .LogicalLeft => {
            value = rs_content << instr.offset;

            var carry: u1 = undefined;
            if (instr.offset != 0)
                carry = @truncate(rs_content >> (0 -% instr.offset)) // equivalent to 32 - instr.offset
            else
                carry = 0;

            registers.cpsr.carry_flag = carry == 1;
        },
        .LogicalRight => {
            value = rs_content >> instr.offset;
            registers.cpsr.carry_flag = (rs_content >> (instr.offset - 1)) & 1 == 1;
        },
        .ArithmeticRight => {
            const rs_signed: i32 = @bitCast(rs_content);

            value = @bitCast(rs_signed >> instr.offset);

            const carry = (rs_signed >> (instr.offset - 1)) & 1;
            registers.cpsr.carry_flag = carry == 1;
        },
        else => unreachable,
    }

    registers.cpsr.neg_flag = (value >> 31) == 1;
    registers.cpsr.zero_flag = value == 0;

    registers.set(instr.rd, value);

    return false;
}

pub fn execAddSub(instr: is.AddSubTInstr, registers: *cpu_state.Registers) bool {
    var op2: u32 = undefined;

    if (instr.imm_flag)
        op2 = instr.op2
    else
        op2 = registers.get(instr.op2);

    const rs_content = registers.get(instr.rs);
    var carry_flag: bool = undefined;
    var overflow_flag: bool = undefined;
    var value: u32 = undefined;

    if (instr.sub) {
        value = rs_content -% op2;

        carry_flag = rs_content >= op2;
    } else {
        value = rs_content +% op2;

        carry_flag = @addWithOverflow(rs_content, op2)[1] == 1;
    }

    const sign_bit1: u1 = @truncate(rs_content >> 31);
    const sign_bit2: u1 = @truncate(op2 >> 31);
    const sign_bit3: u1 = @truncate(value >> 31);

    if (instr.sub)
        overflow_flag = (sign_bit1 != sign_bit2) and (sign_bit1 != sign_bit3)
    else
        overflow_flag = (sign_bit1 == sign_bit2) and (sign_bit1 != sign_bit3);

    registers.cpsr.neg_flag = sign_bit3 == 1;
    registers.cpsr.zero_flag = value == 0;
    registers.cpsr.carry_flag = carry_flag;
    registers.cpsr.overflow_flag = overflow_flag;

    return false;
}

pub fn execMovCmpAddSub8(instr: is.MovCmpAddSub8TInstr, registers: *cpu_state.Registers) bool {
    var carry_flag: bool = undefined;
    var overflow_flag: bool = undefined;
    var neg_flag: bool = undefined;
    var value: u32 = undefined;

    const rd_content = registers.get(instr.rd);

    switch (instr.opcode) {
        .ADD => {
            value = rd_content +% instr.offset;

            carry_flag = @addWithOverflow(rd_content, instr.offset)[1] == 1;
            const sign_bit1: u1 = @truncate(rd_content >> 31);
            const sign_bit2: u1 = @truncate(@as(u32, instr.offset) >> 31);
            const sign_bit3: u1 = @truncate(value >> 31);
            overflow_flag = (sign_bit1 == sign_bit2) and (sign_bit1 != sign_bit3);
            neg_flag = sign_bit3 == 1;
        },
        .CMP, .SUB => {
            value = rd_content -% instr.offset;

            carry_flag = rd_content >= instr.offset;
            const sign_bit1: u1 = @truncate(rd_content >> 31);
            const sign_bit2: u1 = @truncate(@as(u32, instr.offset) >> 31);
            const sign_bit3: u1 = @truncate(value >> 31);
            overflow_flag = (sign_bit1 != sign_bit2) and (sign_bit1 != sign_bit3);
            neg_flag = sign_bit3 == 1;
        },
        .MOV => {
            value = instr.offset;

            carry_flag = registers.cpsr.carry_flag;
            overflow_flag = registers.cpsr.overflow_flag;
            neg_flag = false;
        },
    }

    registers.cpsr.carry_flag = carry_flag;
    registers.cpsr.overflow_flag = overflow_flag;
    registers.cpsr.neg_flag = neg_flag;
    registers.cpsr.zero_flag = value == 0;

    if (instr.opcode != .CMP)
        registers.set(instr.rd, value);

    return false;
}

pub fn execALUOps(instr: is.ALUOpsTInstr, registers: *cpu_state.Registers) bool {
    // for ease of implementation we will just execute equivalent ARM instructions
    return switch (instr.opcode) {
        .AND,
        .EOR,
        .ADC,
        .SBC,
        .ORR,
        .BIC,
        .MVN,
        .TST,
        .CMP,
        .CMN,
        => |thumb_alu_opcode| exec_arm.execDataProc(.{
            .imm_flag = false,
            .opcode = switch (thumb_alu_opcode) {
                .AND => .AND,
                .EOR => .EOR,
                .ADC => .ADC,
                .SBC => .SBC,
                .ORR => .ORR,
                .BIC => .BIC,
                .MVN => .MVN,
                .TST => .TST,
                .CMP => .CMP,
                .CMN => .CMN,
                else => unreachable,
            },
            .set_cond_flag = true,
            .rn = instr.rd,
            .rd = instr.rd,
            .op2 = .{
                .reg_operand = .{
                    .shift = .{ .shift_amount = 0 },
                    .shift_type = .LogicalLeft,
                    .rm = instr.rs,
                },
            },
        }, registers),
        .NEG => exec_arm.execDataProc(.{
            .imm_flag = true,
            .opcode = .RSB,
            .set_cond_flag = true,
            .rn = instr.rs,
            .rd = instr.rd,
            .op2 = .{ .imm_operand = 0 },
        }, registers),
        .LSL,
        .LSR,
        .ASR,
        .ROR,
        => |shift_type_opcode| exec_arm.execDataProc(.{
            .imm_flag = false,
            .opcode = .MOV,
            .set_cond_flag = true,
            .rn = 0,
            .rd = instr.rd,
            .op2 = .{
                .reg_operand = .{
                    .shift = .{ .rs = instr.rs },
                    .shift_type = switch (shift_type_opcode) {
                        .LSL => .LogicalLeft,
                        .LSR => .LogicalRight,
                        .ASR => .ArithmeticRight,
                        .ROR => .RotateRight,
                        else => unreachable,
                    },
                    .rm = instr.rd,
                },
            },
        }, registers),
        .MUL => exec_arm.execMultiply(.{
            .acc_flag = false,
            .set_cond_flag = true,
            .rd = instr.rd,
            .rn = instr.rd,
            .rs = instr.rs,
            .rm = instr.rd,
        }, registers),
    };
}

pub fn execPCRelLoad(
    instr: is.PCRelLoadTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    const address = (registers.get(15) & 0xFFFF_FFFC) +% (@as(u8, instr.offset) << 2);

    registers.set(instr.rd, memory_map.read(address, .Word));

    return false;
}

pub fn execAddOffsetToSP(instr: is.AddOffsetToSPTInstr, registers: *cpu_state.Registers) bool {
    const offset: u9 = instr.offset << 2;
    const current_sp = registers.get(13);

    if (instr.neg)
        registers.set(13, current_sp -% offset)
    else
        registers.set(13, current_sp +% offset);

    return false;
}

pub fn execUnconditionalBranch(instr: is.UnconditionalBranchTInstr, registers: *cpu_state.Registers) bool {
    const current_pc = registers.get(15);

    if (instr.offset >= 0)
        registers.setPC(current_pc +% (@as(u12, @intCast(instr.offset)) << 1))
    else
        registers.setPC(current_pc -% (@as(u12, @intCast(instr.offset)) << 1));

    return true;
}
