pub const Console = @This();

const Prog = @import("root");
const c = Prog.c;
const Coor2u = Prog.Coor2u;
const ansi = Prog.ansi;

const lib = Prog.lib;
const cmp = lib.cmp;

const std = @import("std");
const asBytes = std.mem.asBytes;

size: Coor2u = .{ .x = 0, .y = 0 },
stdin_system_flags: c.struct_termios = undefined,
stdout_system_flags: c.struct_termios = undefined,
cursor: Cursor = .{},

pub fn init(self: *Console) void {

    // save std in/out settings
    const f_stdin = c.fileno(c.stdin);
    const f_stdout = c.fileno(c.stdout);
    _ = c.tcgetattr(f_stdin, &self.stdin_system_flags);
    _ = c.tcgetattr(f_stdout, &self.stdout_system_flags);

    // turn off line buffering
    var flags: c.struct_termios = undefined;
    c.setbuf(c.stdin, null);
    c.setbuf(c.stdout, null);

    _ = c.tcgetattr(f_stdin, &flags);
    flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
    _ = c.tcsetattr(f_stdin, c.TCSANOW, &flags);

    _ = c.tcgetattr(f_stdout, &flags);
    flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
    _ = c.tcsetattr(f_stdout, c.TCSANOW, &flags);

    _ = self.updateSize();
}

pub fn deinit(self: *Console) void {
    // restore buffer settings
    const f_stdin = c.fileno(c.stdin);
    _ = c.tcsetattr(f_stdin, c.TCSANOW, &self.stdin_system_flags);

    const f_stdout = c.fileno(c.stdout);
    _ = c.tcsetattr(f_stdout, c.TCSANOW, &self.stdout_system_flags);
}

pub fn updateSize(self: *Console) bool {
    var w: c.winsize = undefined;
    _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
    var new_size: Coor2u = .{
        .x = w.ws_col - 1,
        .y = w.ws_row - 1,
    };

    if (cmp(asBytes(&self.size), asBytes(&new_size)) == .various) {
        self.size = new_size;
        return false;
    }
    return true;
}

pub fn print(self: *Console, text: []const u8) void {
    for (text) |rune| {
        switch (rune) {
            '\r' => {
                self.cursor.x = 0;
            },

            '\n' => {
                self.cursor.x = 0;
                self.cursor.y += 1;
            },

            else => {
                self.cursor.x += 1;
            },
        }
        Prog.printRune(rune);
    }
}

pub fn cursorToEnd(self: *Console) void {
    self.cursor.move(0, self.size.y);
}

pub fn cursorMove(self: *Console, x: usize, y: usize) void {
    self.cursor.move(x, y);
    if (self.cursor.x > self.size.x) unreachable;
    if (self.cursor.y > self.size.y) unreachable;
}

pub const Cursor = struct {
    x: usize = 0,
    y: usize = 0,

    pub fn init(x: usize, y: usize) Cursor {
        return .{
            .x = x,
            .y = y,
        };
    }

    pub fn move(self: *Cursor, x: usize, y: usize) void {
        if (x != self.x) {
            if (x > self.x) {
                self.shiftRight(x - self.x);
            } else {
                self.shiftLeft(self.x - x);
            }
        }

        if (y != self.y) {
            if (y > self.y) {
                self.shiftDown(y - self.y);
            } else {
                self.shiftUp(self.y - y);
            }
        }
    }

    pub fn shiftLeft(self: *Cursor, pos: usize) void {
        const target = self.x - pos;
        while (self.x > target) {
            Prog.print(ansi.control ++ "1D");
            self.x -= 1;
        }
    }

    pub fn shiftRight(self: *Cursor, pos: usize) void {
        const target = self.x + pos;
        while (self.x < target) {
            Prog.print(ansi.control ++ "1C");
            self.x += 1;
        }
    }

    pub fn shiftUp(self: *Cursor, pos: usize) void {
        const target = self.y - pos;
        while (self.y > target) {
            Prog.print(ansi.control ++ "1A");
            self.y -= 1;
        }
    }

    pub fn shiftDown(self: *Cursor, pos: usize) void {
        const target = self.y + pos;
        while (self.y < target) {
            Prog.print(ansi.control ++ "1B");
            self.y += 1;
        }
    }
};