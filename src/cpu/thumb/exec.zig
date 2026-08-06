const is = @import("../instruction_set.zig");
const cpu_state = @import("../cpu_state.zig");

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
        const sign_bit1: u1 = @truncate(rs_content >> 31);
        const sign_bit2: u1 = @truncate(op2 >> 31);
        const sign_bit3: u1 = @truncate(value >> 31);
        overflow_flag = (sign_bit1 != sign_bit2) and (sign_bit1 != sign_bit3);
    } else {
        value = rs_content +% op2;

        carry_flag = @addWithOverflow(rs_content, op2)[1] == 1;
        const sign_bit1: u1 = @truncate(rs_content >> 31);
        const sign_bit2: u1 = @truncate(op2 >> 31);
        const sign_bit3: u1 = @truncate(value >> 31);
        overflow_flag = (sign_bit1 == sign_bit2) and (sign_bit1 != sign_bit3);
    }

    registers.cpsr.neg_flag = value >> 31 == 1;
    registers.cpsr.zero_flag = value == 0;
    registers.cpsr.carry_flag = carry_flag;
    registers.cpsr.overflow_flag = overflow_flag;

    return false;
}
