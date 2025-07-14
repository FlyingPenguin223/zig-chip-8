const std = @import("std");
const sdl = @import("sdl.zig");
const Cpu = @import("cpu.zig");

const Error = error{FileNotProvidedError};

const FPS = 60;
const INSTRUCTIONS_PER_FRAME = 200;

pub fn main() !void {
    var cpu = try Cpu.init();
    defer cpu.deinit();

    if (std.os.argv.len < 2) {
        std.debug.print("ROM file not provided\n", .{});
        return Error.FileNotProvidedError;
    }

    var rom_file = try std.fs.cwd().openFile(std.mem.span(std.os.argv[1]), .{});
    defer rom_file.close();

    const rom = try rom_file.reader().readAllAlloc(std.heap.c_allocator, 0xDFF); // 0xFFF - 0x200
    defer std.heap.c_allocator.free(rom);

    cpu.load_program(rom);

    while (!cpu.should_quit) {
        const start: sdl.c.Uint64 = sdl.c.SDL_GetTicks64();
        _ = cpu.cycle_events();

        for (0..INSTRUCTIONS_PER_FRAME) |_| {
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
