pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Error = error{InitFail};

pub fn init() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0)
        return Error.InitFail;
}

pub fn deinit() void {
    c.SDL_Quit();
}

pub fn poll() ?c.SDL_Event {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event) != 0) {
        return event;
    }
    return null;
}
