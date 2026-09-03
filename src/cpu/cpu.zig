const std = @import("std");
const is = @import("instruction_set.zig");
const cpu_state = @import("cpu_state.zig");
const decoder_arm = @import("arm/decoder.zig");
const decoder_thumb = @import("thumb/decoder.zig");
const exec_arm = @import("arm/exec.zig");
const exec_thumb = @import("thumb/exec.zig");
const memory = @import("../memory.zig");
const utils = @import("./cpu_utils.zig");

const IORegisters = @import("../io.zig").IORegisters;

var registers = cpu_state.Registers{};

fn getInstr(pc: u32) is.InstrDecodeError!is.Instr {
    if (registers.cpsr.thumb_state) {
        return .{ .thumb = try decoder_thumb.decode(memory_map.read(pc, .HalfWord)) };
    } else {
        return .{ .arm = try decoder_arm.decode(memory_map.read(pc, .Word)) };
    }
}

var memory_map: memory.MemoryMap = .{};

pub fn setBIOS(bios: []u8) void {
    if (bios.len > 16 * 1024) {
        std.debug.print("BIOS too big", .{});
        std.process.exit(1);
    }

    std.mem.copyForwards(u8, memory_map.bios[0..bios.len], bios);
}

pub fn setROM(rom: []u8) void {
    if (rom.len > 32 * 1024 * 1024) {
        std.debug.print("ROM too big", .{});
        std.process.exit(1);
    }

    std.mem.copyForwards(u8, memory_map.rom[0..rom.len], rom);
}

pub fn getMemoryMap() *memory.MemoryMap {
    return &memory_map;
}

fn softwareInterrupt() bool {
    const pc = registers.getPC();
    registers.setPC(is.ExceptionVectors.SoftwareInterrupt);

    registers.svc.spsr = registers.cpsr;
    registers.cpsr.mode = .Supervisor;
    // store addr of next instruction to LR_svc
    if (registers.cpsr.thumb_state)
        registers.set(14, pc + 2)
    else
        registers.set(14, pc + 4);

    registers.cpsr.thumb_state = false;
    registers.cpsr.irq_disable = true;

    return true;
}

fn pollInterruptRequest() void {
    if (registers.cpsr.irq_disable) return;

    const ie_value = memory_map.read(IORegisters.IE, .HalfWord);
    const if_value = memory_map.read(IORegisters.IF, .HalfWord);

    if (ie_value & if_value > 0) {
        registers.irq.spsr = registers.cpsr;
        registers.cpsr.mode = .IRQ;
        registers.cpsr.thumb_state = false;

        registers.set(14, registers.getPC() + 4); // Save interrupted instruction addr + 4 to LR_irq
        registers.setPC(is.ExceptionVectors.IRQ);
    }
}

pub fn poll(io: std.Io, exit: bool) void {
    const pc = registers.getPC();

    if (exit) {
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

        var i_wram_file: ?std.Io.File = undefined;
        i_wram_file = std.Io.Dir.cwd().createFile(io, "i_wram.bin", .{}) catch |e| blk: {
            std.debug.print("Failed to create i_wram.bin {}", .{e});
            break :blk null;
        };

        if (i_wram_file != null) {
            defer i_wram_file.?.close(io);
            i_wram_file.?.writeStreamingAll(io, &memory_map.i_wram) catch |e| {
                std.debug.print("Failed to write i_wram.bin {}", .{e});
            };
        }

        var e_wram_file: ?std.Io.File = undefined;
        e_wram_file = std.Io.Dir.cwd().createFile(io, "e_wram.bin", .{}) catch |e| blk: {
            std.debug.print("Failed to create e_wram.bin {}", .{e});
            break :blk null;
        };

        if (e_wram_file != null) {
            defer e_wram_file.?.close(io);
            e_wram_file.?.writeStreamingAll(io, &memory_map.e_wram) catch |e| {
                std.debug.print("Failed to write e_wram.bin {}", .{e});
            };
        }

        return;
    }

    pollInterruptRequest();

    const instr = getInstr(pc) catch {
        registers.setPC(is.ExceptionVectors.UndefinedInstr);

        registers.und.spsr = registers.cpsr;
        registers.cpsr.mode = .Undefined;
        // store addr of next instruction to LR_und
        if (registers.cpsr.thumb_state)
            registers.set(14, pc + 2)
        else
            registers.set(14, pc + 4);

        registers.cpsr.irq_disable = true;
        registers.cpsr.thumb_state = false;

        return;
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
        .thumb => |thumb_instr| std.debug.print("{}\n", .{thumb_instr}),
    }

    var instr_updated_pc = false;

    switch (instr) {
        .arm => |arm_instr| {
            if (utils.checkCondition(arm_instr.cond, &registers)) {
                instr_updated_pc =
                    switch (arm_instr.fields) {
                        .data_proc => |i| exec_arm.execDataProc(i, &registers),
                        .branch_with_link => |i| exec_arm.execBranchWithLink(i, &registers),
                        .multiply => |i| exec_arm.execMultiply(i, &registers),
                        .multiply_long => |i| exec_arm.execMultiplyLong(i, &registers),
                        .psr_transfer => |i| exec_arm.execPSRTransfer(i, &registers),
                        .software_interrupt => softwareInterrupt(),
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
            instr_updated_pc = switch (thumb_instr) {
                .software_interrupt => softwareInterrupt(),
                .move_register => |i| exec_thumb.execMoveRegister(i, &registers),
                .add_sub => |i| exec_thumb.execAddSub(i, &registers),
                .mov_cmp_add_sub8 => |i| exec_thumb.execMovCmpAddSub8(i, &registers),
                .alu_ops => |i| exec_thumb.execALUOps(i, &registers),
                .pc_rel_load => |i| exec_thumb.execPCRelLoad(i, &registers, &memory_map),
                .add_offset_to_sp => |i| exec_thumb.execAddOffsetToSP(i, &registers),
                .unconditional_branch => |i| exec_thumb.execUnconditionalBranch(i, &registers),
                .sp_rel_load_store => |i| exec_thumb.execSPRelLoadStore(i, &registers, &memory_map),
                .conditional_branch => |i| exec_thumb.execConditionalBranch(i, &registers),
                .load_address => |i| exec_thumb.execLoadAddress(i, &registers),
                .push_pop => |i| exec_thumb.execPushPop(i, &registers, &memory_map),
                .hi_reg_ops_and_bx => |i| exec_thumb.execHiRegOpsAndBX(i, &registers),
                .ls_reg_offset => |i| exec_thumb.execLSRegOffset(i, &registers, &memory_map),
                .ls_imm_offset => |i| exec_thumb.execLSImmOffset(i, &registers, &memory_map),
                .ls_halfword => |i| exec_thumb.execLSHalfword(i, &registers, &memory_map),
                .ls_sign_ex => |i| exec_thumb.execLSSignEx(i, &registers, &memory_map),
                .multiple_ls => |i| exec_thumb.execMultipleLS(i, &registers, &memory_map),
                .long_branch_with_link => |i| exec_thumb.execLongBranchWithLink(i, &registers),
            };
        },
    }

    if (!instr_updated_pc)
        registers.setPC(pc + 4);
}
