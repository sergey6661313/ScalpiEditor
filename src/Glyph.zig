const       Self    = @This();

buffer:     [16]u8  = undefined,
used:       usize   = 0,
maybe_next: ?*Self  = null,
maybe_prev: ?*Self  = null,

pub fn getText(self: *Self) []u8 {
  return self.buffer[0..self.used];
}