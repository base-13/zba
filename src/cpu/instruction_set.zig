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
    NV = 0b1111,
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

pub const MoveRegisterTInstrOpcode = enum(u2) {
    LogicalLeft = 0b00,
    LogicalRight = 0b01,
    ArithmeticRight = 0b10,
    Invalid = 0b11,
};

pub const MovCmpAddSub8TInstrOpcode = enum(u2) {
    MOV = 0b00,
    CMP = 0b01,
    ADD = 0b10,
    SUB = 0b11,
};

pub const ALUOpsTInstrOpcode = enum(u4) {
    AND = 0b0000,
    EOR = 0b0001,
    LSL = 0b0010,
    LSR = 0b0011,
    ASR = 0b0100,
    ADC = 0b0101,
    SBC = 0b0110,
    ROR = 0b0111,
    TST = 0b1000,
    NEG = 0b1001,
    CMP = 0b1010,
    CMN = 0b1011,
    ORR = 0b1100,
    MUL = 0b1101,
    BIC = 0b1110,
    MVN = 0b1111,
};

pub const HiRegOpsAndBXTInstrOpcode = enum(u2) {
    ADD = 0b00,
    CMP = 0b01,
    MOV = 0b10,
    BX = 0b11,
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

pub const BlockDataTransferInstr = struct {
    pre_index: bool,
    add_offset: bool,
    force_user: bool,
    write_back: bool,
    load: bool,
    rn: u4,
    r_list: [16]bool,
};

pub const BranchAndExchangeInstr = struct { rn: u4 };

pub const CoprocessorInstr = struct {};

pub const MoveRegisterTInstr = struct {
    opcode: MoveRegisterTInstrOpcode,
    offset: u5,
    rs: u3,
    rd: u3,
};

pub const AddSubTInstr = struct {
    imm_flag: bool,
    sub: bool,
    op2: u3,
    rs: u3,
    rd: u3,
};

pub const MovCmpAddSub8TInstr = struct {
    opcode: MovCmpAddSub8TInstrOpcode,
    rd: u3,
    offset: u8,
};

pub const ALUOpsTInstr = struct {
    opcode: ALUOpsTInstrOpcode,
    rs: u3,
    rd: u3,
};

pub const PCRelLoadTInstr = struct {
    rd: u3,
    offset: u8,
};

pub const AddOffsetToSPTInstr = struct {
    neg: bool,
    offset: u7,
};

pub const UnconditionalBranchTInstr = struct { offset: i11 };

pub const SPRelLoadStoreTInstr = struct {
    load: bool,
    rd: u3,
    offset: u8,
};

pub const ConditionalBranchTInstr = struct {
    cond: Condition,
    offset: i8,
};

pub const LoadAddressTInstr = struct {
    sp: bool,
    rd: u3,
    offset: u8,
};

pub const PushPopTInstr = struct {
    load: bool,
    pc_lr: bool,
    r_list: [8]bool,
};

pub const HiRegOpsAndBXTInstr = struct {
    opcode: HiRegOpsAndBXTInstrOpcode,
    h1: bool,
    h2: bool,
    rs: u3,
    rd: u3,
};

pub const LSRegOffsetTInstr = struct {
    load: bool,
    byte: bool,
    ro: u3,
    rb: u3,
    rd: u3,
};

pub const LSImmOffsetTInstr = struct {
    byte: bool,
    load: bool,
    offset: u5,
    rb: u3,
    rd: u3,
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
    block_data_transfer: BlockDataTransferInstr,
    branch_and_exchange: BranchAndExchangeInstr,
    coprocessor_instr: CoprocessorInstr,
};

pub const InstrDecodeError = error{InvalidInstruction};

pub const ARMInstr = struct {
    cond: Condition,
    fields: Fields,
};

pub const ThumbInstr = union(enum) {
    software_interrupt: SoftwareInterruptInstr,
    move_register: MoveRegisterTInstr,
    add_sub: AddSubTInstr,
    mov_cmp_add_sub8: MovCmpAddSub8TInstr,
    alu_ops: ALUOpsTInstr,
    pc_rel_load: PCRelLoadTInstr,
    add_offset_to_sp: AddOffsetToSPTInstr,
    unconditional_branch: UnconditionalBranchTInstr,
    sp_rel_load_store: SPRelLoadStoreTInstr,
    conditional_branch: ConditionalBranchTInstr,
    load_address: LoadAddressTInstr,
    push_pop: PushPopTInstr,
    hi_reg_ops_and_bx: HiRegOpsAndBXTInstr,
    ls_reg_offset: LSRegOffsetTInstr,
    ls_imm_offset: LSImmOffsetTInstr,
};

pub const Instr = union(enum) {
    thumb: ThumbInstr,
    arm: ARMInstr,
};
