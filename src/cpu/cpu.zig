const std = @import("std");
const is = @import("arm/instruction_set.zig");
const cpu_state = @import("cpu_state.zig");
const decoder = @import("arm/decoder.zig");
const exec = @import("arm/exec.zig");

var registers = cpu_state.Reigsters{};

fn getInstr(pc: u32) !is.Instr {
    const instr = std.mem.readInt(u32, rom[pc .. pc + 4][0..4], .little);

    return decoder.decode(instr);
}

var rom: []u8 = undefined;

pub fn setROM(new_rom: []u8) void {
    rom = new_rom;
}

pub fn poll() !bool {
    const pc = registers.getPC();

    if (pc >= rom.len) {
        const debug_fmt = "\n\nPC: {} GPRs: {any}\nCPSR: {}\nFIQ: {}\nIRQ: {}\nABT: {}\nSVC: {}\nUND: {}\n\n";
        std.debug.print(debug_fmt, .{
            registers.getPC(),
            registers.r,
            registers.cpsr,
            registers.fiq,
            registers.irq,
            registers.abt,
            registers.svc,
            registers.und,
        });
        return false;
    }

    const instr = try getInstr(pc);

    switch (instr.fields) {
        .data_proc => std.debug.print("{} {}\n", .{ instr, instr.fields.data_proc.op2 }),
        .branch_with_link => std.debug.print("{} {}\n", .{ instr.cond, instr.fields.branch_with_link }),
        .multiply => std.debug.print("{} {}\n", .{ instr.cond, instr.fields.multiply }),
        .multiply_long => std.debug.print("{} {}\n", .{ instr.cond, instr.fields.multiply_long }),
        .psr_transfer => std.debug.print("{} {}\n", .{ instr, instr.fields.psr_transfer.type }),
    }

    if (exec.checkCondition(instr, &registers))
        switch (instr.fields) {
            .data_proc => |i| exec.execDataProc(i, &registers),
            .branch_with_link => |i| exec.execBranchWithLink(i, &registers),
            .multiply => |i| exec.execMultiply(i, &registers),
            .multiply_long => |i| exec.execMultiplyLong(i, &registers),
            .psr_transfer => |i| exec.execPSRTransfer(i, &registers),
            .software_interrupt => exec.execSoftwareInterrupt(&registers),
        };

    // PC may have been updated by instruction so we use the latest value
    registers.setPC(registers.getPC() + 4);

    return true;
}
