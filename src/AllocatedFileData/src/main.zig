const std               = @import("std");
const AllocatedFileData = @import("AllocatedFileData.zig");

pub fn main() anyerror!void {
    var allocated_file_data = try AllocatedFileData.fromName("src/main.zig");
    defer allocated_file_data.deInit() catch unreachable;
    std.log.info("All your codebase are belong to us: \n{s}", .{allocated_file_data.slice});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
