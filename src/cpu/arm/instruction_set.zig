const std = @import("std");

pub const Reigsters = struct {
    pub const CPUMode = enum(u5) {
        User = 0x10,
        FIQ = 0x11,
        IRQ = 0x12,
        Supervisor = 0x13,
        Abort = 0x17,
        Undefined = 0x1B,
        System = 0x1F,
    };

    pub const ProgramStatusReg = struct {
        neg_flag: bool = false,
        zero_flag: bool = false,
        carry_flag: bool = false,
        overflow_flag: bool = false,
        irq_disable: bool = true,
        fiq_disable: bool = true,
        thumb_state: bool = false,
        mode: CPUMode = .Supervisor,
    };

    pc: u32 = 0,

    r: [16]u32 = @splat(0),

    cpsr: ProgramStatusReg = .{},

    fiq: struct {
        r8_14: [7]u32 = @splat(0),
        spsr: ProgramStatusReg = .{},
    } = .{},

    svc: struct {
        r13_14: [2]u32 = @splat(0),
        spsr: ProgramStatusReg = .{},
    } = .{},

    abt: struct {
        r13_14: [2]u32 = @splat(0),
        spsr: ProgramStatusReg = .{},
    } = .{},

    irq: struct {
        r13_14: [2]u32 = @splat(0),
        spsr: ProgramStatusReg = .{},
    } = .{},

    und: struct {
        r13_14: [2]u32 = @splat(0),
        spsr: ProgramStatusReg = .{},
    } = .{},

    pub fn setPSRFromBin(
        self: *Reigsters,
        value: u32,
        cpsr: bool,
        set_control_fields: bool,
        set_cond_fields: bool,
    ) void {
        const current_mode = self.cpsr.mode;

        var n = self.cpsr.neg_flag;
        var z = self.cpsr.zero_flag;
        var c = self.cpsr.carry_flag;
        var v = self.cpsr.overflow_flag;

        if (set_cond_fields) {
            n = (value >> 31) & 1 == 1;
            z = (value >> 30) & 1 == 1;
            c = (value >> 29) & 1 == 1;
            v = (value >> 28) & 1 == 1;
        }

        var i = self.cpsr.irq_disable;
        var f = self.cpsr.fiq_disable;
        var t = self.cpsr.thumb_state;
        var new_mode = self.cpsr.mode;

        if (current_mode != .User and current_mode != .System and set_control_fields) {
            i = (value >> 7) & 1 == 1;
            f = (value >> 6) & 1 == 1;
            t = (value >> 5) & 1 == 1;
            new_mode = std.enums.fromInt(CPUMode, value & 0b11111) orelse self.cpsr.mode;
        }

        if (new_mode != self.cpsr.mode) {
            switch (new_mode) {
                .User, .System => {},
                .FIQ => {
                    for (8..15) |r|
                        self.fiq.r8_14[r - 8] = self.get(r);

                    self.fiq.spsr = cpsr;
                },
                .SVC => {
                    self.svc.r13_14 = .{ self.get(13), self.get(14) };

                    self.svc.spsr = cpsr;
                },
                .Abort => {
                    self.irq.r13_14 = .{ self.get(13), self.get(14) };

                    self.irq.spsr = cpsr;
                },
                .Abort => {
                    self.abt.r13_14 = .{ self.get(13), self.get(14) };

                    self.abt.spsr = cpsr;
                },
                .Undefined => {
                    self.und.r13_14 = .{ self.get(13), self.get(14) };

                    self.und.spsr = cpsr;
                },
            }
        }

        const psr: ProgramStatusReg = .{
            .neg_flag = n,
            .zero_flag = z,
            .carry_flag = c,
            .overflow_flag = v,
            .irq_disable = i,
            .fiq_disable = f,
            .thumb_state = t,
            .mode = new_mode,
        };

        if (cpsr)
            self.cpsr = psr
        else switch (current_mode) {
            .FIQ => self.fiq.spsr = psr,
            .IRQ => self.fiq.spsr = psr,
            .Supervisor => self.fiq.spsr = psr,
            .Abort => self.fiq.spsr = psr,
            .Undefined => self.fiq.spsr = psr,
            .User, .System => unreachable,
        }
    }

    pub fn getBinFromPSR(self: *Reigsters, cpsr: bool) u32 {
        var n: bool = undefined;
        var z: bool = undefined;
        var c: bool = undefined;
        var v: bool = undefined;
        var i: bool = undefined;
        var f: bool = undefined;
        var t: bool = undefined;
        var mode: CPUMode = undefined;

        if (cpsr) {
            n = self.cpsr.neg_flag;
            z = self.cpsr.zero_flag;
            c = self.cpsr.carry_flag;
            v = self.cpsr.overflow_flag;
            i = self.cpsr.irq_disable;
            f = self.cpsr.fiq_disable;
            t = self.cpsr.thumb_state;
            mode = self.cpsr.mode;
        } else {
            var spsr: ProgramStatusReg = undefined;
            switch (self.cpsr.mode) {
                .FIQ => spsr = self.fiq.spsr,
                .IRQ => spsr = self.fiq.spsr,
                .Supervisor => spsr = self.fiq.spsr,
                .Abort => spsr = self.fiq.spsr,
                .Undefined => spsr = self.fiq.spsr,
                .User, .System => unreachable,
            }

            n = spsr.neg_flag;
            z = spsr.zero_flag;
            c = spsr.carry_flag;
            v = spsr.overflow_flag;
            i = spsr.irq_disable;
            f = spsr.fiq_disable;
            t = spsr.thumb_state;
            mode = spsr.mode;
        }

        const n_bit: u32 = @as(u32, @intFromBool(n)) << 31;
        const z_bit: u32 = @as(u32, @intFromBool(z)) << 30;
        const c_bit: u32 = @as(u32, @intFromBool(c)) << 29;
        const v_bit: u32 = @as(u32, @intFromBool(v)) << 28;
        const i_bit: u32 = @as(u32, @intFromBool(i)) << 7;
        const f_bit: u32 = @as(u32, @intFromBool(f)) << 6;
        const t_bit: u32 = @as(u32, @intFromBool(t)) << 5;
        const mode_bits: u32 = @intFromEnum(mode);

        return n_bit | z_bit | c_bit | v_bit | i_bit | f_bit | t_bit | mode_bits;
    }

    pub fn getPC(self: *Reigsters) u32 {
        return self.pc;
    }

    pub fn setPC(self: *Reigsters, value: u32) void {
        self.pc = value;
        self.r[15] = value;
    }

    pub fn get(self: *Reigsters, reg: u4) u32 {
        const mode = self.cpsr.mode;

        if (reg >= 8 and reg <= 14 and mode == .FIQ)
            return self.fiq.r8_14[reg - 8]
        else if (reg == 13 or reg == 14)
            return switch (mode) {
                .IRQ => self.irq.r13_14[reg - 13],
                .Supervisor => self.svc.r13_14[reg - 13],
                .Abort => self.abt.r13_14[reg - 13],
                .Undefined => self.und.r13_14[reg - 13],
                else => self.r[reg],
            }
        else if (reg == 15) // emulate prefetching, pc stays ahead 4B(ARM mode) or 2B(Thumb mode)
            return self.r[15] +| if (self.cpsr.thumb_state) @as(u32, 2) else @as(u32, 4)
        else
            return self.r[reg];
    }

    pub fn set(self: *Reigsters, reg: u4, value: u32) void {
        const mode = self.cpsr.mode;

        if (reg >= 8 and reg <= 14 and mode == .FIQ)
            self.fiq.r8_14[reg - 8] = value
        else if (reg == 13 or reg == 14)
            switch (mode) {
                .IRQ => self.irq.r13_14[reg - 13] = value,
                .Supervisor => self.svc.r13_14[reg - 13] = value,
                .Abort => self.abt.r13_14[reg - 13] = value,
                .Undefined => self.und.r13_14[reg - 13] = value,
                else => self.r[reg] = value,
            }
        else
            self.r[reg] = value;

        if (reg == 15) self.pc = value;
    }
};

