const Prog = @This();
var prog: Prog = .{};

const std = @import("std");
const lib = @import("lib.zig");

pub fn main() anyerror!void {
    lib.print(All your codebase are belong to us.");
}