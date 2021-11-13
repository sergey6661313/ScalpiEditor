const std = @import("std");
const asBytes = std.mem.asBytes;
const Main = @This();

pub fn cmp(a: []u8, b: []u8) enum {equal, various} {
    if(a.len != a.len) return .various;
    var pos: usize = 0;
    const last = a.len - 1;
    while(true) {
        if(a[pos] != b[pos]) return .various;
        if(pos == last) return .equal;
        pos += 1;
    }
}

pub const c = @cImport({
    // canonical c
    @cInclude("stdio.h");

    // linux
    @cInclude("arpa/inet.h");
    @cInclude("fcntl.h");
    @cInclude("netinet/in.h");
    @cInclude("netinet/ip.h");
    @cInclude("termios.h");
    @cInclude("sys/ioctl.h");
    @cInclude("sys/socket.h");
    @cInclude("unistd.h");
});

pub const ansi = struct {
    pub const esc = "\x1B";
    pub const control = ESC ++ "[";

    pub const Colors = struct {
        // zig fmt: off
        pub const RED   = "\x1b[31;1m";
        pub const GREEN = "\x1b[32;1m";
        pub const CYAN  = "\x1b[36;1m";
        pub const WHITE = "\x1b[37;1m";
        pub const BOLD  = "\x1b[1m";
        pub const DIM   = "\x1b[2m";
        pub const RESET = "\x1b[0m";
        // zig fmt: on
    };
};


pub const Coor2u = struct {
    x: usize,
    y: usize,
};

pub const Modes = enum {
    navigation,
    edit,
    command,
};

pub const Console = struct {
    size: Coor2u = .{.x = 0, .y = 0},

    pub fn init(self: *Console) void {
        _ = self.updateSize();
    }

    pub fn updateSize(self: *Console) bool {
        var w: c.winsize = undefined;
        _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
        var new_size: Coor2u = .{
            .x = w.ws_row,
            .y = w.ws_col,
        };
        
        if (cmp(asBytes(&self.size), asBytes(&new_size)) == .various) {
            self.size = new_size;
            return false;
        }
        return true;

    }
};

console: Console = .{},


var prog: Main = undefined;

pub fn createBufferScreen(self: *Main, _size: ?*Coor2u) error{Oops}!void {
    var size: Coor2u = undefined;
    if (_size == null) {
        size = self.console.size;
    }
    // TODO check "size is bigger self.console.size ?" then return error.
    // TODO create console buffer
}


pub fn main() error{Oops}!void {
    std.log.info("{s}:{}: Hello!", .{@src().file, @src().line});
    const self = &prog;
    self.console.init();
    try self.createBufferScreen(null);
    // TODO save file
    std.log.info("{s}:{}: Bye!", .{@src().file, @src().line});
}
