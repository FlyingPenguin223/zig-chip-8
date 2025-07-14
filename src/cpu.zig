const sdl = @import("sdl.zig");
const std = @import("std");
const Self = @This();

const Display = @import("display.zig");

const font = @embedFile("font");
const font_start = 0;

const memorysize = 0xFFF;
const stacksize = 12;

const program_start = 0x200;

v: [16]u8 = .{0} ** 16,
i: u12 = 0,

ip: u16 = program_start,
stack: [stacksize]u16 = .{0} ** stacksize,
stack_ptr: u8 = 0,

delay_timer: u8 = 0,
sound_timer: u8 = 0,

ram: [memorysize]u8 = .{0} ** memorysize,

display: Display,

keys: [0x10]bool = .{false} ** 0x10,
should_quit: bool = false,

pub fn init() !Self {
    const display = try Display.init();
    errdefer display.deinit();

    return Self{
        .display = display,
    };
}

pub fn deinit(self: Self) void {
    self.display.deinit();
}

pub fn load_program(self: *Self, program: []const u8) void {
    for (program, program_start..) |e, i| { // load program
        self.ram[i] = e;
    }

    for (font, font_start..) |f, i| { // load font
        self.ram[i] = f;
    }
}

pub fn cycle_events(self: *Self) ?u4 {
    var press: ?u4 = null;
    if (sdl.poll()) |e| {
        switch (e.type) {
            sdl.c.SDL_QUIT => self.should_quit = true,
            sdl.c.SDL_KEYDOWN => {
                if (match_scancode(e.key.keysym.scancode)) |k| {
                    press = k;
                    self.keys[k] = true;
                }
            },
            sdl.c.SDL_KEYUP => {
                if (match_scancode(e.key.keysym.scancode)) |k| {
                    self.keys[k] = false;
                }
            },
            else => {},
        }
    }
    return press;
}

fn match_scancode(scancode: u32) ?u4 {
    return switch (scancode) {
        sdl.c.SDL_SCANCODE_X => 0x00,
        sdl.c.SDL_SCANCODE_1 => 0x01,
        sdl.c.SDL_SCANCODE_2 => 0x02,
        sdl.c.SDL_SCANCODE_3 => 0x03,
        sdl.c.SDL_SCANCODE_Q => 0x04,
        sdl.c.SDL_SCANCODE_W => 0x05,
        sdl.c.SDL_SCANCODE_E => 0x06,
        sdl.c.SDL_SCANCODE_A => 0x07,
        sdl.c.SDL_SCANCODE_S => 0x08,
        sdl.c.SDL_SCANCODE_D => 0x09,
        sdl.c.SDL_SCANCODE_Z => 0x0a,
        sdl.c.SDL_SCANCODE_C => 0x0b,
        sdl.c.SDL_SCANCODE_4 => 0x0c,
        sdl.c.SDL_SCANCODE_R => 0x0d,
        sdl.c.SDL_SCANCODE_F => 0x0e,
        sdl.c.SDL_SCANCODE_V => 0x0f,
        else => null,
    };
}

pub fn run_next_upcode(self: *Self) !void {
    const opcode: u16 = (@as(u16, self.ram[self.ip]) << 8) + self.ram[self.ip + 1];
    self.ip += 2;
    try self.execute_opcode(opcode);
}

