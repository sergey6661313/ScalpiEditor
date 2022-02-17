const ParsePath = @This();
const Prog = @import("root");
const lib = Prog.lib;
pub const countSymbol     = lib.countSymbol;
pub const findSymbol      = lib.findSymbol;
pub const u64FromCharsDec = lib.u64FromCharsDec;

file_name: []const u8,
line:      ?usize = null,
column:    ?usize = null,

pub fn init(text: []const u8) error{
    Unexpected,
}!ParsePath {
    const comma_symbol = ':';
    const count_comma: usize = countSymbol(text, comma_symbol);
    var self: ParsePath = .{.file_name = undefined};
    switch (count_comma) {
        0 => {
            self.file_name = text[0..];
        },

        1 => {
            var comma_pos = findSymbol(text, comma_symbol).?;

            // parse name
            self.file_name = text[0..comma_pos + 1];

            // parse line
            const line_as_text = text[comma_pos + 1..];
            self.line = u64FromCharsDec(line_as_text) catch return error.Unexpected;
        },

        2 => {
            var comma_pos_1 = findSymbol(text, comma_symbol).?;
            var comma_pos_2 = findSymbol(text[comma_pos_1 + 1 ..], comma_symbol).?;

            // parse name
            self.file_name = text[0..comma_pos_1 + 1];

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