const is = @import("./instruction_set.zig");
const cpu_state = @import("./cpu_state.zig");

pub fn getNBits(number: u32, start: u5, n: u5, T: type) T {
    return @intCast((number >> start) & ((@as(u32, 1) << n) - 1));
}

pub fn checkCondition(cond: is.Condition, registers: *cpu_state.Registers) bool {
    const zero = registers.cpsr.zero_flag;
    const carry = registers.cpsr.carry_flag;
    const neg = registers.cpsr.neg_flag;
    const overflow = registers.cpsr.overflow_flag;

    return switch (cond) {
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
