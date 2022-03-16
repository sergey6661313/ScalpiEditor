const Line                 = @This();
const std                  = @import("std");
const Prog                 = @import("root");
const prog                 = Prog.prog;
pub const Text             = @import("Text.zig");
pub const RuneIteratorUtf8 = struct {};
text:    Text   = .{},
next:    ?*Line = null,
prev:    ?*Line = null,
parent:  ?*Line = null,
child:   ?*Line = null,
num:     usize  = 0,
pub fn pushPrev            (self: *Line, new_line: *Line) void {
  { // update chain
    if (self.prev) |prev| {
      prev.next = new_line;
      new_line.prev = prev;
    } // end if
    self.prev = new_line;
    new_line.next = self;
  }
  { // update tree
    if (self.parent) |parent| {
      self.parent = null;
      parent.child = new_line;
      new_line.parent = parent;
    }
  }
} // end fn
pub fn pushNext            (self: *Line, new_line: *Line) void {
  { // update chain
    if (self.next) |next| {
      next.prev = new_line;
      new_line.next = next;
    } // end if
    self.next = new_line;
    new_line.prev = self;
  } // update chain
} // end fn add
pub fn getFirst            (self: *Line) *Line {
  var line = self;
  while(line.prev) |prev| line = prev;
  return line;
}
pub fn getParent           (self: *Line) ?*Line {
  var first = self.getFirst();
  return first.parent;
}
pub fn getLastChild        (self: *Line) ?*Line {
  if (self.child) |first| {
    var current = first;
    while (current.next) |next| current = next;
    return current;
  } else return null;
}
pub fn changeIndentToCutie (self: *Line) !void {
  var new_indent: usize = 0;
  if (self.prev) |prev| {new_indent = prev.text.countIndent(1);}
  else if (self.parent) |parent| {new_indent = parent.text.countIndent(1) + 2;}
  try self.text.changeIndent(new_indent);
}