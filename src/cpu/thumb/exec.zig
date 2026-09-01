const is = @import("../instruction_set.zig");
const exec_arm = @import("../arm/exec.zig");
const cpu_state = @import("../cpu_state.zig");
const memory = @import("../../memory.zig");
const utils = @import("../cpu_utils.zig");

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

pub fn execSPRelLoadStore(
    instr: is.SPRelLoadStoreTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    const address = (registers.get(13) & 0xFFFF_FFFC) +% (@as(u8, instr.offset) << 2);

    if (instr.load)
        registers.set(instr.rd, memory_map.read(address, .Word))
    else
        memory_map.write(address, registers.get(instr.rd), .Word);

    return false;
}

pub fn execConditionalBranch(instr: is.ConditionalBranchTInstr, registers: *cpu_state.Registers) bool {
    const cond_true = utils.checkCondition(instr.cond, registers);

    if (cond_true) {
        const current_pc = registers.get(15);

        if (instr.offset >= 0)
            registers.setPC(current_pc +% (@as(u9, @intCast(instr.offset)) << 1))
        else
            registers.setPC(current_pc -% (@as(u9, @intCast(instr.offset)) << 1));
    }

    return cond_true;
}

pub fn execLoadAddress(instr: is.LoadAddressTInstr, registers: *cpu_state.Registers) bool {
    var base_value: u32 = undefined;

    if (instr.sp)
        base_value = registers.get(13)
    else
        base_value = registers.get(15) & 0xFFFF_FFFC;

    registers.set(instr.rd, base_value +% (instr.offset << 2));

    return false;
}

pub fn execPushPop(
    instr: is.PushPopTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    var n: u4 = 0;

    for (instr.r_list) |r_enabled| {
        if (r_enabled) n += 1;
    }
    if (instr.pc_lr) n += 1;

    const sp = registers.get(13);
    var addr: u32 = sp;

    if (instr.load) {
        for (instr.r_list, 0..) |r_enabled, r| {
            if (r_enabled) {
                registers.set(@intCast(r), memory_map.read(addr, .Word));
                addr += 4;
            }
        }

        if (instr.pc_lr)
            registers.setPC(memory_map.read(addr, .Word));

        registers.set(13, sp + 4 * n);
    } else {
        addr -= 4 * n;
        for (instr.r_list, 0..) |r_enabled, r| {
            if (r_enabled) {
                memory_map.write(addr, registers.get(@intCast(r)), .Word);
                addr += 4;
            }
        }

        if (instr.pc_lr)
            memory_map.write(addr, registers.get(14), .Word);

        registers.set(13, sp - 4 * n);
    }

    return instr.pc_lr and instr.load;
}

pub fn execHiRegOpsAndBX(instr: is.HiRegOpsAndBXTInstr, registers: *cpu_state.Registers) bool {
    var pc_changed = false;

    var rd: u4 = instr.rd;
    var rs: u4 = instr.rs;

    if (instr.h1)
        rd += 8;
    if (instr.h1)
        rs += 8;

    switch (instr.opcode) {
        .ADD,
        .MOV,
        .CMP,
        => pc_changed = exec_arm.execDataProc(.{
            .imm_flag = false,
            .opcode = switch (instr.opcode) {
                .ADD => .ADD,
                .MOV => .MOV,
                .CMP => .CMP,
                else => unreachable,
            },
            .set_cond_flag = instr.opcode == .CMP,
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
        .BX => {
            const addr = registers.get(rs);
            registers.setPC(addr);
            registers.cpsr.thumb_state = addr & 1 == 1;
            pc_changed = true;
        },
    }

    return pc_changed;
}

pub fn execLSRegOffset(
    instr: is.LSRegOffsetTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    const addr = registers.get(instr.rb) +% registers.get(instr.ro);
    const old_value = memory_map.read(addr, .Word);

    if (instr.load) {
        var new_value = old_value;

        if (instr.byte) new_value &= 0xFF;

        registers.set(instr.rd, new_value);
    } else {
        var new_value = registers.get(instr.rd);

        if (instr.byte) new_value = (old_value & 0xFFFF_FF00) | (new_value & 0xFF);

        memory_map.write(addr, new_value, .Word);
    }

    return false;
}

pub fn execLSImmOffset(
    instr: is.LSImmOffsetTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    const addr = registers.get(instr.rb) +% (instr.offset << 2);
    const old_value = memory_map.read(addr, .Word);

    if (instr.load) {
        var new_value = old_value;

        if (instr.byte) new_value &= 0xFF;

        registers.set(instr.rd, new_value);
    } else {
        var new_value = registers.get(instr.rd);

        if (instr.byte) new_value = (old_value & 0xFFFF_FF00) | (new_value & 0xFF);

        memory_map.write(addr, new_value, .Word);
    }

    return false;
}

pub fn execLSHalfword(
    instr: is.LSHalfwordTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    const addr = registers.get(instr.rb) +% (instr.offset << 1);

    if (instr.load)
        registers.set(instr.rd, memory_map.read(addr, .HalfWord))
    else
        memory_map.write(addr, @truncate(registers.get(instr.rd)), .HalfWord);

    return false;
}

pub fn execLSSignEx(
    instr: is.LSSignExTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    const addr = registers.get(instr.rb) +% registers.get(instr.ro);

    switch (instr.opcode) {
        .STRH => memory_map.write(addr, registers.get(instr.rd), .HalfWord),
        .LDRH => registers.set(instr.rd, memory_map.read(addr, .HalfWord)),
        .LDSB => {
            const value: i8 = @bitCast(@as(u8, @truncate(memory_map.read(addr, .Word) & 0xFF)));

            registers.set(instr.rd, @bitCast(@as(i32, value)));
        },
        .LDSH => {
            const value: i16 = @bitCast(memory_map.read(addr, .HalfWord));

            registers.set(instr.rd, @bitCast(@as(i32, value)));
        },
    }

    return false;
}

pub fn execMultipleLS(
    instr: is.MultipleLSTInstr,
    registers: *cpu_state.Registers,
    memory_map: *memory.MemoryMap,
) bool {
    var addr = registers.get(instr.rb);

    for (instr.r_list, 0..) |r_enabled, r| {
        if (r_enabled) {
            if (instr.load)
                registers.set(@intCast(r), memory_map.read(addr, .Word))
            else
                memory_map.write(addr, registers.get(@intCast(r)), .Word);

            addr += 4;
        }
    }

    registers.set(instr.rb, addr);

    return false;
}

pub fn execLongBranchWithLink(instr: is.LongBranchWithLinkTInstr, registers: *cpu_state.Registers) bool {
    if (instr.prefix) {
        const offset: i32 = @as(i11, @bitCast(instr.offset));

        var lr: i32 = undefined;

        lr = @as(i32, @bitCast(registers.get(15))) +% (offset << 12);

        registers.set(14, @bitCast(lr));
    } else {
        const offset = @as(i32, @bitCast(registers.get(14))) +% @as(i32, @as(u12, instr.offset) << 1);

        const old_pc = registers.get(15);
        var new_pc: i32 = undefined;

        new_pc = @as(i32, @bitCast(old_pc)) +% offset;

        registers.set(15, @bitCast(new_pc));
        registers.set(14, (old_pc - 4) & 0xFFFF_FFFC); // current instruction address = R15 - 4 because PC stays 4B ahead
    }

    return !instr.prefix;
}
