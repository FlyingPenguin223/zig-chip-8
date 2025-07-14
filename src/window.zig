const sdl = @import("sdl.zig");
const Self = @This();
const Error = error{InitFail};

width: u16,
height: u16,
ptr: *sdl.c.SDL_Window,

pub fn init(title: [:0]const u8, width: u16, height: u16) !Self {
    const ptr = sdl.c.SDL_CreateWindow(title, 0, 0, width, height, sdl.c.SDL_WINDOW_RESIZABLE);
    if (ptr == null)
        return Error.InitFail;
    errdefer sdl.c.DestroyWindow(ptr);

    return Self{
        .ptr = ptr.?,
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: Self) void {
    sdl.c.SDL_DestroyWindow(self.ptr);
}
