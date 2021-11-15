const std = @import("std");
const asBytes = std.mem.asBytes;
const Prog = @This();

pub fn print(text: []const u8) void {
    for (text) |ch| {
        _ = c.fputc(ch, c.stdout);
        _ = c.fflush(c.stdout);
        std.time.sleep(std.time.ns_per_ms * 5);
    }
}

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
    system_flags: c.struct_termios = undefined, 

    pub fn init(self: *Console) void {
        // Use termios to turn off line buffering to input
        const f_stdin = c.fileno(c.stdin); 
        var term: c.termios = undefined;
        self.system_flags = term;
        _ = c.tcgetattr(f_stdin, &term);
        term.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
        c.setbuf(c.stdin, null);
        _ = c.tcsetattr(f_stdin, c.TCSANOW, &term);

        _ = self.updateSize();
    }

    pub fn deInit(self: *Console) void {
        // return buffer settings
        const f_stdin = c.fileno(c.stdin); 
        _ = c.tcsetattr(f_stdin, c.TCSANOW, &self.system_flags);
    }

    pub fn updateSize(self: *Console) bool {
        var w: c.winsize = undefined;
        _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
        var new_size: Coor2u = .{
            .x = w.ws_col,
            .y = w.ws_row,
        };
        
        if (cmp(asBytes(&self.size), asBytes(&new_size)) == .various) {
            self.size = new_size;
            return false;
        }
        return true;

    }
};

console: Console = .{},


var prog: Prog = undefined;

pub fn createBufferScreen(self: *Prog, _size: ?*Coor2u) error{
    SizeIsBiggestFromConsole,
    Oops,
}!void {
    var size: Coor2u = undefined;
    if (_size) |s| {
        if (size.isBigger(&self.console.size)) return error.SizeIsBiggestFromConsole;
        size = s.*;
    } else {
        size = self.console.size;
    }

    std.log.info("size is {}", .{size});
    // screen alloc and clear screen
    {
        var pos: usize = 0;
        while(true) {
            print("\n");
            var spaces: usize = 0;
            while(true){
                print(" ");
                if(spaces == size.x - 1) break;
                spaces += 1;
            }
            if(pos == size.y - 1) break;
            pos += 1;
        }
    }
}


pub fn main() error{
    BufferNotCreated,
    Oops,
}!void {
    std.log.info("{s}:{}: Hello!", .{@src().file, @src().line});
    const self = &prog;
    self.console.init();
    self.createBufferScreen(null) catch return error.BufferNotCreated;
    // TODO save file
    std.log.info("{s}:{}: Bye!", .{@src().file, @src().line});
}
