// { imports
const     Prog         = @This();
const     std          = @import("std");
pub const ansi         = @import("ansi.zig");
pub const lib          = @import("lib.zig");
pub const ParsePath    = @import("ParsePath.zig");
pub const Line         = @import("Line.zig");
pub const Console      = @import("Console.zig");
pub const AllocatedFileData = @import("AllocatedFileData/src/AllocatedFileData.zig");
pub const File         = @import("File/src/File.zig");
// }
// { defines
pub const Buffer       = struct {
pub const size = 25000; // about 10 mb...
lines:         [size]Line,
free:          ?*Line,
cutted:        ?*Line,
find_text:     ?*Line,
to_goto:       ?*Line,
to_find:       ?*Line,
line_for_goto: usize,
pub fn fromInit     () !*Buffer {
const allocated    = lib.c.aligned_alloc(8, @sizeOf(Buffer)) orelse return error.NeedMoreMemory;
var buffer: *Buffer = @ptrCast(*Buffer, @alignCast(8, allocated));
try buffer.init();
return buffer;
}
pub fn init         (self: *Buffer) !void {
self.cutted        = null;
self.find_text     = null;
self.to_goto       = null;
self.to_find       = null;
self.line_for_goto = 0;
for (self.lines) |*line| { // init all lines:
line.* = try Line.fromInit();
}
//{ tie all lines to "free" chain
const first = &self.lines[0];
const last = &self.lines[size - 1];
//{  update ends of range
first.next = &self.lines[1];
last.prev = &self.lines[size - 2];
//}
{ // update others everything in between first and last
var pos: usize = 1;
while (true) {
const current = &self.lines[pos];
current.prev = &self.lines[pos - 1];
current.next = &self.lines[pos + 1];
pos += 1;
if (pos == size - 1) break;
}
}
//}
self.free = &self.lines[0];
} // end fn init
pub fn create       (self: *Buffer) !*Line {
if (self.free) |free| {
self.free = free.next; // update self.free
const line = free;
try line.init();
return line;
} else return error.NoFreeSlots;
}
pub fn delete       (self: *Buffer, line: *Line) void {
if (line.child) |_| self.deleteBlock(line) else self.deleteLine(line);
} // end fn delete
pub fn deleteBlock  (self: *Buffer, line: *Line) void {
const start_line = line;
const end_line = start_line.next;
prog.view.unFold();
var current: ?*Line = start_line;
while (current) |cur_line| {
if (current == end_line) break;
current = cur_line.next;
self.deleteLine(cur_line);
}
} // end fn deleteBlock
pub fn deleteLine   (self: *Buffer, line: *Line) void {
//{ change links
if (line.prev) |prev| {
prev.next = line.next;
}
if (line.next) |next| {
next.prev = line.prev;
}
if (line.parent) |parent| {
parent.child = line.next;
if (line.next) |next| {
next.parent = parent;
}
}
line.prev = null;
line.next = null;
line.parent = null;
//}
//{ add to free
line.next = self.free;
self.free = line;
//}
} // end fn deleteLine
pub fn cut          (self: *Buffer, line: *Line) void {
//{ change links
if (line.prev) |prev| {
prev.next = line.next;
}
if (line.next) |next| {
next.prev = line.prev;
}
if (line.parent) |parent| {
parent.child = line.next;
if (line.next) |next| {
next.parent = parent;
}
}
line.prev = null;
line.next = null;
line.parent = null;
//}
//{ add to cutted
line.next = self.cutted;
self.cutted = line;
//}
}
pub fn lineToPos    (self: *Buffer, line: *Line) usize {
const ptr = @ptrToInt(line) - @ptrToInt(&self.lines);
const pos = ptr / @sizeOf(Line);
return pos;
}
};
pub const View         = struct {
pub const Mode = enum {
edit,
to_find,
to_line,
history,
select,
normal,
};
mode:        Mode        = .edit,
file_name:   [1024]u8    = undefined,
first:       *Line       = undefined,
line:        *Line       = undefined,
symbol:      usize       = 0,
offset:      lib.Coor2u  = .{ .y = 1 },
focus:       bool        = false,
last_line:   ?*Line      = null,
selected:    usize       = 0,
marked_line: ?*Line      = null,
bakup_line:  *Line       = undefined,
pub fn init                 (self: *View, file_name: [:0]const u8, text: []const u8) !void {
self.* = .{};
self.setFileName(file_name);
self.first = try prog.buffer.create();
parse_text_to_lines: {
if (text.len == 0) break :parse_text_to_lines;
var line_num: usize = 0;
var line: *Line = self.first;
var start_line: usize = 0;
var data_pos: usize = 0;
if (text[0] == '\n') { // add blank line
try line.text.set("");
start_line = 1;
const new_line = try prog.buffer.create();
line.pushNext(new_line);
line = new_line;
line_num += 1;
}
while (true) { // find other '\n'
if (data_pos >= text.len or text[data_pos] == '\n') add_line: {
const end_line: usize = data_pos;
if (end_line < start_line) break :add_line;
line.text.set(text[start_line..end_line]) catch {
return error.LineIsToLong;
};
start_line = end_line + 1;
const new_line = try prog.buffer.create();
line.pushNext(new_line);
line = new_line;
line_num += 1;
}
data_pos += 1;
if (start_line >= text.len) break;
} // end while
}
self.line = self.first;
self.bakup_line = try prog.buffer.create();
} // end fn loadLines
pub fn save                 (self: *View) !void {
prog.need_redraw = false;
{ // change status
prog.console.cursorMove(.{ .x = 0, .y = 0 });
lib.print(ansi.reset);
lib.print(ansi.color.blue2);
prog.console.print("saving...");
prog.console.fillSpacesToEndLine();
lib.print(ansi.reset);
}
const file_name = @ptrCast([*:0]const u8,  &self.file_name);
var file = File.fromOpen(file_name, .toWrite) catch unreachable;
defer file.close() catch unreachable;
//{ write
var line: *Line = self.first;
var count: usize = 0;
writing: while (true) {
const text = line.text.get();
try file.write(text);
count += 1;
if (line.child) |child| {
try file.write("\n");
line = child;
} 
else if (line.next) |next| {
try file.write("\n");
line = next;
} 
else { // get parent with next
while (true) {
line = line.getParent() orelse break :writing;
line = line.next orelse continue;
try file.write("\n");
break;
} // end while
} // end else
} // end while
//}
{ // change status
prog.console.cursorMove(.{ .x = 0, .y = 0 });
var buffer: [254]u8 = undefined;
const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "file saved. %d lines writed.", count));
lib.print(ansi.reset);
lib.print(ansi.color.blue2);
prog.console.print(buffer[0..buffer_count]);
prog.console.fillSpacesToEndLine();
prog.console.cursorMoveToEnd();
}
}
pub fn setFileName          (self: *View, name: [:0]const u8) void {
std.mem.copy(u8, self.file_name[0..], name);
}
pub fn changeMode           (self: *View, mode: Mode) void {
switch (mode) {
.edit    => {
if (self.last_line) |last| {
self.line = last;
} else {
self.line = self.first;
}
},
.to_find => {
self.last_line = self.line;
},
.to_line => {
self.last_line = self.line;
if (prog.buffer.to_goto == null) { // create
const new_line = prog.buffer.create() catch return;
prog.buffer.to_goto = new_line;
}
self.line = prog.buffer.to_goto.?;
self.goToEndOfLine();
},
.history => {},
.select  => {},
.normal  => {},
}
self.mode = mode;
}
pub fn cursorMoveToCurrent  (self: *View) void {
prog.console.cursorMove(.{ .x = self.offset.x, .y = self.offset.y });
}
pub fn getLineNum           (self: *View) usize {
return (@ptrToInt(self.line) - @ptrToInt(&prog.buffer.lines)) / @sizeOf(Line);
}
// { mark
pub fn markThisLine         (self: *View) void {
self.marked_line = self.line;
}
pub fn goToMarked           (self: *View) void {
if (self.marked_line) |mark| {
self.line = mark;
}
}
// }
// { edit
pub fn insertSymbol      (self: *View, rune: u8) !void {
try self.line.text.insert(self.symbol, rune);
self.goToNextSymbol();
prog.need_redraw  = true;
} // end fn
pub fn deleteSymbol      (self: *View) void {
if (self.line.text.used == 0) return;
self.line.text.delete(self.symbol) catch return;
prog.need_redraw  = true;
}
pub fn deletePrevSymbol  (self: *View) void {
if (self.symbol == 0) {
if (self.first == self.line) return;
if (self.line.parent) |_| return;
if (self.line.child) |_| self.unFold();
var next = self.line;
if (next.prev) |prev| {
const next_used = next.text.used;
const prev_used = prev.text.used;
if (prev_used + next_used > 252) return;
if (prev_used != 0) { // move cursor
self.goToPrevLine();
self.goToEndOfLine();
self.goToNextLine();
}
std.mem.copy(u8, prev.text.buffer[prev.text.used..], next.text.get());
prev.text.used += next_used;
self.deleteLine();
if (self.line.next) |_| self.goToPrevLine();
self.goToSymbol(prev_used);
}
prog.need_clear  = true;
}
else {
if (self.line.text.used == 0) return;
self.goToPrevSymbol();
self.deleteSymbol();
}
prog.need_redraw  = true;
}
pub fn clearLine         (self: *View) void {
self.line.text.used = 0;
self.goToStartOfLine();
prog.need_redraw  = true;
}
pub fn addPrevLine       (self: *View) !void {
const new_line = try prog.buffer.create();
self.line.pushPrev(new_line);
if (self.first == self.line) self.first = new_line;
self.goToPrevLine();
self.goToStartOfLine();
prog.need_redraw  = true;
}
pub fn addNextLine       (self: *View) !void {
const new_line = try prog.buffer.create();
self.line.pushNext(new_line);
self.goToNextLine();
self.goToStartOfLine();
prog.need_redraw  = true;
}
pub fn divide            (self: *View) !void {
if (self.symbol == 0) {
try self.addPrevLine();
self.goToNextLine();
self.goToStartOfLine();
} 
else if (self.symbol >= self.line.text.used) {
var indent = self.line.text.countIndent(1);
if (self.line.child == null) {
if (self.line.text.buffer[self.symbol - 1] == ':') {indent += 2;}
}
try self.addNextLine();
self.goToStartOfLine();
while (indent > 0) {
try self.line.text.add(' ');
self.goToNextSymbol();
indent -= 1;
}
prog.need_redraw  = true;
} 
else if (self.line.text.buffer[self.symbol] == '}' and self.line.text.buffer[self.symbol - 1] == '{') {
if (self.line.child) |_| return;
const new_line = prog.buffer.create() catch return;
self.line.child = new_line;
new_line.parent = self.line;
new_line.text.set(self.line.text.get()[self.symbol..]) catch unreachable;
self.line.text.used = self.symbol;
self.line = new_line;
try self.addPrevLine();
prog.need_clear  = true;
}
else { 
if (self.line.child) |_| return;
var   parent = self.line;
var   pos    = self.symbol;
var   indent = self.line.text.countIndent(1);
const text   = self.line.text.get()[pos..];
try self.addNextLine();
self.line.text.used = indent + text.len;
std.mem.copy(u8, self.line.text.buffer[indent..], text);
if (indent > 0) { // add indent
while (true) { // add indent
self.line.text.buffer[indent - 1] = ' ';
indent -= 1;
if (indent == 0) break;
}
} 
self.goToStartOfText();
parent.text.used = pos;
}
prog.need_redraw  = true;
}
pub fn swapWithBottom    (self: *View) void {
if (self.line.next) |_| {
self.cut();
self.goToNextLine();
self.pasteLine();
}
prog.need_redraw  = true;
}
pub fn swapWithUpper     (self: *View) void {
if (self.line.prev) |_| {
self.cut();
self.goToPrevLine();
self.pasteLine();
}
prog.need_redraw  = true;
}
pub fn deleteLine        (self: *View) void {
var next_selected_line: *Line = undefined;
if (self.line.next) |next| {
next_selected_line = next;
} else if (self.line.prev) |prev| {
next_selected_line = prev;
} else if (self.line.parent) |parent| {
next_selected_line = parent;
} else {
self.line.text.set("") catch unreachable;
return;
}
self.clearLine();
if (self.first == self.line) self.first = next_selected_line;
prog.buffer.delete(self.line);
self.line = next_selected_line;
prog.need_redraw  = true;
}
pub fn deleteIndent      (self: *View) void {
const text = self.line.text.get();
const indent = self.line.text.countIndent(1);
var new_indent: usize = 0;
if (self.line.getParent()) |parent| new_indent = parent.text.countIndent(1);
var buffer = self.line.text.buffer[0..];
if (new_indent == indent) {return;} 
else if (new_indent > indent) {
std.mem.copyBackwards(u8, buffer[new_indent..], buffer[indent..]);
self.line.text.used = text.len + (indent - new_indent);
for (buffer[0..new_indent]) |*rune| rune.* = ' ';
} 
else { // new_indent < indent
std.mem.copy(u8, buffer[new_indent..], buffer[indent..]);
self.line.text.used = text.len - (indent - new_indent);
}
self.goToStartOfText();
prog.need_redraw  = true;
}
//}
// { draw
pub fn draw             (self: *View) void {
if (self.symbol < self.offset.x) { // unexpected
self.offset.x = 0;
self.symbol = 0;
}
lib.print(ansi.reset);
lib.print(ansi.cyrsor_style.hide); defer {lib.print(ansi.cyrsor_style.show);}
if (self.line.child) |_| self.drawEditedFoldedLine(self.offset.y) else self.drawEditedLine(self.offset.y);
self.drawUpperLines();
self.drawDownerLines();
} // end draw lines
pub fn drawUpperLines   (self: *View) void {
if (self.offset.y == 0) return;
var pos_y: usize = self.offset.y - 1;
var last_line: *Line = self.line;
//{ draw lines
var current: ?*Line = self.line.prev;
while (current) |line| {
if (line.child) |_| {
lib.print(ansi.reset);
lib.print(ansi.bg_color.black2);
self.drawLine(line, pos_y);
} else {
lib.print(ansi.reset);
self.drawLine(line, pos_y);
}
if (pos_y == 0) return;
pos_y -= 1;
current = line.prev;
last_line = line;
}
//}
//{ draw parents
while (last_line.getParent()) |parent| {
lib.print(ansi.reset);
lib.print(ansi.color.blue);
self.drawLine(parent, pos_y);
if (pos_y == 0) break;
pos_y -= 1;
last_line = parent;
}
//}
}
pub fn drawDownerLines  (self: *View) void {
lib.print(ansi.reset);
var line = self.line;
var pos_y = self.offset.y;
while (true) {
if (pos_y < prog.console.size.y - 1) {
if (line.next) |next| {
pos_y += 1;
line = next;
if (line.child) |_| {
lib.print(ansi.reset);
lib.print(ansi.bg_color.black2);
self.drawLine(line, pos_y);
} else {
lib.print(ansi.reset);
self.drawLine(line, pos_y);
}
continue;
}
}
break;
}
}
pub fn drawLine         (self: *View, line: *Line, offset_y: usize) void {
// draw left-to-right from first visible rune
const text = line.text.get();
prog.console.cursorMove(.{ .x = 0, .y = offset_y });
if (self.symbol < self.offset.x) { // unexpected
self.offset.x = 0;
self.symbol = 0;
prog.need_redraw = true;
return;
}
var pos: usize = self.symbol - self.offset.x; // first visible rune
var offset_x: usize = 0;
while (offset_x < prog.console.size.x) {
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
}
}
pub fn drawEditedLine   (self: *View, offset_y: usize) void {
// draw left-to-right from first visible rune
const text = self.line.text.get();
const text_color = ansi.color.green2;
prog.console.cursorMove(.{ .x = 0, .y = offset_y });
var pos: usize = self.symbol - self.offset.x;
var offset_x: usize = 0;
if (pos > 0) { // draw '<'
lib.print(ansi.reset);
lib.print(ansi.color.magenta);
prog.console.printRune('<');
pos += 1;
offset_x += 1;
}
//{ left symbols
lib.print(ansi.reset);
lib.print(text_color);
while (offset_x < self.offset.x) {
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
}
//}
//{ current symbol. maybe inverse cursour?
lib.print(ansi.reset);
lib.print(ansi.color.yellow);
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
//}
//{ right symbols
lib.print(ansi.reset);
lib.print(text_color);
while (offset_x < prog.console.size.x - 1) {
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
}
//}
if (text.len > pos) { // draw '>'
lib.print(ansi.color.magenta);
prog.console.printRune('>');
} else { // draw ' '
prog.console.printRune(' ');
}
}
pub fn drawEditedFoldedLine(self: *View, offset_y: usize) void {
// draw left-to-right from first visible rune
const text = self.line.text.get();
const text_color = ansi.color.green2;
const bg_color = ansi.bg_color.black2;
prog.console.cursorMove(.{ .x = 0, .y = offset_y });
var pos: usize = self.symbol - self.offset.x;
var offset_x: usize = 0;
if (pos > 0) { // draw '<'
lib.print(ansi.reset);
lib.print(ansi.color.magenta);
prog.console.printRune('<');
pos += 1;
offset_x += 1;
}
//{ left symbols
lib.print(ansi.reset);
lib.print(bg_color);
lib.print(text_color);
while (offset_x < self.offset.x) {
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
}
//}
//{ current symbol. maybe inverse cursour?
lib.print(ansi.reset);
lib.print(ansi.color.yellow);
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
//}
//{ right symbols
lib.print(ansi.reset);
lib.print(bg_color);
lib.print(text_color);
while (offset_x < prog.console.size.x - 1) {
drawSymbol(text, pos);
pos += 1;
offset_x += 1;
}
//}
if (text.len > pos) { // draw '>'
lib.print(ansi.reset);
lib.print(ansi.color.magenta);
prog.console.printRune('>');
} else { // draw ' '
prog.console.printRune(' ');
}
}
pub fn drawSymbol       (text: []const u8, pos: usize) void {
if (pos >= text.len) prog.console.printRune(' ') else prog.console.printRune(text[pos]);
}
//}
// { navigation
pub fn goToLine         (self: *View) void {
var num = lib.u64FromCharsDec(self.line.text.get()) catch return;
num += prog.buffer.lineToPos(self.first) - 1;
if (num >= prog.buffer.lineToPos(self.line)) return;
self.last_line = &prog.buffer.lines[num];
self.changeMode(.edit);
self.offset.y = 6;
self.symbol = self.line.text.countIndent(1);
prog.need_clear  = true;
prog.need_redraw = true;
self.bakup();
}
pub fn goToPrevLine     (self: *View) void {
if (self.line.prev) |prev| {self.line = prev;} 
else {return;}
// correct offset_y:
if (self.offset.y > 1) self.offset.y -= 1;
var count_to_upperest_line: usize = 0;
var line: *Line = self.line;
while (count_to_upperest_line < 5) {
if (line.prev) |prev| {
count_to_upperest_line += 1;
line = prev;
} 
else {break;}
}
if (self.offset.y < count_to_upperest_line + 1) {
self.offset.y = count_to_upperest_line + 1;
prog.need_clear  = true;
}
prog.need_redraw = true;
self.bakup();
} // end fn
pub fn goToNextLine     (self: *View) void {
if (self.line.next) |next| {
self.line = next;
} else {
return;
}
// correct offset_y:
if (self.offset.y < prog.console.size.y - 1) self.offset.y += 1;
var count_to_downest_line: usize = 0;
var line: *Line = self.line;
while (count_to_downest_line < 5) {
if (line.next) |next| {
count_to_downest_line += 1;
line = next;
} 
else {break;}
}
if (prog.console.size.y - self.offset.y < count_to_downest_line) {
self.offset.y = prog.console.size.y - count_to_downest_line;
prog.need_clear  = true;
}
prog.need_redraw = true;
self.bakup();
} // end fn
pub fn goToPrevSymbol   (self: *View) void {
const used = self.line.text.used;
if (self.symbol == 0) {
if (self.line.prev) |_| {
self.goToPrevLine();
self.goToEndOfLine();
}
return;
}
if (self.symbol > used) {
self.symbol = used;
if (used < prog.console.size.x - 1) self.offset.x = self.line.text.used;
prog.need_redraw  = true;
return;
}
if (self.symbol > 0) self.symbol -= 1;
if (self.symbol >= 10) {if (self.offset.x > 10) {self.offset.x -= 1;}} 
else {if (self.offset.x > 0) self.offset.x -= 1;}
prog.need_redraw  = true;
}
pub fn goToNextSymbol   (self: *View) void {
const used = self.line.text.used;
if (self.symbol >= used) {
if (self.line.next) |_| {
self.goToNextLine();
self.goToStartOfLine();
}
return;
}
if (self.symbol < Line.Text.size - 1) self.symbol += 1;
if (used - self.symbol >= 10) {
if (self.offset.x < prog.console.size.x - 12) self.offset.x += 1;
} else {
if (self.offset.x < prog.console.size.x - 2) self.offset.x += 1;
}
prog.need_redraw  = true;
}
pub fn goToStartOfLine  (self: *View) void {
self.symbol = 0;
self.offset.x = 0;
prog.need_redraw  = true;
}
pub fn goToEndOfLine    (self: *View) void {
self.symbol = self.line.text.used;
if (self.symbol > prog.console.size.x - 2) {self.offset.x = prog.console.size.x - 2;}
else {self.offset.x = self.symbol;}
prog.need_redraw  = true;
}
pub fn goToSymbol       (self: *View, pos: usize) void {
self.symbol = pos;
if (self.symbol > prog.console.size.x - 2) {
self.offset.x = prog.console.size.x - 2;
} 
else {self.offset.x = self.symbol;}
}
pub fn goToRoot         (self: *View) void {
self.line = self.first;
self.offset.y = 1;
self.goToStartOfLine();
prog.need_clear  = true;
prog.need_redraw = true;
self.bakup();
}
pub fn goToFirstLine    (self: *View) void {
while (self.line.prev) |_| self.goToPrevLine();
self.goToStartOfLine();
prog.need_clear  = true;
prog.need_redraw = true;
self.bakup();
}
pub fn goToLastLine     (self: *View) void {
while (self.line.next) |_| self.goToNextLine();
self.goToEndOfLine();
prog.need_clear  = true;
prog.need_redraw = true;
self.bakup();
}
pub fn findNext         (self: *View) void {
const text = self.line.text.get();
var line   = self.line;
if (line.text.find(text, self.symbol)) |pos|   { // goto pos and return
self.line = line;
self.goToSymbol(pos);
return;
}
else { // iterate and find
while(true) {
// iterate
if (line.child) |child| { // goto child
line = child;
} 
else if (line.next)  |next|  { // goto next
line = next;
}
else { // find parent with next
var next: *Line = undefined;
while (true) {
line = line.getParent() orelse return;
next = line.next        orelse continue;
break;
}
line = next;
}
// find
if (line.text.find(text, 0)) |pos| { // goto pos and return
self.line = line;
self.goToSymbol(pos);
return;
}
}
}
self.changeMode(.edit);
prog.need_clear  = true;
prog.need_redraw = true;
self.bakup();
}
pub fn goToStartOfWord  (self: *View) void {
if (self.symbol == 0) {return;}
if (self.symbol > self.line.text.used) {self.goToSymbol(self.line.text.used);}
const first_rune = self.line.text.buffer[self.symbol];
if (first_rune == ' ') {
self.goToPrevSymbol();
while (true) {
if (self.symbol == 0) {break;}
const rune = self.line.text.buffer[self.symbol];
if (rune != ' ') break;
self.goToPrevSymbol();
}
}
else {
self.goToPrevSymbol();
while(true) {
if (self.symbol == 0) {break;}
const next_symbol = self.line.text.buffer[self.symbol - 1];
switch(next_symbol){
' ', '	', '\\', 
'+', '-', '/', '*', '^',
'(', ')', 
'[', ']', 
'{', '}', 
'"', '\'',
'.'  => {break;},
else => {},
}
self.goToPrevSymbol();
}
}
prog.need_redraw = true;
}
pub fn goToEndOfWord    (self: *View) void {
if (self.symbol >= self.line.text.used) {return;}
const first_rune = self.line.text.buffer[self.symbol];
if (first_rune == ' ') {
while(true) {
self.goToNextSymbol();
if (self.symbol >= self.line.text.used) {break;}
const rune = self.line.text.buffer[self.symbol];
if (rune != ' ') break;
}
}
else while(true) {
self.goToNextSymbol();
if (self.symbol >= self.line.text.used) {break;}
const rune = self.line.text.buffer[self.symbol];
switch(rune){
' ', '	', '\\', 
'+', '-', '/', '*', '^',
'(', ')', 
'[', ']', 
'{', '}', 
'"', '\'',
'.'  => {break;},
else => {},
}
}
prog.need_redraw = true;
}
pub fn goToStartOfText  (self: *View) void {
const indent = self.line.text.countIndent(1);
self.goToSymbol(indent);
}
//}
// { folding
pub fn unFold            (self: *View) void {
var current = self.first;
while (true) {
if (current.child) |child| {
current.child = null;
child.parent = null;
//{ insert range child..last into current and current.next
if (current.next) |current_next| { // tie last_child <-> current_next
var last_child: *Line = child;
while (true) { // find last_child
if (last_child.next) |next| {
last_child = next;
} else break;
} // end while
last_child.next = current_next;
current_next.prev = last_child;
} // end if
//{ tie child <-> current
child.prev = current;
current.next = child;
//}
//} end insert into last and current.next
} // end if current_line.child
if (current.next)  |next| {
current = next;
continue;
}
break;
} // end while
prog.need_redraw = true;
prog.need_clear  = true;
} // end fn
pub fn foldFromBrackets  (self: *View) void {
self.unFold();
var current: ?*Line = self.first;
while (current) |line| {
var close_count = line.text.getRunesCount('}'); // **{
var open_count = line.text.getRunesCount('{'); // **}
if (open_count == close_count) {
current = line.next;
} else if (open_count > close_count) {
if (line.next) |next| {
next.parent = line;
line.child = next;
line.next = null;
next.prev = null;
}
current = line.child;
} else { // for close_count > open_count
if (line.getParent()) |parent| {
if (line.next) |next| {
next.prev = parent;
}
parent.next = line.next;
current = line.next;
line.next = null;
} else { // unexpected
current = line.next;
continue;
}
}
}
prog.need_redraw = true;
prog.need_clear  = true;
}
pub fn foldFromIndent    (self: *View, tabsize: usize) void {
self.unFold();
var last_indent = self.first.text.countIndent(tabsize);
var line: *Line = self.first.next orelse return;
while (true) {
const prev = line.prev orelse unreachable;
if (line.text.used == 0) {} // skip blank lines
else { // change to child or parent
const indent = line.text.countIndent(tabsize);
if (indent != last_indent) {
if (indent > last_indent) {
prev.child = line;
prev.next = null;
line.parent = line.prev;
line.prev = null;
} else if (indent < last_indent) {
var parent = line.getParent() orelse unreachable;
var line_parent = parent;
while (true) {
var parent_indent = parent.text.countIndent(tabsize);
if (parent_indent == indent) {
prev.next = null;
parent.next = line;
line.prev = parent;
break;
} else if (parent_indent > indent) {
parent = parent.getParent() orelse unreachable;
continue;
} else if (parent_indent < indent) {
if (parent == line_parent) break;
var last = parent.getLastChild() orelse unreachable;
prev.next = null;
last.next = line;
line.prev = last;
}
}
}
last_indent = indent;
}
}
line = line.next orelse break;
}
prog.need_redraw = true;
prog.need_clear  = true;
}
pub fn goToIn           (self: *View) void {
const line_indent = self.line.text.countIndent(1);
const child = self.line.child orelse return;
const child_indent = child.text.countIndent(1);
if (line_indent < child_indent) {self.offset.x = child_indent - line_indent;} 
else self.offset.x = 1;
self.symbol = child_indent;
self.line = child;
self.offset.y = 6;
prog.need_redraw = true;
prog.need_clear  = true;
}
pub fn goToOut          (self: *View) void {
if (self.line.getParent()) |parent| {
self.symbol = parent.text.countIndent(1);
self.line = parent;
self.offset.y = 6;
if (parent.getParent()) |grand_parent| {
const parent_indent = parent.text.countIndent(1);
const grand_parent_indent = grand_parent.text.countIndent(1);
if (grand_parent_indent <= parent_indent) {
self.offset.x = parent_indent - grand_parent_indent;
} 
else self.offset.x = self.symbol;
} 
else self.offset.x = self.symbol;
} 
else self.goToRoot();
prog.need_redraw = true;
prog.need_clear  = true;
}
//}
// { clipboard
pub fn duplicate      (self: *View) void {
const first      = self.line; 
const copy_first = prog.buffer.create() catch return;
copy_first.text.set(first.text.get()) catch unreachable;
self.line.pushNext(copy_first);
if (first.child) |first_child| {
var current         = first_child;
var copy_current    = prog.buffer.create() catch return;
copy_current.text.set(current.text.get()) catch unreachable;
copy_current.parent = copy_first;
copy_first.child    = copy_current;
copying: while (true) {
if (current.child) |child| {
var copy_child = prog.buffer.create() catch return;
copy_child.text.set(child.text.get()) catch unreachable;
copy_child.parent  = copy_current;
copy_current.child = copy_child;
current       = child;
copy_current  = copy_child;
} 
else if (current.next) |next| {
var copy_next = prog.buffer.create() catch return;
copy_next.text.set(next.text.get()) catch unreachable;
copy_next.prev    = copy_current;
copy_current.next = copy_next;
current       = next;
copy_current  = copy_next;
}
else { // find parent with next
var next: *Line = undefined;
while (true) {
current     = current.getParent()      orelse break :copying;
if (current == first) break: copying;
copy_current = copy_current.getParent() orelse unreachable;
next        = current.next orelse continue;
break;
}
var copy_next     = prog.buffer.create() catch return;
copy_next.text.set(next.text.get()) catch unreachable;
copy_next.prev    = copy_current;
copy_current.next = copy_next;
current           = next;
copy_current      = copy_next;
}
}
}
self.line = copy_first;
prog.need_redraw = true;
}
pub fn cut            (self: *View) void {
if (self.line.parent) |parent| {
parent.child = self.line.next;
}
var next_selected_line: *Line = undefined;
// { select next selected line
if (self.line.next) |next| {
next_selected_line = next;
} else if (self.line.prev) |prev| {
next_selected_line = prev;
} else if (self.line.parent) |parent| {
next_selected_line = parent;
} else {
self.line.text.set("") catch unreachable;
return;
}
// }
if (self.first == self.line) self.first = next_selected_line;
prog.buffer.cut(self.line);
self.line = next_selected_line;
prog.need_clear  = true;
prog.need_redraw = true;
}
pub fn pasteLine      (self: *View) void {
if (prog.buffer.cutted) |cutted| {
prog.buffer.cutted = cutted.next;
cutted.next = null;
self.line.pushPrev(cutted);
if (self.first == self.line) self.first = cutted;
self.offset.y += 1;
self.goToPrevLine();
}
prog.need_redraw = true;
}
pub fn externalCopy   (self: *View) !void {
var file = File.fromOpen(prog.path_to_clipboard.getSantieled(), .toWrite) catch return;
defer file.close() catch unreachable;
if (prog.buffer.cutted) |cutted| {
// { working with lines
var current: *Line = cutted;
try file.write(current.text.get());
copying: while (true) {
if (current.child) |child| {
try file.write("\n");
try file.write(child.text.get());
current = child;
} 
else if (current.next) |next| {
try file.write("\n");
try file.write(next.text.get());
current = next;
}
else { // find parent with next
var next: *Line = undefined;
while (true) {
current     = current.getParent()      orelse break :copying;
next        = current.next orelse continue;
break;
}
try file.write("\n");
try file.write(next.text.get());
current = next;
}
}
// }
{ // change status
prog.need_redraw = false;
prog.console.cursorMove(.{ .x = 0, .y = 0 });
lib.print(ansi.reset);
lib.print(ansi.color.blue2);
prog.console.print("cuted text saved to ~/clipboard.tmp");
prog.console.fillSpacesToEndLine();
lib.print(ansi.reset);
}
}
else {
// { working with lines
const first = self.line;
try file.write(first.text.get());
if (first.child) |first_child| {
var current: *Line = first_child;
try file.write("\n");
try file.write(current.text.get());
copying: while (true) {
if (current.child) |child| {
try file.write("\n");
try file.write(child.text.get());
current = child;
} 
else if (current.next) |next| {
try file.write("\n");
try file.write(next.text.get());
current = next;
}
else { // find parent with next
var next: *Line = undefined;
while (true) {
current = current.getParent() orelse break :copying;
if (current == first) break: copying;
next = current.next orelse continue;
break;
}
try file.write("\n");
try file.write(next.text.get());
current = next;
}
}
}
// }
{ // change status
prog.need_redraw = false;
prog.console.cursorMove(.{ .x = 0, .y = 0 });
lib.print(ansi.reset);
lib.print(ansi.color.blue2);
prog.console.print("this block saved to ~/clipboard.tmp");
prog.console.fillSpacesToEndLine();
lib.print(ansi.reset);
}
}
prog.need_redraw = true;
}
pub fn externalPaste  (self: *View) !void {
const line = self.line;
const file_data_allocated = AllocatedFileData.fromName(prog.path_to_clipboard.getSantieled()) catch {
{ // change status
prog.console.cursorMove(.{ .x = 0, .y = 0 });
lib.print(ansi.reset);
lib.print(ansi.color.red2);
prog.console.print("file ~/clipboard.tmp not reedable.");
prog.console.fillSpacesToEndLine();
lib.print(ansi.reset);
}
return;
};
try self.addPrevLine();
const slice = file_data_allocated.slice orelse unreachable;
for (slice) |rune| { // parse lines
switch(rune) {
10, 13 => {try self.addNextLine();},
else   => {try self.insertSymbol(rune);},
}
}
self.line = line;
prog.need_redraw = true;
}
//}
// { bakup
pub fn bakup   (self: *View) void {
self.bakup_line.text.set(self.line.text.get()) catch {};
}
pub fn restore (self: *View) void {
self.line.text.set(self.bakup_line.text.get()) catch {};
prog.need_redraw = true;
}
// }
}; // end view
pub const CommandLine  = struct {
text: [254]u8 = undefined,
used: usize = 0,
};
pub const Debug        = struct {
visible: bool = false,
pub fn draw    (self: *Debug) void {
if (self.visible == false) {return;}
const debug_lines = 7;
var buffer: [254]u8 = undefined;
lib.print(ansi.color.blue2);
var print_offset: usize = prog.console.size.y - debug_lines;
prog.console.cursorMove(.{ .x = 0, .y = print_offset });
{ // line
const as_num         = prog.view.getLineNum();
const sprintf_result = lib.c.sprintf(&buffer, "line = %d", as_num);
const buffer_count   = @intCast(usize, sprintf_result);
prog.console.print(buffer[0..buffer_count]);
prog.console.fillSpacesToEndLine();
}
{ // current line prev
prog.console.cursorMoveToNextLine();
if (prog.view.line.prev) |prev| {
const as_num: usize = (@ptrToInt(prev) - @ptrToInt(&prog.buffer.lines)) / @sizeOf(Line);
const sprintf_result = lib.c.sprintf(&buffer, "line.prev = %d", as_num);
const buffer_count = @intCast(usize, sprintf_result);
prog.console.print(buffer[0..buffer_count]);
} 
else {
prog.console.print("line.prev = null");
}
prog.console.fillSpacesToEndLine();
}
{ // current line next
prog.console.cursorMoveToNextLine();
if (prog.view.line.next) |next| {
const as_num: usize = (@ptrToInt(next) - @ptrToInt(&prog.buffer.lines)) / @sizeOf(Line);
const sprintf_result = lib.c.sprintf(&buffer, "line.next = %d", as_num);
const buffer_count = @intCast(usize, sprintf_result);
prog.console.print(buffer[0..buffer_count]);
} 
else {
prog.console.print("line.next = null");
}
prog.console.fillSpacesToEndLine();
}
{ // view.offset
prog.console.cursorMoveToNextLine();
const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "view.offset .x = %d, .y = %d", prog.view.offset.x, prog.view.offset.y));
prog.console.print(buffer[0..buffer_count]);
prog.console.fillSpacesToEndLine();
}
{ // line.used
prog.console.cursorMoveToNextLine();
const used = prog.view.line.text.used;
const sprintf_result = lib.c.sprintf(&buffer, "line.len = %d", used);
const buffer_count = @intCast(usize, sprintf_result);
prog.console.print(buffer[0..buffer_count]);
prog.console.fillSpacesToEndLine();
}
{ // symbol
prog.console.cursorMoveToNextLine();
const used = prog.view.line.text.used;
var sprintf_result: c_int = 0;
if (prog.view.symbol >= used) {
sprintf_result = lib.c.sprintf(&buffer, "symbol = %d (null)", prog.view.symbol);
} 
else {
sprintf_result = lib.c.sprintf(&buffer, "symbol = %d (%c)", prog.view.symbol, prog.view.line.text.get()[prog.view.symbol]);
}
const buffer_count = @intCast(usize, sprintf_result);
prog.console.print(buffer[0..buffer_count]);
prog.console.fillSpacesToEndLine();
}
{ // input
prog.console.cursorMoveToNextLine();
var buffer_pos: usize = 0;
var pos: usize = 0;
while (pos < 8) {
_ = lib.c.sprintf(&buffer[buffer_pos], "%02X", prog.console.input.debug_buffer[pos]);
buffer_pos += 2;
pos += 1;
}
prog.console.print(buffer[0..buffer_pos]);
prog.console.fillSpacesToEndLine();
}
lib.print(ansi.reset);
}
pub fn toggle  (self: *Debug) void {
self.visible = !self.visible;
prog.need_redraw = true;
}
};
const MainErrors       = error{
BufferNotInit,
ViewNotInit,
Unexpected,
};
// }
// { fields
pub var prog:      Prog         = .{};
working:           bool         = true,
console:           Console      = .{},
buffer:            *Buffer      = undefined,
view:              View         = .{},
debug:             Debug        = .{},
path_to_clipboard: Line.Text    = undefined,
need_clear:        bool         = true,
need_redraw:       bool         = true,
usage_line:        *Line        = undefined,
// }
pub fn main        () MainErrors!void {
const self = &prog;
self.buffer = Buffer.fromInit() catch return error.BufferNotInit;
{ // load usage text
const path = "ScalpiEditor_usage.txt";
const text = @embedFile("ScalpiEditor_usage.txt");
self.view.init(path, text) catch return error.ViewNotInit;
self.usage_line = self.view.first;
}
if (std.os.argv.len > 1) { // work with arguments
var   argument            = try lib.getTextFromArgument();
const parsed_path         = ParsePath.fromText(argument) catch {
lib.print(
\\  file name not parsed. 
\\
\\  Scalpi editor does not open multiple files in one time.
\\  you can use [Ctrl] + [F2] to change tty.
\\  or use tmux, byobu, GNU_Screen, dtach, abduco, mtm, or eny you want terminal multiplexor...
\\  or if you use X or wayland just open multiple terminals and use it...
\\
\\
);
return;
};
var   file_name           = parsed_path.file_name orelse unreachable;
const file_name_santieled = file_name.getSantieled();
var   file_data_allocated = AllocatedFileData.fromName(file_name_santieled) catch {
lib.print( 
\\  File not exist or file blocked by system.
\\  ScalpiEditor does not create files itself.
\\  You can create file with "touch" command:
\\     touch file_name
\\
\\
);
return;
};
defer file_data_allocated.deInit() catch unreachable;
const text                = file_data_allocated.slice orelse unreachable; 
self.view.init(file_name_santieled, text) catch return error.ViewNotInit;
}
self.console.init(); defer {self.console.deInit();}
self.updatePathToClipboard();
self.mainLoop();
self.console.cursorMoveToEnd();
lib.print("\r\n");
} // end fn main
// { methods
pub fn mainLoop       (self: *Prog) void {
while (true) {
self.console.updateSize();
self.updateKeys();
if (self.working == false) return;
if (self.need_clear  == true) {
self.need_clear = false;
prog.console.clear();
}
if (self.need_redraw == true) {
self.need_redraw = false;
self.view.draw();
prog.debug.draw();
self.view.cursorMoveToCurrent();
}
std.time.sleep(std.time.ns_per_ms * 10);
}
}
pub fn stop           (self: *Prog) void {
self.need_redraw = false;
self.working = false;
}
pub fn updateKeys     (self: *Prog) void {
self.console.input.updateUnreaded();
while (self.console.input.grab()) |key| {
self.onKey(key);
}
} // end fn updateKeys
pub fn onKey          (self: *Prog, cik: Console.Input.Key) void {
switch (self.view.mode) {
.edit    => {
switch (cik) {
.sequence  => |sequence| {
switch (sequence) {
.f1               => {self.view.line = self.usage_line; self.need_clear = true; self.need_redraw = true;},
.f1_tty           => {self.view.line = self.usage_line; self.need_clear = true; self.need_redraw = true;},
.f2               => {self.debug.toggle();},
.f2_tty           => {self.debug.toggle();},
.f9               => {self.view.changeMode(.normal);},
.delete           => {self.view.deleteSymbol();},
.end              => {self.view.goToEndOfLine();},
.home             => {self.view.goToStartOfLine();},
.down             => {self.view.goToNextLine();},
.up               => {self.view.goToPrevLine();},
.left             => {self.view.goToPrevSymbol();},
.right            => {self.view.goToNextSymbol();},
.alt_v            => {self.view.externalPaste() catch {};},
.alt_m            => {self.view.markThisLine();},
.alt_M            => {self.view.goToMarked();},
.ctrl_shift_left  => {self.view.goToStartOfLine();},
.ctrl_shift_right => {self.view.goToEndOfLine();},
.ctrl_left        => {self.view.goToStartOfWord();},
.ctrl_right       => {self.view.goToEndOfWord();},
.ctrl_up          => {self.view.goToFirstLine();},
.ctrl_down        => {self.view.goToLastLine();},
.alt_up           => {self.view.swapWithUpper();},
.alt_down         => {self.view.swapWithBottom();},
else              => {self.need_redraw = true;},
}
},
.byte      => |byte| {
self.view.insertSymbol(byte) catch {};
self.need_redraw = true;
},
.ascii_key => |key|  {
switch (key) {
.ctrl_q     => {self.stop();},
.ctrl_s     => {self.view.save() catch {};},
.ctrl_g     => {self.view.changeMode(.to_line);},
.ctrl_f     => {self.view.changeMode(.to_find);},
.ctrl_u     => {self.view.unFold();},
.ctrl_r     => {self.view.foldFromIndent(1);},
.ctrl_e     => {self.view.foldFromBrackets();},
.ctrl_j     => {self.view.divide() catch {};},
.enter      => {
switch (self.console.input.is_paste) {
true   => {self.view.addNextLine() catch {};},
false  => {self.view.divide() catch {};},
}
},
.back_space => {self.view.deletePrevSymbol();},
.ctrl_o     => {self.view.line.text.removeIndent(2) catch {}; self.need_redraw = true;},
.ctrl_p     => {self.view.line.text.addIndent(2) catch {}; self.need_redraw = true;},
.ctrl_d     => {self.view.duplicate();},
.ctrl_x     => {self.view.cut();},
.ctrl_c     => {self.view.externalCopy() catch {};},
.ctrl_v     => {self.view.pasteLine();},
.ctrl_bs    => {self.view.clearLine();},
.ctrl_t     => {self.view.insertSymbol('\t') catch {};},
.escape     => {self.view.goToOut();},
.tab        => {self.view.goToIn();},
.ctrl_y     => {self.debug.toggle();},
.ctrl_z     => {self.view.restore();},
else        => {
var byte = @enumToInt(key);
self.view.insertSymbol(byte) catch {};
self.need_redraw = true;
},
}
},
}
},
.to_find => {
switch (cik) {
.sequence  => |sequence| {
switch (sequence) {
.ctrl_left  => self.view.goToStartOfLine(),
.ctrl_right => self.view.goToEndOfLine(),
.delete     => self.view.deleteSymbol(),
else        => {},
}
},
.byte      => |byte| {
self.view.insertSymbol(byte) catch {};
},
.ascii_key => |key|  {
switch (key) {
.escape     => self.view.changeMode(.edit),
.ctrl_q     => self.stop(),
.back_space => self.view.deletePrevSymbol(),
.ctrl_j     => self.view.findNext(),
.enter      => self.view.findNext(),
.ctrl_bs    => self.view.clearLine(),
else        => {
var byte = @enumToInt(key);
self.view.insertSymbol(byte) catch {};
},
}
},
}
},
.to_line => {
switch (cik) {
.sequence  => |sequence| {
switch (sequence) {
.ctrl_left  => self.view.goToStartOfLine(),
.ctrl_right => self.view.goToEndOfLine(),
.delete     => self.view.deleteSymbol(),
else        => {},
}
},
.byte      => |byte| {
self.view.insertSymbol(byte) catch {};
},
.ascii_key => |key|  {
switch (key) {
.escape     => self.view.changeMode(.edit),
.ctrl_q     => self.stop(),
.back_space => self.view.deletePrevSymbol(),
.ctrl_j     => self.view.goToLine(),
.enter      => self.view.goToLine(),
.ctrl_bs    => self.view.clearLine(),
else        => {
var byte = @enumToInt(key);
self.view.insertSymbol(byte) catch {};
},
}
},
}
},
.history => {},
.select  => {},
.normal  => {
switch (cik) {
.sequence  => |sequence| {
switch (sequence) {
.delete     => self.view.deleteSymbol(),
.end        => self.view.goToEndOfLine(),
.home       => self.view.goToStartOfLine(),
.down       => self.view.goToNextLine(),
.up         => self.view.goToPrevLine(),
.left       => self.view.goToPrevSymbol(),
.right      => self.view.goToNextSymbol(),
else        => {},
}
},
.byte      => |_| {},
.ascii_key => |key|  {
switch (key) {
.code_q     => {self.stop();},
.code_s     => {self.view.save() catch {};},
.code_i     => {self.view.changeMode(.edit);},
.code_g     => {self.view.changeMode(.to_line);},
.code_u     => {self.view.unFold();},
.code_y     => {self.view.foldFromIndent(4);},
.code_r     => {self.view.foldFromIndent(1);},
.code_e     => {self.view.foldFromBrackets();},
.code_j     => {self.view.divide() catch {};},
.enter      => {self.view.divide() catch {};},
.back_space => {self.view.deletePrevSymbol();},
.code_p     => {self.view.deleteIndent();},
.code_d     => {self.view.duplicate();},
.code_x     => {self.view.cut();},
.code_c     => {self.view.externalCopy() catch {};},
.code_v     => {self.view.pasteLine();},
.ctrl_bs    => {self.view.clearLine();},
.code_t     => {self.view.insertSymbol('\t') catch {};},
.escape     => {self.view.goToOut();},
.tab        => {self.view.goToIn();},
.code_l     => {self.view.goToLastLine();},
else        => {},
}
},
}
},
}
}
pub fn updatePathToClipboard  (self: *Prog) void {
var len_c_int = lib.c.sprintf(&self.path_to_clipboard.buffer, "%s/clipboard.tmp", lib.c.getenv("HOME"));
var len = @intCast(usize, len_c_int);
self.path_to_clipboard.used = len;
}
// }
