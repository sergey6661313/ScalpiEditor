// { usage:
  // just call update unreaded
  // and use grab in loop for get keys
// } 

const Self = @This();
const std  = @import("std");
const Prog = @import("root");
const ansi = Prog.ansi;
pub const c = @cImport({
  @cInclude("stdio.h");
  @cInclude("sys/ioctl.h");
  @cInclude("unistd.h");
});
pub const KeyTag      = enum {
  sequence,
  byte,
  ascii_key,
};
pub const Key         = union(KeyTag) {
  sequence:   ansi.Sequence,
  byte:       u8,
  ascii_key:  ansi.AsciiKey,
}; 
ungrabed:     usize   = 0,
unreaded:     usize   = 0,
buffer:       [8]u8   = .{0}**8,
debug_buffer: [8]u8   = .{0}**8,
is_paste:     bool    = false,
pub fn updateUnreaded  (self: *Self) void  {
  var bytesWaiting: c_int = undefined;
  _ = c.ioctl(0, c.FIONREAD, &bytesWaiting);
  var count = @intCast(usize, bytesWaiting);
  self.unreaded = count;
  if (self.unreaded > 8) {self.is_paste = true;}
  else {self.is_paste = false;}
}
pub fn grab            (self: *Self) ?Key  {
  while (self.ungrabed <  8 and self.unreaded >  0) {
    _ = c.read(0, &self.buffer[self.ungrabed], 1);
    self.ungrabed += 1;
    self.unreaded -= 1;
  }
  if (self.ungrabed == 0) return null;
  if (ansi.Sequence.Parser.fromDo(self.buffer[0..self.ungrabed])) |parser| {
    self.shift(parser.used);
    const key: Key = .{.sequence = parser.sequence};
    return key;
  }
  else if (self.buffer[0] > 127) {
    const byte = self.buffer[0];
    self.shift(1);
    const key: Key = .{.byte = byte};
    return key;
  }
  else { // return ascii
    const ascii_key = @intToEnum(ansi.AsciiKey, self.buffer[0]);
    self.shift(1);
    const key: Key = .{.ascii_key = ascii_key};
    return key;
  }
}
fn shift (self: *Self, val: usize) void {
  std.mem.copy(u8, self.debug_buffer[0..],     self.debug_buffer[val..]);
  std.mem.copy(u8, self.debug_buffer[8-val..], self.buffer      [0..val]);
  std.mem.copy(u8, self.buffer      [0..],     self.buffer      [val..]);
  self.ungrabed -= val;
}
