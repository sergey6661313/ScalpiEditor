const std = @import("std");
const ansi = @import("ansi.zig");
pub fn main() anyerror!void {
  std.log.info("Test color: {s} *** {s}", .{ansi.color.black, ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.red,   ansi.reset});
  std.log.info("Test color: {s} *** {s} {s} deleted line", .{ansi.color.green,   ansi.reset, ansi.clear_line});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.yellow,   ansi.reset});
  std.log.info("Test color: {s} *** {s} {s}\r deleted line 2", .{ansi.color.magenta,   ansi.reset, ansi.clear_line});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.blue,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.cyan,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.white,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.zero,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.black2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.red2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.green2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.yellow2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.blue2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.magenta2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.cyan2,   ansi.reset});
  std.log.info("Test color: {s} *** {s}", .{ansi.color.white2,   ansi.reset});
}
