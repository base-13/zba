const std = @import("std");

pub const CPUMode = enum(u5) {
    User = 0x10,
    FIQ = 0x11,
    IRQ = 0x12,
    Supervisor = 0x13,
    Abort = 0x17,
    Undefined = 0x1B,
    System = 0x1F,
};

pub const Reigsters = struct {
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
                    for (8..15) |r| {
                        const reg: u4 = @intCast(r);
                        self.fiq.r8_14[reg - 8] = self.get(reg);
                    }

                    self.fiq.spsr = self.cpsr;
                },
                .Supervisor => {
                    self.svc.r13_14 = .{ self.get(13), self.get(14) };

                    self.svc.spsr = self.cpsr;
                },
                .IRQ => {
                    self.irq.r13_14 = .{ self.get(13), self.get(14) };

                    self.irq.spsr = self.cpsr;
                },
                .Abort => {
                    self.abt.r13_14 = .{ self.get(13), self.get(14) };

                    self.abt.spsr = self.cpsr;
                },
                .Undefined => {
                    self.und.r13_14 = .{ self.get(13), self.get(14) };

                    self.und.spsr = self.cpsr;
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
            .IRQ => self.irq.spsr = psr,
            .Supervisor => self.svc.spsr = psr,
            .Abort => self.abt.spsr = psr,
            .Undefined => self.und.spsr = psr,
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
                .IRQ => spsr = self.irq.spsr,
                .Supervisor => spsr = self.svc.spsr,
                .Abort => spsr = self.abt.spsr,
                .Undefined => spsr = self.und.spsr,
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
