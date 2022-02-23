const std  = @import("std");
const File = @import("File.zig");
pub fn main() anyerror!void {
    var file: File = .{};
    std.log.info("file.handle = {}", .{file.handle});
    try file.open("src/main.zig", .toRead);
    defer file.close() catch unreachable;
    std.log.info("file.handle = {}", .{file.handle.?});
    const size = try file.getSize();
    std.log.info("size = {}", .{size});
}
test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
