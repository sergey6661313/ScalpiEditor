const std         = @import("std");
const MapableFile = @import("MapableFile.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var mapable_file = MapableFile.fromRead(allocator, "asd") catch |e| {
      std.log.info("error = {}", .{e});
      return;
    };
    std.log.info("data = {s}", .{mapable_file.data.?});
}