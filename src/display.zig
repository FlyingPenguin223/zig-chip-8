const std = @import("std");
const sdl = @import("sdl.zig");
const Renderer = @import("renderer.zig");
const Window = @import("window.zig");
const Self = @This();

const buffer_width: u16 = 64;
const buffer_height: u16 = 32;
const buffer_size: u16 = 64 * 32;

buffer: [buffer_size]bool,

window: Window,
renderer: Renderer,

pub fn init() !Self {
    const window = try Window.init("chip8 display", 1200, 800);
    errdefer window.deinit();

    const renderer = try Renderer.init(window);
    errdefer renderer.deinit();

    return Self{
        .buffer = .{false} ** buffer_size,
        .window = window,
        .renderer = renderer,
    };
}

pub fn deinit(self: Self) void {
    self.renderer.deinit();
    self.window.deinit();
}

pub fn clear(self: *Self) void {
    self.buffer = .{false} ** buffer_size;
}

pub fn refresh(self: Self) !void {
    try self.renderer.clear();
    for (0..buffer_size) |i| {
        const x: u16 = @as(u16, @intCast(i)) % buffer_width;
        const y: u16 = @as(u16, @intCast(i)) / buffer_width;
        if (self.buffer[i])
            try self.renderer.draw_pixel(x, y);
    }
    self.renderer.present();
}

pub fn draw_byte(self: *Self, x: u16, y: u16, byte: u8) bool {
    const line = (y % 32) * buffer_width;
    var ret = false;

    var bit = byte;
    for (0..8) |i| {
        if (bit >> 7 == 1) {
            self.buffer[line + (i + x) % 64] = !self.buffer[line + (i + x) % 64];
            if (!self.buffer[line + (i + x) % 64])
                ret = true;
        }
        bit <<= 1;
    }

    return ret;
}
