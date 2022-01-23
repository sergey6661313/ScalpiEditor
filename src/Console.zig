// zig fmt: off
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
    pub fn move        (self: *Cursor, new_pos: Coor2u) void {
        move_from_x: {
            if (new_pos.x == self.pos.x) break :move_from_x;
            if (new_pos.x > self.pos.x) {
                self.shiftRight(new_pos.x - self.pos.x);
            } else {
                self.shiftLeft(self.pos.x - new_pos.x);
            }
        }
        move_from_y: {
            if (new_pos.y == self.pos.y) break :move_from_y; 
            if (new_pos.y > self.pos.y) {
                self.shiftDown(new_pos.y - self.pos.y);
            } else {
                self.shiftUp(self.pos.y - new_pos.y);
            }
        }
    }
    pub fn shiftLeft   (self: *Cursor, pos: usize) void {
        var buffer: [254]u8 = undefined;
        const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dD", pos));
        lib.print(buffer[0..buffer_count]);
        self.pos.x -= pos;
    }
    pub fn shiftRight  (self: *Cursor, pos: usize) void {
        var buffer: [254]u8 = undefined;
        const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dC", pos)); // ^ESC[6C
        lib.print(buffer[0..buffer_count]);
        self.pos.x += pos;
    }
    pub fn shiftUp     (self: *Cursor, pos: usize) void {
        var buffer: [254]u8 = undefined;
        const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dA", pos));
        lib.print(buffer[0..buffer_count]);
        self.pos.y -= pos;
    }
    pub fn shiftDown   (self: *Cursor, pos: usize) void {
        var buffer: [254]u8 = undefined;
        const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dB", pos));
        lib.print(buffer[0..buffer_count]);
        self.pos.y += pos;
    }
};
size:                Coor2u           = .{ .x = 0, .y = 0 },
stdin_system_flags:  c.struct_termios = undefined,
stdout_system_flags: c.struct_termios = undefined,
cursor:              Cursor           = .{},
pub fn init                 (self: *Console) void {
    //{ save std in/out settings
        const f_stdin = c.fileno(c.stdin);
        const f_stdout = c.fileno(c.stdout);
        _ = c.tcgetattr(f_stdin, &self.stdin_system_flags);
        _ = c.tcgetattr(f_stdout, &self.stdout_system_flags);
    //}
    //{ set special flags
        var flags: c.struct_termios = undefined;
        //{ for stdin
            _ = c.tcgetattr(f_stdin, &flags);

            flags.c_oflag &= ~(  // disable iflags
              @as(c_uint, lib.c.OPOST)   | // add \r after \n
              0
            );
            flags.c_cflag |=  (  // enable  cflags
              @as(c_uint, lib.c.CS8)     |
              0
            );
            flags.c_iflag &= ~(  // disable iflags
              @as(c_uint, lib.c.IGNBRK)  |
              @as(c_uint, lib.c.BRKINT)  |
              @as(c_uint, lib.c.IXON)    | // catch Ctrl+s and Ctrl+q
              @as(c_uint, lib.c.ICRNL)   | // fix Ctrl+m
              @as(c_uint, lib.c.IXOFF)   |
              @as(c_uint, lib.c.INPCK)   | 
              @as(c_uint, lib.c.ISTRIP)  |
              0
            );
            flags.c_lflag &= ~(  // disable lflags
              @as(c_uint, lib.c.ISIG)    | // catch Ctrl+c and Ctrl+z
              @as(c_uint, lib.c.ICANON)  |
              @as(c_uint, lib.c.ECHO)    |
              @as(c_uint, lib.c.ECHOE)   |
              @as(c_uint, lib.c.TOSTOP)  |
              @as(c_uint, lib.c.IEXTEN)  | // catch Ctrl+v
              0
            );
            flags.c_lflag |=  (  // enable  lflags
              @as(c_uint, lib.c.ECHOCTL) |
              0
            );
            flags.c_cc[lib.c.VMIN]  = 0;
            flags.c_cc[lib.c.VTIME] = 0;

            _ = c.tcsetattr(f_stdin, c.TCSAFLUSH, &flags);
        //}
        //{ for std out
            _ = c.tcgetattr(f_stdout, &flags);
            flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
            _ = c.tcsetattr(f_stdout, c.TCSANOW, &flags);
        //}
    //}
    self.updateSize();
    self.initBlankLines();
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
    self.size.y = w.ws_row - 3;
}
pub fn printRune            (self: *Console, rune: u8) void {
    if (self.cursor.pos.x >= self.size.x) unreachable;
    if (self.cursor.pos.y >= self.size.y) unreachable;
    switch (rune) {
        0...31,
        127...255
        =>  {
            lib.print(ansi.bg_color.red2);
            lib.printRune(' ');
            lib.print(ansi.reset);
        },
        else => {
            lib.printRune(rune);
        },
    }
    //~ lib.printRune(rune);
    self.cursor.pos.x += 1;
}
pub fn print                (self: *Console, text: []const u8) void {
    if (text.len > self.size.x) {
        for (text[0..self.size.x - 1]) |rune| {
            self.printRune(rune);
        }
        lib.print(ansi.color.red);
        self.printRune('>');
        lib.print(ansi.reset);
    } else {
        for (text) |rune| {
            self.printRune(rune);
        }
    }
}
pub fn cursorMoveToEnd      (self: *Console) void {
    self.cursor.move(.{.x = 0, .y = self.size.y});
}
pub fn cursorMove           (self: *Console, pos: Coor2u) void {
    if (pos.x > self.size.x) unreachable;
    if (pos.y > self.size.y) unreachable;
    self.cursor.move(pos);
}
pub fn cursorMoveToNextLine (self: *Console) void {
    self.cursor.move(.{.x = 0, .y = self.cursor.pos.y + 1});
    if (self.cursor.pos.x > self.size.x) unreachable;
    if (self.cursor.pos.y > self.size.y) unreachable;
}
pub fn clear                (self: *Console) void {
    var pos_y: usize = 0; 
    while (pos_y < self.size.y) {
        self.cursorMove(.{.x = 0, .y = pos_y});
        self.fillSpacesToEndLine();
        pos_y += 1;
    } // end while
} // end fn clear
pub fn initBlankLines       (self: *Console) void {
    self.cursorMove(.{.x = 0, .y = 0});
    var pos_y: usize = 0; 
    while (pos_y < self.size.y) {
        lib.printRune('\n');
        pos_y += 1;
        self.cursor.pos.y += 1;
    } // end while
} // end fn clear
pub fn fillSpacesToEndLine  (self: *Console) void {
    while (self.cursor.pos.x < self.size.x) {
        lib.printRune(' ');
        self.cursor.pos.x += 1;
    }
}
pub fn printLine            (self: *Console, text: []u8, pos_y: usize) void {
    self.cursorMove(.{.x = 0, .y = pos_y});
    self.print(text);
    self.fillSpacesToEndLine();
} 
