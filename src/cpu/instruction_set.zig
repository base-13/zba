pub const Reigsters = struct {
    pub const ProgramStatusReg = struct {
        neg_flag: bool = false,
        zero_flag: bool = false,
        carry_flag: bool = false,
        overflow_flag: bool = false,
        irq_disable: bool = true,
        fiq_disable: bool = true,
        thumb_state: bool = false,
        mode: enum(u5) {
            User = 0x10,
            FIQ = 0x11,
            IRQ = 0x12,
            Supervisor = 0x13,
            Abort = 0x17,
            Undefined = 0x1B,
            System = 0x1F,
        } = .Supervisor,
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

pub const DataProcInstrOps = struct {
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
    opcode: DataProcInstrOps.Opcode,
    set_cond_flag: bool,
    rn: u4,
    rd: u4,
    op2: DataProcInstrOps.Operand2,
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

pub const Fields = union(enum) {
    data_proc: DataProcInstr,
    branch_with_link: BranchWithLink,
    multiply: MultiplyInstr,
};

pub const Instr = struct {
    cond: Condition,
    fields: Fields,
};
