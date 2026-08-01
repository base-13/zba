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

pub const OffsetOperand = struct {
    pub const ShiftType = enum(u2) {
        LogicalLeft = 0b00,
        LogicalRight = 0b01,
        ArithmeticRight = 0b10,
        RotateRight = 0b11,
    };

    pub const RegOffsetShift = union(enum) {
        shift_amount: u5,
        rs: u4,
    };

    pub const Operand = union(enum) {
        reg_operand: struct {
            shift: RegOffsetShift,
            shift_type: ShiftType,
            rm: u4,
        },
        rotated_imm_operand: struct {
            rotate: u4,
            imm: u8,
        },
        imm_operand: u12,
    };

    pub const HAndSDataTransferOperand = union(enum) {
        rm: u4,
        offset: u8,
    };
};

pub const DataProcInstrOpcode = enum(u4) {
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

pub const DataProcInstr = struct {
    imm_flag: bool,
    opcode: DataProcInstrOpcode,
    set_cond_flag: bool,
    rn: u4,
    rd: u4,
    op2: OffsetOperand.Operand,
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

pub const SoftwareInterruptInstr = struct {};

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

pub const SingleDataTransferInstr = struct {
    imm_flag: bool,
    pre_index: bool,
    add_offset: bool,
    transfer_byte: bool,
    write_back: bool,
    load: bool,
    rn: u4,
    rd: u4,
    op2: OffsetOperand.Operand,
};

pub const SingleDataSwapInstr = struct {
    swap_byte: bool,
    rn: u4,
    rd: u4,
    rm: u4,
};

pub const HAndSDataTransferInstr = struct {
    pre_index: bool,
    add_offset: bool,
    imm_flag: bool,
    write_back: bool,
    load: bool,
    rn: u4,
    rd: u4,
    sh: u2,
    op2: OffsetOperand.HAndSDataTransferOperand,
};

pub const Fields = union(enum) {
    data_proc: DataProcInstr,
    branch_with_link: BranchWithLink,
    multiply: MultiplyInstr,
    multiply_long: MultiplyLongInstr,
    psr_transfer: PSRTransferInstr,
    software_interrupt: SoftwareInterruptInstr,
    single_data_transfer: SingleDataTransferInstr,
    single_data_swap: SingleDataSwapInstr,
    h_and_s_data_transfer: HAndSDataTransferInstr,
};

pub const Instr = struct {
    cond: Condition,
    fields: Fields,
};
