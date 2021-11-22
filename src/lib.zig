const std = @import("std");
const expect = std.testing.expect;

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


pub fn findSymbol(text: []const u8, symbol: u8) ?usize {
    for(text) |rune, id| {
        if (rune == symbol) return id;
    }
    return null;
}
pub fn countSymbol(text: []const u8, symbol: u8) usize {
    var count: usize = 0;
    for(text) |rune| {
        if (rune == symbol) count += 1;
    }
    return count;
}


pub fn u64FromCharsDec(data: []const u8) error{
    NotNumber,
    Unexpected,
}!u64 {
    const MAX_LEN = "18446744073709551615".len; // UINT64_MAX
    if (data.len > MAX_LEN) return error.Unexpected;
    var result: u64 = 0;
    var numerical_place: usize = 1;
    var pos: usize = data.len - 1; // last symbol
    while(true) {
        const value: usize = switch(data[pos]) {
            '0' => 0,
            '1' => 1,
            '2' => 2,
            '3' => 3,
            '4' => 4,
            '5' => 5,
            '6' => 6,
            '7' => 7,
            '8' => 8,
            '9' => 9,
            else => return error.NotNumber,
        };
        result += value * numerical_place;
        if (pos == 0) return result;
        numerical_place *= 10;
        pos -= 1;
    }
}



fn printedTest(data: []const u8, expected: u64) !void {
    const result = try u64FromCharsDec(data);
    std.log.info("expected {} received {}", .{ expected, result });
    try expect(expected == result);
}

pub fn u64FromCharsDec_tests() !void {
    try printedTest("0", 0);
    try printedTest("1", 1);
    try printedTest("10", 10);
    try printedTest("2", 2);
    try printedTest("20", 20);
    try printedTest("200", 200);
    try printedTest("8", 8);
    try printedTest("16", 16);
    try printedTest("32", 32);
    try printedTest("64", 64);
    try printedTest("128", 128);
    try printedTest("256", 256);
    try printedTest("9223372036854775807", 9223372036854775807);
    try printedTest("9223372036854775808", 9223372036854775808);
    try printedTest("18446744073709551615", 18446744073709551615);
}