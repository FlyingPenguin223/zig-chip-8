const sdl = @import("sdl.zig");
const Window = @import("window.zig");
const Self = @This();
const Error = error{ InitFail, RenderFail, ColorFail, DrawFail };

ptr: *sdl.c.SDL_Renderer,

pub fn init(window: Window) !Self {
    const ptr = sdl.c.SDL_CreateRenderer(window.ptr, 0, 0);
    if (ptr == null)
        return Error.InitFail;
    errdefer sdl.c.SDL_DestroyRenderer(ptr);

    if (sdl.c.SDL_RenderSetLogicalSize(ptr, 64, 32) < 0)
        return Error.InitFail;

    return Self{
        .ptr = ptr.?,
    };
}

pub fn deinit(self: Self) void {
    sdl.c.SDL_DestroyRenderer(self.ptr);
}

pub fn present(self: Self) void {
    sdl.c.SDL_RenderPresent(self.ptr);
}

pub fn clear(self: Self) !void {
    try self.set_color(0, 0, 0, 255);
    if (sdl.c.SDL_RenderClear(self.ptr) < 0)
        return Error.RenderFail;
}

pub fn set_color(self: Self, r: u8, g: u8, b: u8, a: u8) !void {
    if (sdl.c.SDL_SetRenderDrawColor(self.ptr, r, g, b, a) < 0)
        return Error.ColorFail;
}

pub fn draw_pixel(self: Self, x: u16, y: u16) !void {
    try self.set_color(255, 255, 255, 255);
    if (sdl.c.SDL_RenderDrawPoint(self.ptr, x, y) < 0)
        return Error.DrawFail;
}
