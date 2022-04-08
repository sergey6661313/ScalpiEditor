const Self = @This();
const std  = @import("std");

// fields
file: std.fs.File = undefined,
data: ?[]u8       = null,

pub fn fromRead(allocator: std.mem.Allocator, name: []const u8) !Self {
  var self: Self = .{};
  var cwd        = std.fs.cwd();
  self.file      = try cwd.openFile(name, .{.mode = .read_only});
  defer self.file.close();
  const size     = try self.file.getEndPos();
  if (size == 0) return self;
  self.data      = try allocator.alloc(u8, size);
  const readed = try self.file.readAll(self.data.?);
  if (readed < size) unreachable;
  return self;
}