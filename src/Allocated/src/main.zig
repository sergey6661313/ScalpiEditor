// todo replace this file to example of usage Allocated
const std       = @import("std");
const Allocated = @import("Allocated.zig");

pub fn main() anyerror!void {
var allocated = try Allocated.fromSize(10);
defer allocated.deInit() catch unreachable;
if (allocated.slice) |slice| {std.log.info("slice: {any}", .{slice});}
else {std.log.info("All your codebase are belong to us.", .{});}
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
