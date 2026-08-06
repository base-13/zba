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
