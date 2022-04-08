const Self = @This();
const std  = @import("std");
const Allocator = std.mem.Allocator;
const Allocator = std.heap.page_allocator;

// depensies
const file = @import("File/src/File.zig");

// fields
file: File    = {},
data: ?[]u8   = null,

fn read(self: *Self, allocator: Allocator, name: []u8) !void {
  self.file.setName(name);
  try self.file.open();
  const size   = self.file.getSize();
  const buffer = allocator.alloc(u8, size);
  self.data    = buffer;
}