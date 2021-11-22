const std = @import("std");

pub const c = @cImport({
    // canonical c
    @cInclude("stdio.h");
    @cInclude("stdlib.h");

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


pub const Coor2u = struct {
    x: usize,
    y: usize,

    pub fn isNotSmaller(self: *Coor2u, target: *Coor2u) bool {
        if (self.x < target.x) return false;
        if (self.y < target.y) return false;
        return true;
    }

    pub fn isBigger(self: *Coor2u, target: *Coor2u) bool {
        if (self.x > target.x) return true;
        if (self.y > target.y) return true;
        return false;
    }
};


pub fn printRune(rune: u8) void {
    _ = c.fputc(rune, c.stdout);
    _ = c.fflush(c.stdout);
    std.time.sleep(std.time.ns_per_ms * 1);
}


pub fn print(text: []const u8) void {
    for (text) |ch| {
        _ = c.fputc(ch, c.stdout);
        _ = c.fflush(c.stdout);
        std.time.sleep(std.time.ns_per_ms * 1);
    }
}


pub fn cmp(a: []u8, b: []u8) enum { equal, various } {
    if (a.len != a.len) return .various;
    var pos: usize = 0;
    const last = a.len - 1;
    while (true) {
        if (a[pos] != b[pos]) return .various;
        if (pos == last) return .equal;
        pos += 1;
    }
}