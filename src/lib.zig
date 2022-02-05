const std = @import("std");
pub const c          = @cImport({
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
pub const Coor2u     = struct {
    x: usize = 0,
    y: usize = 0,

    pub fn isNotSmaller  (self: *Coor2u, target: *Coor2u) bool {
        if (self.x < target.x) return false;
        if (self.y < target.y) return false;
        return true;
    }
    pub fn isBigger      (self: *Coor2u, target: *Coor2u) bool {
        if (self.x > target.x) return true;
        if (self.y > target.y) return true;
        return false;
    }
};
pub const File       = struct {
    //{ defines
        const Method = enum {
            ToRead,
            ToWrite
        };
        const Errors = error {
            FileNotExist,
            Unexpected,
        };
    //}
    //{ fields
        handle: *c.struct__IO_FILE = undefined,
    //}
    //{ methods
        pub fn open    (self: *File, name: []const u8, method: Method) Errors!void {
            // DODO use zig api for file, but ONLY after zig release
            switch (method) {
                .ToRead  => {
                    self.handle = c.fopen(name.ptr, "rb") orelse return error.FileNotExist;
                },
                .ToWrite => {
                    self.handle = c.fopen(name.ptr, "wb") orelse return error.Unexpected;
                },
            }
        }
        pub fn close   (self: *File) !void {
            var fcloseResult = c.fclose(self.handle);
            if (fcloseResult != 0) return error.Unexpected;
        }
        pub fn getSize (self: *File) !usize {
            _ = c.fseek(self.handle, 0, c.SEEK_END);
            const size      = c.ftell(self.handle);
            const err_value = std.math.maxInt(u32);
            if (size == err_value) return error.Unexpected;
            return @intCast(usize, size);
        }
        pub fn loadTo  (self: *File, buffer: []u8) !void {
            _ = c.fseek(self.handle, 0, c.SEEK_SET);
            const freadResult = c.fread(buffer.ptr, 1, buffer.len, self.handle);
            if (freadResult != buffer.len) return error.Unexpected;
        }
        pub fn write   (self: *File, data: []const u8) void {
            _ = c.fwrite(data.ptr, 1, data.len, self.handle);
        }
    //}

};
pub const CmpResult  = enum { equal, various };
pub fn printRune            (rune: u8) void {
    _ = c.fputc(rune, c.stdout);
    _ = c.fflush(c.stdout);
}
pub fn print                (text: []const u8) void {
    for (text) |ch| {
        printRune(ch);
    }
}
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
pub fn findSymbol           (text: []const u8, symbol: u8) ?usize {
    for(text) |rune, id| {
        if (rune == symbol) return id;
    }
    return null;
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
pub fn loadFile             (name: []const u8) File.Errors![]u8 {
    var file: File = .{};
    try file.open(name, .ToRead);
    defer file.close() catch unreachable; // this is NOT unreachable, but zig not supports error in defer 0_o
    const size   = try file.getSize();
    const buffer = try alloc(size);
    try file.loadTo(buffer);
    return buffer;
}
pub fn alloc                (size: usize) ![]u8 {
    // DODO rewrite this to zig allocator, but ONLY after zig release
    const memory_ptr = c.malloc(size) orelse return error.Unexpected;
    const buffer = @ptrCast([*]u8, memory_ptr)[0..size]; //? how to normal syntax to create slice?
    return buffer;
}
pub fn getTextFromArgument  () error{Unexpected} ![]const u8 {
    var argIterator_packed = std.process.ArgIterator.init();
    var argIterator        = &argIterator_packed.inner;
    _ = argIterator.skip(); // skip name of programm
    var arg = argIterator.next() orelse return error.Unexpected;
    return arg;
}
pub fn findRune(_rune: u8, text: []u8, _pos: usize) ?usize {
  var pos = _pos;
  while(true) {
    const rune = text[pos];
    if (rune == _rune) return pos;
    if (pos == text.len - 1) break;
    pos += 1;
  }
  return null;
}
pub fn findRuneReversed(_rune: u8, text: []u8, _pos: usize) ?usize {
  var pos = _pos;
  while(true) {
    const rune = text[pos];
    if (rune == _rune) return pos;
    if (pos == 0) break;
    pos -= 1;
  }
  return null;
}

