const TextLine = @This();
const std      = @import("std");
const Prog     = @import("root");
const prog     = &Prog.prog;
pub const size      = 254;
buffer:   [size]u8  = undefined,
used:     usize     = 0,
pub fn insert              (self: *TextLine, pos: usize, rune: u8) !void {
    if (self.used > size) unreachable;
    if (pos       > size) unreachable;
    if (self.used == size - 1) return error.LineIsFull;
    if (pos > self.used)   return error.UnexpectedPos;
    if (pos < self.used)   { // shiftSymbolsToRight
        const from = self.buffer[pos      ..  self.used    ];
        const dest = self.buffer[pos + 1  ..  self.used + 1];
        std.mem.copyBackwards(u8, dest, from);
    }
    self.buffer[pos] = rune;
    self.used += 1;
}
pub fn delete              (self: *TextLine, pos: usize) !void {
    if (self.used >  size)    unreachable;
    if (self.used == 0)       return error.LineIsEmpty;
    if (pos >  size - 1)      unreachable;
    if (pos >  self.used - 1) return error.UnexpectedPos;
    if (pos != self.used - 1) { // shiftSymbolsToLeft
        const from = self.buffer[pos + 1  ..  self.used    ];
        const dest = self.buffer[pos      ..  self.used - 1];
        std.mem.copy(u8, dest, from);
    }
    self.used -= 1;
} // end fn
pub fn get                 (self: *TextLine) []u8 {
    return self.buffer[0 .. self.used];
}
pub fn set                 (self: *TextLine, text: []const u8) void {
    if (text.len > size) unreachable;
    std.mem.copy(u8, self.buffer[0..], text);
    self.used = text.len;
}
pub fn getRunesCount       (self: *TextLine, rune: u8) usize {
  var count: usize = 0;
  var text:  []u8  = self.get();
  for (text) |r| {
    if (r == rune) count += 1; 
  }
  return count;
}
pub fn getFirstRunesCount  (self: *TextLine, rune: u8) usize {
  var count: usize = 0;
  var text:  []u8 = self.get();
  for (text) |r| {
    if (r == rune) {
      count += 1;
    }
    else { 
      break;
    }
  }
  return count;
}
pub fn countIndent         (self: *TextLine) usize {
  var count: usize = 0;
  var text = self.get();
  for (text) |r| {
    switch(r) {
      ' ', '\t' => count += 1,
      else => break,
    }
  }
  return count;
}