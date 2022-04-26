// { import
const Self      = @This();
const std       = @import("std");
const Prog      = @import("root");
const prog      = Prog.prog;
const ansi      = Prog.ansi;
pub const Rune  = @import("Rune.zig");
pub const Text  = @import("Text.zig");
// }
// { fields
text:      Text   = .{},

// tree-like
next:      ?*Self = null,
prev:      ?*Self = null,
parent:    ?*Self = null,
child:     ?*Self = null,

// flat
flat_next: ?*Self = null,
flat_prev: ?*Self = null,

len:       usize  = 0,
runes:     ?*Rune = null,
// }
// { methods
pub fn pushPrev            (self: *Self, new_line: *Self) void {
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
pub fn pushNext            (self: *Self, new_line: *Self) void {
  { // update chain
    if (self.next) |next| {
      next.prev = new_line;
      new_line.next = next;
    } // end if
    self.next = new_line;
    new_line.prev = self;
  } // update chain
} // end fn add
pub fn getFirst            (self: *Self) *Self  {
  var line = self;
  while(line.prev) |prev| line = prev;
  return line;
}
pub fn getParent           (self: *Self) ?*Self {
  var first = self.getFirst();
  return first.parent;
}
pub fn getLastChild        (self: *Self) ?*Self {
  if (self.child) |first| {
    var current = first;
    while (current.next) |next| current = next;
    return current;
  } else return null;
}
pub fn changeIndentToCutie (self: *Self) !void  {
  var new_indent: usize = 0;
  if (self.prev) |prev| {new_indent = prev.text.countIndent(1);}
  else if (self.parent) |parent| {new_indent = parent.text.countIndent(1) + 2;}
  try self.text.changeIndent(new_indent);
}
pub fn countNum            (self: *Self) usize {
  var num: usize = 0;
  var current = self;
  while(true){current = current.flat_prev orelse return num;}
}
// }