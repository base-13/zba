const std = @import("std");
const is = @import("arm/instruction_set.zig");
const cpu_state = @import("cpu_state.zig");
const decoder = @import("arm/decoder.zig");
const exec = @import("arm/exec.zig");
const memory = @import("../memory.zig");

var registers = cpu_state.Reigsters{};

fn getInstr(pc: u32) decoder.InstrDecodeError!is.Instr {
    const instr = memory_map.read(pc);

    return decoder.decode(instr);
}

var memory_map: memory.MemoryMap = .{};
var last_instr_addr: u32 = undefined;

pub fn setBIOS(bios: []u8) void {
    if (bios.len > 16 * 1024) {
        std.debug.print("BIOS too big", .{});
        std.process.exit(1);
    }

    std.mem.copyForwards(u8, memory_map.bios[0..bios.len], bios);
    last_instr_addr = @intCast(bios.len);
}

pub fn poll(io: std.Io) !bool {
    const pc = registers.getPC();

    if (pc >= last_instr_addr) { // we will currently only run in BIOS region and stop at the last instruction
        std.debug.print("\n\nPC: {} GPRs: ", .{registers.getPC()});
        for (0..16) |i|
            std.debug.print("r{}=0x{X} ", .{ i, registers.r[i] });

        const debug_fmt = "\nCPSR: {}\nFIQ: {}\nIRQ: {}\nABT: {}\nSVC: {}\nUND: {}\n\n";
        std.debug.print(debug_fmt, .{
            registers.cpsr,
            registers.fiq,
            registers.irq,
            registers.abt,
            registers.svc,
            registers.und,
        });

        const i_wram_file = try std.Io.Dir.cwd().createFile(io, "i_wram.bin", .{});
        const e_wram_file = try std.Io.Dir.cwd().createFile(io, "e_wram.bin", .{});
        defer i_wram_file.close(io);
        defer e_wram_file.close(io);

        try i_wram_file.writeStreamingAll(io, &memory_map.i_wram);
        try e_wram_file.writeStreamingAll(io, &memory_map.e_wram);

        return false;
    }

    const instr = try getInstr(pc);

    switch (instr.fields) {
        .data_proc => std.debug.print("{} op2={}\n", .{ instr, instr.fields.data_proc.op2 }),
        .branch_with_link => std.debug.print("{} {}\n", .{ instr.cond, instr.fields.branch_with_link }),
        .multiply => std.debug.print("{} {}\n", .{ instr.cond, instr.fields.multiply }),
        .multiply_long => std.debug.print("{} {}\n", .{ instr.cond, instr.fields.multiply_long }),
        .psr_transfer => std.debug.print("{} {}\n", .{ instr, instr.fields.psr_transfer.type }),
        .software_interrupt => std.debug.print("Software Interrupt Instruction\n", .{}),
        .single_data_transfer => std.debug.print("{} op2={}\n", .{
            instr,
            instr.fields.single_data_transfer.op2,
        }),
        .single_data_swap => std.debug.print("{} {}", .{ instr.cond, instr.fields.single_data_swap }),
    }

    if (exec.checkCondition(instr, &registers))
        switch (instr.fields) {
            .data_proc => |i| exec.execDataProc(i, &registers),
            .branch_with_link => |i| exec.execBranchWithLink(i, &registers),
            .multiply => |i| exec.execMultiply(i, &registers),
            .multiply_long => |i| exec.execMultiplyLong(i, &registers),
            .psr_transfer => |i| exec.execPSRTransfer(i, &registers),
            .software_interrupt => exec.execSoftwareInterrupt(&registers),
            .single_data_transfer => |i| exec.execSingleDataTransfer(i, &registers, &memory_map),
            .single_data_swap => |i| exec.execSingleDataSwap(i, &registers, &memory_map),
        };

    // PC may have been updated by instruction so we use the latest value
    registers.setPC(registers.getPC() + 4);

    return true;
}