pub fn execute_opcode(self: *Self, opcode: u16) !void {
    const nnn: u12 = @truncate(opcode);
    const nn: u8 = @truncate(opcode);
    const x: u4 = @truncate(opcode >> 8);
    const y: u4 = @truncate(opcode >> 4);
    const head: u4 = @truncate(opcode >> 12);
    const tail: u4 = @truncate(opcode);
    if (opcode == 0x00E0) {
        // 00E0 clear display
        self.display.clear();
    } else if (opcode == 0x00EE) {
        // 00EE return from subroutine
        self.stack_ptr -= 1;
        self.ip = self.stack[self.stack_ptr];
    } else if (head == 0) {
        // 0NNN execute machine language subroutine at NNN
        std.log.debug("wtf! {x}", .{opcode});
        // unreachable;
    } else if (head == 1) {
        // 1NNN jump to NNN
        self.ip = nnn;
    } else if (head == 2) {
        // 2NNN execute subroutine at NNN
        self.stack[self.stack_ptr] = self.ip;
        self.stack_ptr += 1;
        self.ip = nnn;
    } else if (head == 3) {
        // 3XNN skip if vx == NN
        if (self.v[x] == nn)
            self.ip += 2;
    } else if (head == 4) {
        // 4XNN skip if vx != NN
        if (self.v[x] != nn)
            self.ip += 2;
    } else if (head == 5) {
        // 5XY0 skip if vx == vy
        if (self.v[x] == self.v[y])
            self.ip += 2;
    } else if (head == 6) {
        // 6XNN store NN in vx
        self.v[x] = nn;
    } else if (head == 7) {
        // 7XNN add NN to vx
        self.v[x] +%= nn; // % is allow overflow
    } else if (head == 8 and tail == 0) {
        // 8XY0 store vy in vx
        self.v[x] = self.v[y];
    } else if (head == 8 and tail == 1) {
        // 8XY1 vx = vx | vy
        self.v[x] |= self.v[y];
    } else if (head == 8 and tail == 2) {
        // 8XY2 vx = vx & vy
        self.v[x] &= self.v[y];
    } else if (head == 8 and tail == 3) {
        // 8XY3 vx = vx ^ vy
        self.v[x] ^= self.v[y];
    } else if (head == 8 and tail == 4) {
        // 8XY4 vx += vy  carry -> vf
        self.v[x], const overflow = @addWithOverflow(self.v[x], self.v[y]);
        self.v[0xF] = if (overflow == 1) 1 else 0;
    } else if (head == 8 and tail == 5) {
        // 8XY5 vx -= vy  borrow -> vf
        const borrow: u8 = if (self.v[y] > self.v[x]) 0 else 1;
        self.v[x] -%= self.v[y];
        self.v[0xF] = borrow;
    } else if (head == 8 and tail == 6) {
        // 8XY6 vx = vy >> 1 carry -> vf           THIS IS NOT THE POPULAR IMPLEMENTATION
        const carry: u1 = @truncate(self.v[x]);
        self.v[x] = self.v[y] >> 1;
        self.v[0xF] = carry;
    } else if (head == 8 and tail == 7) {
        // 8XY7 vx = vy - vx  borrow -> vf
        const borrow: u8 = if (self.v[y] < self.v[x]) 0 else 1;
        self.v[x] = self.v[y] -% self.v[x];
        self.v[0xF] = borrow;
    } else if (head == 8 and tail == 0xE) {
        // 8XYE vx = vy << 1 carry -> vf             THIS IS ALSO NOT THE POPULAR IMPLEMENTATION
        const carry: u1 = @truncate(self.v[x] >> 7);
        self.v[x] = self.v[y] << 1;
        self.v[0xF] = carry;
    } else if (head == 9) {
        // 9XY0 skip if vx != vy
        if (self.v[x] != self.v[y])
            self.ip += 2;
    } else if (head == 0xA) {
        // ANNN store NNN in i
        self.i = nnn;
    } else if (head == 0xB) {
        // BNNN jump to NNN + v0
        self.ip = nnn + self.v[0];
    } else if (head == 0xC) {
        // CXNN set vx to random with mask NN
        self.v[x] = std.crypto.random.int(u8) & nn;
    } else if (head == 0xD) {
        // DXYN draw sprite at vx, vy with N bytes of sprite data starting at i, vf = 1 if pixels unset (collision)
        var collision = false;

        for (0..tail) |spr_y| {
            const collide = self.display.draw_byte(self.v[x], self.v[y] + @as(u16, @truncate(spr_y)), self.ram[self.i + spr_y]);
            collision = collision or collide;
        }
        self.v[0xF] = if (collision) 1 else 0;
    } else if (head == 0xE and nn == 0x9E) {
        // EX9E skip if key in vx is pressed
        if (self.keys[self.v[x]])
            self.ip += 2;
    } else if (head == 0xE and nn == 0xA1) {
        // EXA1 skip if key in vx not pressed
        if (!self.keys[self.v[x]])
            self.ip += 2;
    } else if (head == 0xF and nn == 0x07) {
        // FX07 read delay timer to vx
        self.v[x] = self.delay_timer;
    } else if (head == 0xF and nn == 0x0A) {
        // FX0A wait for keypress, read to vx
        while (!self.should_quit) {
            if (self.cycle_events()) |key| {
                self.v[x] = key;
                break;
            } else {
                try self.refresh_display();
                sdl.c.SDL_Delay(1000 / 60);
            }
        }
    } else if (head == 0xF and nn == 0x15) {
        // FX15 write vx to delay timer
        self.delay_timer = self.v[x];
    } else if (head == 0xF and nn == 0x18) {
        // FX18 write vx to sound timer
        self.sound_timer = self.v[x];
    } else if (head == 0xF and nn == 0x1E) {
        // FX1E add vx to i
        self.i += self.v[x];
    } else if (head == 0xF and nn == 0x29) {
        // FX29 set i to address of hex font sprite corresponding to vx
        self.i = self.v[x] * 5 + font_start;
    } else if (head == 0xF and nn == 0x33) {
        // FX33 binary coded decimal
        self.ram[self.i] = self.v[x] / 100;
        self.ram[self.i + 1] = self.v[x] / 10 % 10;
        self.ram[self.i + 2] = self.v[x] % 10;
    } else if (head == 0xF and nn == 0x55) {
        // FX55 store memory from v0 to vx inclusive into memory starting at i, i points to next value (first not written)
        for (0..@as(usize, x) + 1) |i| {
            self.ram[self.i] = self.v[i];
            self.i += 1;
        }
    } else if (head == 0xF and nn == 0x65) {
        // FX65 fill registers v0 to vx inclusive with memory starting at i, i points to next value (first not copied)
        for (0..@as(usize, x) + 1) |i| {
            self.v[i] = self.ram[self.i];
            self.i += 1;
        }
    }
}

pub fn refresh_display(self: Self) !void {
    try self.display.refresh();
}
