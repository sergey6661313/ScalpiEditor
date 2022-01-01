const std = @import("std");
const expect = std.testing.expect;

//defines
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

// methods
pub fn printRune(rune: u8) void {
    _ = c.fputc(rune, c.stdout);
    _ = c.fflush(c.stdout);
    //~ std.time.sleep(std.time.ns_per_ms * 1);
}
pub fn print(text: []const u8) void {
    for (text) |ch| {
        printRune(ch);
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
pub fn loadFile(name: []const u8) error{
    FileNotExist,
    Unexpected,
}![]u8 {
    // TODO check - file exits?
    // open file DODO use zig api for file, but ONLY after zig release
    const handle: *c.struct__IO_FILE = c.fopen(name.ptr, "rb") orelse return error.FileNotExist;
    defer {
        var fcloseResult = c.fclose(handle);
        if (fcloseResult != 0) unreachable; // this is NOT unreachable, but zig not supports error in defer 0_o
    }

    // read file size
    _ = c.fseek(handle, 0, c.SEEK_END);
    const size = @intCast(usize, c.ftell(handle));
    const err_value = std.math.maxInt(u32);
    if (size == err_value) return error.Unexpected;

    // allock memory for file
    // DODO rewrite this to zig allocator, but ONLY after zig release
    const memory_ptr = c.malloc(size) orelse return error.Unexpected;
    const buffer = @ptrCast([*]u8, memory_ptr)[0..size]; // how to normal syntax to create slice?

    // load full file to buffer.
    _ = c.fseek(handle, 0, c.SEEK_SET);
    const freadResult = c.fread(memory_ptr, 1, size, handle);
    if (freadResult != size) return error.Unexpected;

    return buffer;
}
