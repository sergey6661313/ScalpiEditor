const Self                 = @This();
const std                  = @import("std");
const Prog                 = @import("root");
const prog                 = Prog.prog;
const ansi                 = Prog.ansi;
pub const Text             = @import("Text.zig");
pub const Word             = @import("Word.zig");
text:    Text   = .{},
next:    ?*Self = null,
prev:    ?*Self = null,
parent:  ?*Self = null,
child:   ?*Self = null,
num:     usize  = 0,

words:   ?*Word = null,
size:    usize  = 0,

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