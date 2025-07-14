const std = @import("std");
const sdl = @import("sdl.zig");
const Cpu = @import("cpu.zig");

const Error = error{FileNotProvidedError};

const FPS = 60;

pub fn main() !void {
    var cpu = try Cpu.init();
    defer cpu.deinit();

    const argv = std.os.argv;

    if (argv.len < 2) {
        std.debug.print("ROM file not provided\n", .{});
        return Error.FileNotProvidedError;
    }

    var instructions_per_frame: u32 = 200;

    if (argv.len > 2) {
        instructions_per_frame = try std.fmt.parseInt(u32, std.mem.span(argv[2]), 10);
    }

    var rom_file = try std.fs.cwd().openFile(std.mem.span(argv[1]), .{});

    const rom = try rom_file.reader().readAllAlloc(std.heap.c_allocator, 0xDFF); // 0xFFF - 0x200
    defer std.heap.c_allocator.free(rom);

    rom_file.close();

    cpu.load_program(rom);

    while (!cpu.should_quit) {
        const start: sdl.c.Uint64 = sdl.c.SDL_GetTicks64();
        _ = cpu.cycle_events();

        for (0..instructions_per_frame) |_| {
            try cpu.run_next_upcode();
        }

        if (cpu.delay_timer > 0)
            cpu.delay_timer -= 1;

        if (cpu.sound_timer > 0)
            cpu.sound_timer -= 1;

        try cpu.refresh_display();

        const time: sdl.c.Uint64 = sdl.c.SDL_GetTicks64() - start;
        if (time < 1000 / FPS) {
            const sleep_time = 1000 / FPS - time;
            if (sleep_time > 0)
                sdl.c.SDL_Delay(@truncate(sleep_time));
        }
    }
}