pub const Condition = enum(u4) {
    EQ = 0b0000,
    NE = 0b0001,
    CS = 0b0010,
    CC = 0b0011,
    MI = 0b0100,
    PL = 0b0101,
    VS = 0b0110,
    VC = 0b0111,
    HI = 0b1000,
    LS = 0b1001,
    GE = 0b1010,
    LT = 0b1011,
    GT = 0b1100,
    LE = 0b1101,
    AL = 0b1110,
};

pub const DataProcPSRTInstrOps = struct {
    pub const Opcode = enum(u4) {
        AND = 0b0000,
        EOR = 0b0001,
        SUB = 0b0010,
        RSB = 0b0011,
        ADD = 0b0100,
        ADC = 0b0101,
        SBC = 0b0110,
        RSC = 0b0111,
        TST = 0b1000,
        TEQ = 0b1001,
        CMP = 0b1010,
        CMN = 0b1011,
        ORR = 0b1100,
        MOV = 0b1101,
        BIC = 0b1110,
        MVN = 0b1111,
    };
    pub const Operand2 = union(enum) {
        reg_operand: struct {
            shift: Operand2RegShift,
            shift_type: ShiftType,
            rm: u4,
        },
        imm_operand: struct {
            rotate: u4,
            imm: u8,
        },
    };

    pub const ShiftType = enum(u2) {
        LogicalLeft = 0b00,
        LogicalRight = 0b01,
        ArithmeticRight = 0b10,
        RotateRight = 0b11,
    };

    pub const Operand2RegShift = union(enum) {
        shift_amount: u5,
        rs: u4,
    };
};

pub const DataProcInstr = struct {
    imm_flag: bool,
    opcode: DataProcPSRTInstrOps.Opcode,
    set_cond_flag: bool,
    rn: u4,
    rd: u4,
    op2: DataProcPSRTInstrOps.Operand2,
};

pub const BranchWithLink = struct {
    link: bool,
    offset: i24,
};

pub const MultiplyInstr = struct {
    acc_flag: bool,
    set_cond_flag: bool,
    rd: u4,
    rn: u4,
    rs: u4,
    rm: u4,
};

pub const MultiplyLongInstr = struct {
    signed: bool,
    acc_flag: bool,
    set_cond_flag: bool,
    rd_high: u4,
    rd_low: u4,
    rs: u4,
    rm: u4,
};

pub const PSRTransferInstr = struct {
    cpsr: bool,
    update_control_fields: bool = false,
    update_cond_fields: bool = false,
    type: union(enum) {
        mrs: struct { rd: u4 },
        msr: struct {
            imm_flag: bool,
            rm: ?u4 = null,
            rotate: ?u4 = null,
            imm: ?u8 = null,
        },
    },
};

pub const Fields = union(enum) {
    data_proc: DataProcInstr,
    branch_with_link: BranchWithLink,
    multiply: MultiplyInstr,
    multiply_long: MultiplyLongInstr,
    psr_transfer: PSRTransferInstr,
};

pub const Instr = struct {
    cond: Condition,
    fields: Fields,
};
