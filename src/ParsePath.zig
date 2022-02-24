const ParsePath = @This();
const Prog      = @import("root");
const lib       = Prog.lib;
const Text      = @import("Text.zig");
pub const countSymbol     = lib.countSymbol;
pub const findSymbol      = lib.findSymbol;
pub const u64FromCharsDec = lib.u64FromCharsDec;

file_name: ?Text   = null,
line:      ?usize  = null,
column:    ?usize  = null,

pub fn fromText(text: []const u8) !ParsePath {
const comma_symbol = ':';
const count_comma: usize = countSymbol(text, comma_symbol);
var self: ParsePath = .{};
switch (count_comma) {
0 => {
var text_line = try Text.fromText(text[0..]);
try text_line.add('\x00');
self.file_name = text_line;
},
1 => {
var comma_pos = findSymbol(text, comma_symbol).?;

var text_line = try Text.fromText(text[0..comma_pos]);
try text_line.add('\x00');
self.file_name = text_line;

// parse line
const line_as_text = text[comma_pos + 1..];
self.line = u64FromCharsDec(line_as_text) catch return error.Unexpected;
},
2 => {
var comma_pos_1 = findSymbol(text, comma_symbol).?;
var comma_pos_2 = findSymbol(text[comma_pos_1 + 1 ..], comma_symbol).?;

// parse name
var text_line = try Text.fromText(text[0..comma_pos_1 + 1]);
try text_line.add('\x00');
self.file_name = text_line;

// parse line
const line_as_text = text[comma_pos_1 + 1..];
self.line = u64FromCharsDec(line_as_text) catch return error.Unexpected;

// parse column
const column_as_text = text[comma_pos_2 + 1..];
self.column = u64FromCharsDec(column_as_text) catch return error.Unexpected;
},
else => return error.Unexpected,
}
return self;
}
