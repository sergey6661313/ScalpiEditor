// zig fmt: off
//{ defines
const Console    = @This();
const std        = @import("std");
const asBytes    = std.mem.asBytes;
const Prog       = @import("root");
const ansi       = Prog.ansi;
const lib        = Prog.lib;
const c          = lib.c;
const Coor2u     = lib.Coor2u;
const cmp        = lib.cmp;
pub const Cursor = struct {
    pos: Coor2u = .{},

    pub fn init        (pos: Coor2u) Cursor {
        return .{
            .pos = pos
        };
    }
    pub fn move        (self: *Cursor, x: usize, y: usize) void {
        if (x != self.pos.x) {
            if (x > self.pos.x) {
                self.shiftRight(x - self.pos.x);
            } else {
                self.shiftLeft(self.pos.x - x);
            }
        }
        if (y != self.pos.y) {
            if (y > self.pos.y) {
                self.shiftDown(y - self.pos.y);
            } else {
                self.shiftUp(self.pos.y - y);
            }
        }
    }
    pub fn shiftLeft   (self: *Cursor, pos: usize) void {
        const target = self.pos.x - pos;
        while (self.pos.x > target) {
            lib.print(ansi.control ++ "1D");
            self.pos.x -= 1;
        }
    }
    pub fn shiftRight  (self: *Cursor, pos: usize) void {
        const target = self.pos.x + pos;
        while (self.pos.x < target) {
            lib.print(ansi.control ++ "1C");
            self.pos.x += 1;
        }
    }
    pub fn shiftUp     (self: *Cursor, pos: usize) void {
        const target = self.pos.y - pos;
        while (self.pos.y > target) {
            lib.print(ansi.control ++ "1A");
            self.pos.y -= 1;
        }
    }
    pub fn shiftDown   (self: *Cursor, pos: usize) void {
        const target = self.pos.y + pos;
        while (self.pos.y < target) {
            lib.print(ansi.control ++ "1B");
            self.pos.y += 1;
        }
    }
};
//}
//{ fields
size:                Coor2u           = .{ .x = 0, .y = 0 },
stdin_system_flags:  c.struct_termios = undefined,
stdout_system_flags: c.struct_termios = undefined,
cursor:              Cursor           = .{},
//}
//{ methods
pub fn init                 (self: *Console) void {
    //{ save std in/out settings
    const f_stdin = c.fileno(c.stdin);
    const f_stdout = c.fileno(c.stdout);
    _ = c.tcgetattr(f_stdin, &self.stdin_system_flags);
    _ = c.tcgetattr(f_stdout, &self.stdout_system_flags);
    //}
    //{ turn off line buffering
    var flags: c.struct_termios = undefined;
    c.setbuf(c.stdin, null);
    c.setbuf(c.stdout, null);

    _ = c.tcgetattr(f_stdin, &flags);
    flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
    _ = c.tcsetattr(f_stdin, c.TCSANOW, &flags);

    _ = c.tcgetattr(f_stdout, &flags);
    flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
    _ = c.tcsetattr(f_stdout, c.TCSANOW, &flags);
    //}
    
    self.updateSize();
    self.clear();
}
pub fn deInit               (self: *Console) void {
    // restore buffer settings
    const f_stdin = c.fileno(c.stdin);
    _ = c.tcsetattr(f_stdin, c.TCSANOW, &self.stdin_system_flags);

    const f_stdout = c.fileno(c.stdout);
    _ = c.tcsetattr(f_stdout, c.TCSANOW, &self.stdout_system_flags);
}
pub fn updateSize           (self: *Console) void {
    var w: c.winsize = undefined;
    _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
    self.size.x = w.ws_col - 1;
    self.size.y = w.ws_row - 4;
}
pub fn printRune            (self: *Console, rune: u8) void {
    switch (rune) {
        '\r' => {
            self.cursor.pos.x = 0;
        },

        '\n' => {
            self.cursor.pos.x = 0;
            self.cursor.pos.y += 1;
        },

        else => {
            self.cursor.pos.x += 1;
        },
    }
    lib.printRune(rune);
}
pub fn print                (self: *Console, text: []const u8) void {
    if (text.len > self.size.x) {
        for (text[0..self.size.x - 1]) |rune| {
            self.printRune(rune);
        }
        lib.print(ansi.colors.__c33);
        self.printRune('>');
        lib.print(ansi.reset);
    } else {
        for (text) |rune| {
            self.printRune(rune);
        }
    }
}
pub fn cursorMoveToEnd      (self: *Console) void {
    self.cursor.move(0, self.size.y);
}
pub fn cursorMove           (self: *Console, pos: Coor2u) void {
    self.cursor.move(pos.x, pos.y);
    if (self.cursor.pos.x > self.size.x) unreachable;
    if (self.cursor.pos.y > self.size.y) unreachable;
}
pub fn clear                (self: *Console) void {
    self.cursorMove(.{.x = 0, .y = 0});
    while (true) { 
        self.fillSpacesToEndLine();
        self.print("\r\n");
        if (self.cursor.pos.y > self.size.y) break;
    } // end while
    self.cursorMoveToEnd();
} // end fn clear
pub fn fillSpacesToEndLine  (self: *Console) void {
    while (self.cursor.pos.x < self.size.x) {
        self.printRune(' ');
    }
    self.print("\r\n");
}
//}
