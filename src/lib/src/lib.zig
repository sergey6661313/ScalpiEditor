const do_not_compile_todo = false;
const std             = @import("std");
pub const c           = @cImport({
    // canonical c
    @cInclude("stdio.h");
    @cInclude("stdlib.h");

    // linux
    @cInclude("locale.h");
    @cInclude("arpa/inet.h");
    @cInclude("fcntl.h");
    @cInclude("netinet/in.h");
    @cInclude("netinet/ip.h");
    @cInclude("termios.h");
    @cInclude("sys/ioctl.h");
    @cInclude("sys/socket.h");
    @cInclude("unistd.h");
    @cInclude("signal.h");
});
pub const Coor2u      = struct {
    const Self = @This();
    
    x: usize = 0,
    y: usize = 0,

    pub fn isNotSmaller  (self: *const Self, target: *const Self) bool {
        if (self.x < target.x) return false;
        if (self.y < target.y) return false;
        return true;
    }
    pub fn isBigger      (self: *const Self, target: *const Self) bool {
        if (self.x > target.x) return true;
        if (self.y > target.y) return true;
        return false;
    }
};
pub const CmpResult   = enum { 
equal, 
various,
};
pub const ToggleState = enum {
enable,
disable,
};
pub fn cmp                  (a: []const u8, b: []const u8) CmpResult {
    if (a.len != b.len) return .various;
    var pos: usize = 0;
    const last = a.len - 1;
    while (true) {
        if (a[pos] != b[pos]) return .various;
        if (pos == last) return .equal;
        pos += 1;
    }
}
pub fn countSymbol          (text: []const u8, symbol: u8) usize {
    var count: usize = 0;
    for(text) |rune| {
        if (rune == symbol) count += 1;
    }
    return count;
}
pub fn u64FromCharsDec      (data: []const u8) error{NotNumber, Unexpected,}!u64 {
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
pub fn getTextFromArgument  () error{Unexpected} ![]const u8 {
    var argIterator_packed = std.process.ArgIterator.init();
    var argIterator        = &argIterator_packed.inner;
    _ = argIterator.skip(); // skip name of programm
    var arg = argIterator.next() orelse return error.Unexpected;
    return arg;
}
pub fn findSymbol           (text: []const u8, symbol: u8) ?usize {
    for(text) |rune, id| {
        if (rune == symbol) return id;
    }
    return null;
}
pub fn findRune             (_rune: u8, text: []u8, _pos: usize) ?usize {
  var pos = _pos;
  while(true) {
    const rune = text[pos];
    if (rune == _rune) return pos;
    if (pos == text.len - 1) break;
    pos += 1;
  }
  return null;
}
pub fn findRuneReversed     (_rune: u8, text: []u8, _pos: usize) ?usize {
  var pos = _pos;
  while(true) {
    const rune = text[pos];
    if (rune == _rune) return pos;
    if (pos == 0) break;
    pos -= 1;
  }
  return null;
}
pub fn toggleU32            (ptr: *u32, flag: u32, state: ToggleState) void {
switch(state) {
.enable  => ptr.* |= flag,
.disable => ptr.* &= ~flag,
}
}
pub fn todo                 (text: []u8) void {
  if (do_not_compile_todo) @compileError("TODO: implement me");
  if (std.builtin.mode == .Debug) {std.log.warn("TODO: {s}", .{text});}
}

// print
pub fn printRune            (rune: u8) void {
  _ = c.fputc(rune, c.stdout);
}
pub fn print                (text: []const u8) void {
  for (text) |ch| {
    printRune(ch);
  }
}
pub fn printFlush           () void {
  _ = c.fflush(c.stdout);
}