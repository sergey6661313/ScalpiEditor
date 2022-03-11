const TextLine = @This();
const std      = @import("std");
const Prog     = @import("root");
const prog     = Prog.prog;
const lib      = @import("lib.zig");
pub const  size      = 512;
used:      usize,
buffer:    [size]u8,
pub fn fromText            (text: []const u8) !TextLine {
var self: TextLine = undefined;
self.used = 0;
try self.set(text);
return self;
}
pub fn get                 (self: *const TextLine) []const   u8 {
    return self.buffer[0 .. self.used];
}
pub fn getRunesCount       (self: *const TextLine, rune: u8) usize { // used for folding on brackets
  var count: usize = 0;
  var text:  []const u8 = self.get();
  for (text) |r| {
    if (r == rune) count += 1; 
  }
  return count;
}
pub fn find                (self: *const TextLine, text: []const u8, start_pos: usize) ?usize { // pos  
const self_text = self.get();
if (self.used < text.len)  return null;
if (self.used < start_pos) return null;
var pos: usize = start_pos;
while (true) {
if (self.used - pos < text.len) return null;
if (lib.cmp(self_text, text) == .equal) return pos;
pos += 1;
if (pos >= self.used) return null;
}
}
pub fn add                 (self: *TextLine, rune: u8) !void {
if (self.used >= size) unreachable;
if (self.used == size - 1) return error.LineIsFull;
self.buffer[self.used] = rune;
self.used += 1;
}
pub fn set                 (self: *TextLine, text: []const u8) !void {
if (text.len > size) return error.TextIsToLong;
std.mem.copy(u8, self.buffer[0..], text);
self.used = text.len;
}
pub fn insert              (self: *TextLine, pos: usize, rune: u8) !void {
if (self.used > size) unreachable;
if (pos       > size) unreachable;
if (self.used == size - 1) return error.LineIsFull;
if (pos > self.used)   return error.UnexpectedPos;
if (pos < self.used)   { // shiftSymbolsToRight
const from = self.buffer[pos      ..  self.used    ];
const dest = self.buffer[pos + 1  ..  self.used + 1];
std.mem.copyBackwards(u8, dest, from);
}
self.buffer[pos] = rune;
self.used += 1;
}
pub fn delete              (self: *TextLine, pos: usize) !void {
if (self.used >  size)    unreachable;
if (self.used == 0)       return error.LineIsEmpty;
if (pos >  size - 1)      unreachable;
if (pos >  self.used - 1) return error.UnexpectedPos;
if (pos != self.used - 1) { // shiftSymbolsToLeft
const from = self.buffer[pos + 1  ..  self.used    ];
const dest = self.buffer[pos      ..  self.used - 1];
std.mem.copy(u8, dest, from);
}
self.used -= 1;
} // end fn
pub fn getSantieled        (self: *TextLine) [:0]const u8 {
self.buffer[self.used] = 0;
return self.buffer[0 .. self.used :0];
}
// { indent
pub fn countIndent         (self: *const TextLine, tabsize: usize) usize {
var count: usize = 0;
var text = self.get();
for (text) |r| {
switch(r) {
' '  => count += 1,
'\t' => count += tabsize,
else => break,
}
}
return count;
}
pub fn countNonIndent      (self: *const TextLine) usize {
const indent = self.countIndent(1);
return self.used - indent;
}
pub fn addIndent           (self: *TextLine, count: usize) !void {
const last_indent = self.countIndent(1);
const last_start  = last_indent;
const last_end    = self.used;
const new_start   = last_indent + count;
const new_end     = self.used   + count;
if (new_end > size - 1) return error.LineIsFull;
std.mem.copyBackwards(u8, self.buffer[new_start .. new_end], self.buffer[last_start .. last_end]);
for (self.buffer[last_indent .. last_indent + count]) |*rune| rune.* = ' '; // fill spaces
self.used = new_end;
}
pub fn removeIndent        (self: *TextLine, count: usize) !void {
const last_indent = self.countIndent(1);
if (last_indent < count) return error.CountIsBiggerThanExistIndent;
const last_start  = last_indent;
const last_end    = self.used;
const new_start   = last_indent - count;
const new_end     = self.used   - count;
std.mem.copy(u8, self.buffer[new_start .. new_end], self.buffer[last_start .. last_end]);
self.used = new_end;
}
pub fn changeIndent        (self: *TextLine, new_indent: usize) !void {
  const indent = self.countIndent(1);
  if (new_indent == indent) {return;}
  else if (new_indent > indent) { 
    const delta = new_indent - indent;
    try self.addIndent(delta);
  } 
  else { // new_indent < indent
    const delta = indent - new_indent;
    try self.removeIndent(delta);
  }
}
// }