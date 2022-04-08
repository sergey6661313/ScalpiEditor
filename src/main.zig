const std         = @import("std");
const MapableFile = @import("MapableFile.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var mapable_file = try MapableFile.fromRead(allocator, "src/main.zig");
    std.log.info("data = {s}", .{mapable_file.data.?});
}
