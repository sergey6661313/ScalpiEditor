const Console    = @This();
const std        = @import("std");
const asBytes    = std.mem.asBytes;
const Prog       = @import("root");
const ansi       = Prog.ansi;
const lib        = Prog.lib;
const c          = lib.c;
const Coor2u     = lib.Coor2u;
const cmp        = lib.cmp;
pub const ToggleState = enum {
enable,
disable,
};
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
size:                Coor2u            = .{ .x = 0, .y = 0 },
cursor:              Cursor            = .{},
last_flags:          c.struct_termios  = undefined,
pub fn init                 (self: *Console) void {
lib.print(ansi.reset);
var flags: c.struct_termios = undefined;
_ = c.tcgetattr(0, &flags);
_ = c.tcgetattr(0, &self.last_flags); // save for restore
{ // configure flags
const cflag = &flags.c_cflag;
const iflag = &flags.c_iflag;
const lflag = &flags.c_lflag;
const oflag = &flags.c_oflag;


// use 8 bit
toggleU32(cflag, c.CS8,    .enable);  // use 8 bit
toggleU32(cflag, c.PARENB, .disable); // parity check
toggleU32(iflag, c.ISTRIP, .disable); // do not strip


// non canonical
toggleU32(lflag, c.ICANON, .disable); // no wait '\n'


// disable all converts
toggleU32(iflag, c.INLCR,  .disable); // do not convert NL to CR
toggleU32(oflag, c.ONLCR,  .disable); // --//--
toggleU32(iflag, c.ICRNL,  .disable); // do not convert CR to NL
toggleU32(oflag, c.OCRNL,  .disable); // --//--
toggleU32(iflag, c.XCASE,  .disable); // do not convert register
toggleU32(iflag, c.IUCLC,  .disable); // --//--
toggleU32(oflag, c.OLCUC,  .disable); // --//--


// disable flow control
toggleU32(iflag, c.IXON,   .disable); // Ctrl+S Ctlr+Q
toggleU32(lflag, c.ISIG,   .disable); // Ctrl+C


// disable all echo
toggleU32(lflag, c.ECHO,   .disable); // no print pressed keys
toggleU32(lflag, c.ECHOE,  .disable); // no mashing
toggleU32(lflag, c.ECHOK,  .disable); // no print 
toggleU32(lflag, c.ECHONL, .disable); // no print NL


for (flags.c_cc) |*conf| conf.* = 0; // clear c_cc

}
_ = c.tcsetattr(0, c.TCSANOW, &flags);
self.updateSize();
self.initBlankLines();
self.clear();
self.cursorMove(.{.x = 0, .y = 0});
}
pub fn deInit               (self: *Console) void {
_ = c.tcsetattr(0,  c.TCSANOW, &self.last_flags); // restore buffer settings
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
        10, 13 => {
            lib.print(ansi.bg_color.red2);
            lib.printRune(' ');
            lib.print(ansi.reset);
        },
        0...9, 
        11...12,
        14...31,
        127...255
        =>  {
            lib.print(ansi.bg_color.black2);
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
    lib.print(ansi.reset);
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
pub fn getBytesWaiting      (self: *Console) usize {
  _ = self;
  var bytesWaiting: c_int = undefined;
  _ = lib.c.ioctl(0, lib.c.FIONREAD, &bytesWaiting);
  var count = @intCast(usize, bytesWaiting);
  return count;
}
pub fn toggleU32            (ptr: *u32, flag: u32, state: ToggleState) void {
switch (state) {
.enable  => ptr.* |= flag,
.disable => ptr.* &= ~flag,
}
}
