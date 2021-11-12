const std = @import("std");

const Modes = enum {
    navigation,
    edit,
    command,
}

pub fn main() anyerror!void {
    std.log.info("{s}:{}: Hello!", .{@src().file, @src().line});
    // TODO create buffer screen
    // TODO save file
    std.log.info("{s}:{}: Bye!", .{@src().file, @src().line});
}
