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

// zig fmt: off
pub const ansi = struct {
    pub const esc     = "\x1B";
    pub const control = esc ++ "[";
    pub const reset   = control ++ "0m";
    pub const bold    = control ++ "1m";
    pub const dim     = control ++ "2m";

    pub const Colors = struct {
        pub const red    = control ++ "31;1m";
        pub const green  = control ++ "32;1m";
        pub const __c33  = control ++ "33;1m";
        pub const __c34  = control ++ "34;1m";
        pub const __c35  = control ++ "35;1m";
        pub const cyan   = control ++ "36;1m";
        pub const white  = control ++ "37;1m";
        pub const __c38  = control ++ "38;1m";
        pub const __c39  = control ++ "39;1m";
    };
};
// zig fmt: on


pub const Coor2u = struct {
    x: usize,
    y: usize,

    pub fn isNotSmaller(self: *Coor2u, target: *Coor2u) bool {
        if(self.x < target.x) return false;
        if(self.y < target.y) return false;
        return true;
    }

    pub fn isBigger(self: *Coor2u, target: *Coor2u) bool {
        if (self.x > target.x) return true;
        if (self.y > target.y) return true;
        return false;
    }
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

pub fn createBufferScreen(self: *Main, _size: ?*Coor2u) error{
    SizeIsBiggestFromConsole,
    Oops,
}!void {
    var size: Coor2u = undefined;
    if (_size) |s| {
        if (size.isBigger(self.console.size)) return error.SizeIsBiggestFromConsole;
        size = s;
    } else {
        size = self.console.size;
    }
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
