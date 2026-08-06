const is = @import("../instruction_set.zig");
const cpu_state = @import("../cpu_state.zig");

pub fn execMoveRegister(instr: is.MoveRegisterTInstr, registers: *cpu_state.Reigsters) bool {
    var value: u32 = undefined;
    const rs_content = registers.get(instr.rs);

    switch (instr.opcode) {
        .LogicalLeft => value = rs_content << instr.offset,
        .LogicalRight => value = rs_content >> instr.offset,
        .ArithmeticRight => value = @bitCast(@as(i32, @bitCast(rs_content)) >> instr.offset),
        else => unreachable,
    }

    registers.set(instr.rd, value);

    return false;
}
