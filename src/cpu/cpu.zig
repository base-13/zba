const std = @import("std");
const is = @import("instruction_set.zig");
const cpu_state = @import("cpu_state.zig");
const decoder_arm = @import("arm/decoder.zig");
const decoder_thumb = @import("thumb/decoder.zig");
const exec_arm = @import("arm/exec.zig");
const exec_thumb = @import("thumb/exec.zig");
const memory = @import("../memory.zig");

var registers = cpu_state.Reigsters{};

fn getInstr(pc: u32) is.InstrDecodeError!is.Instr {
    if (registers.cpsr.thumb_state) {
        return .{ .thumb = try decoder_thumb.decode(memory_map.read(pc, .HalfWord)) };
    } else {
        return .{ .arm = try decoder_arm.decode(memory_map.read(pc, .Word)) };
    }
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

    if (pc >= last_instr_addr) { // we will currently only run in BIOS region and stop at the end of ROM
        std.debug.print("\n\nPC: {} GPRs: ", .{registers.getPC()});
        for (0..16) |i|
            std.debug.print("r{}=0x{X} ", .{ i, registers.get(@intCast(i)) });

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

    const instr = getInstr(pc) catch {
        registers.setPC(4); // UND Exception vector

        registers.und.spsr = registers.cpsr;
        // store addr of next instruction to LR_und
        if (registers.cpsr.thumb_state)
            registers.und.r13_14[1] = pc + 2
        else
            registers.und.r13_14[1] = pc + 4;

        registers.cpsr.irq_disable = true;
        registers.cpsr.thumb_state = false;

        return true;
    };

    switch (instr) {
        .arm => |arm_instr| switch (arm_instr.fields) {
            .data_proc => std.debug.print("{} op2={}\n", .{ arm_instr, arm_instr.fields.data_proc.op2 }),
            .branch_with_link => std.debug.print("{} {}\n", .{ arm_instr.cond, arm_instr.fields.branch_with_link }),
            .multiply => std.debug.print("{} {}\n", .{ arm_instr.cond, arm_instr.fields.multiply }),
            .multiply_long => std.debug.print("{} {}\n", .{ arm_instr.cond, arm_instr.fields.multiply_long }),
            .psr_transfer => std.debug.print("{} {}\n", .{ arm_instr, arm_instr.fields.psr_transfer.type }),
            .software_interrupt => std.debug.print("Software Interrupt Instruction\n", .{}),
            .single_data_transfer => std.debug.print("{} op2={}\n", .{
                arm_instr,
                arm_instr.fields.single_data_transfer.op2,
            }),
            .single_data_swap => std.debug.print("{} {}\n", .{ arm_instr.cond, arm_instr.fields.single_data_swap }),
            .h_and_s_data_transfer => std.debug.print("{} op2={}\n", .{
                arm_instr,
                arm_instr.fields.h_and_s_data_transfer.op2,
            }),
            .block_data_transfer => std.debug.print("{} {}\n", .{ arm_instr.cond, arm_instr.fields }),
            .branch_and_exchange => std.debug.print("{}\n", .{arm_instr}),
            .coprocessor_instr => std.debug.print("Coprocessor Instruction\n", .{}),
        },
        .thumb => |thumb_instr| {
            _ = thumb_instr;
        },
    }

    var instr_updated_pc = false;

    switch (instr) {
        .arm => |arm_instr| {
            if (exec_arm.checkCondition(arm_instr, &registers)) {
                instr_updated_pc =
                    switch (arm_instr.fields) {
                        .data_proc => |i| exec_arm.execDataProc(i, &registers),
                        .branch_with_link => |i| exec_arm.execBranchWithLink(i, &registers),
                        .multiply => |i| exec_arm.execMultiply(i, &registers),
                        .multiply_long => |i| exec_arm.execMultiplyLong(i, &registers),
                        .psr_transfer => |i| exec_arm.execPSRTransfer(i, &registers),
                        .software_interrupt => exec_arm.execSoftwareInterrupt(&registers),
                        .single_data_transfer => |i| exec_arm.execSingleDataTransfer(
                            i,
                            &registers,
                            &memory_map,
                        ),
                        .single_data_swap => |i| exec_arm.execSingleDataSwap(
                            i,
                            &registers,
                            &memory_map,
                        ),
                        .h_and_s_data_transfer => |i| exec_arm.execHAndSDataTransfer(
                            i,
                            &registers,
                            &memory_map,
                        ),
                        .block_data_transfer => |i| exec_arm.execBlockDataTransfer(
                            i,
                            &registers,
                            &memory_map,
                        ),
                        .branch_and_exchange => |i| exec_arm.execBranchAndExchange(i, &registers),
                        .coprocessor_instr => false,
                    };
            }
        },
        .thumb => |thumb_instr| {
            _ = thumb_instr;
        },
    }

    if (!instr_updated_pc)
        registers.setPC(pc + 4);

    return true;
}
