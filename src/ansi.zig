pub const ansi         = @This();
const Prog             = @import("root");
const lib              = Prog.lib;
pub const Ascii        = enum(u7)  {
// { specials
NUL,
start_of_heading,
star_of_text,
end_of_text,
end_of_transmission,
enquiry,
acknowledge,
bell,
back_space,
tab,
line_feed,
vertical_tab,
formFeed,
carriage_return,
shift_out,
shift_in,
data_link_escape,
device_control_1,
device_control_2,
device_control_3,
device_control_4,
negative_acknowledge,
synchrinius_idle,
end_of_trans_block,
cancel,
end_of_medium,
substitute,
escape,
file_separator,
group_separetor,
record_separator,
unit_separator,
//}
// { signs
space,           // ' '
exclamation,     // '!'
double_cuotes,   // '"'
number_sign,     // '#'
dollar_sign,     // '$'
percent_sign,    // '%'
ampersand,       // '&'
apostrophe,      // '\''
round_bracket_open,
round_bracket_close,
asterisk,        // '*'
plus_sign,       // '+'
comma,           // ','
minus_sign,      // '-'
dot,             // '.'
slash,           // '/'
// }
// { numbers
code_0,
code_1,
code_2,
code_3,
code_4,
code_5,
code_6,
code_7,
code_8,
code_9,
// }
// { signs2
colon,         // ':'
semi_colon,    // ';'
less_sign,     // '<'
equals_sign,   // '='
greater_sign,  // '>'
question_mark, // '?'
at,            // '@'
// }
// { capitals
code_A,
code_B,
code_C,
code_D,
code_E,
code_F,
code_G,
code_H,
code_I,
code_J,
code_K,
code_L,
code_M,
code_N,
code_O,
code_P,
code_Q,
code_R,
code_S,
code_T,
code_U,
code_V,
code_W,
code_X,
code_Y,
code_Z,
//}
// { signs 3 
open_bracket,  // '['
back_slash,    // '\\'
close_bracket, // ']'
caret,         // '^'
under_score,   // '_'
grave_accent,  // '`'
// }
// { non_capitals
code_a,
code_b,
code_c,
code_d,
code_e,
code_f,
code_g,
code_h,
code_i,
code_j,
code_k,
code_l,
code_m,
code_n,
code_o,
code_p,
code_q,
code_r,
code_s,
code_t,
code_u,
code_v,
code_w,
code_x,
code_y,
code_z,
//}
// { signs 4
open_figure_bracket,
vertical_bar,
close_figure_bracket,
tilda,
delete,
// }
};
pub const AsciiKey     = enum(u7)  {
// { specials
NUL,
ctrl_a,  // start_of_heading,
ctrl_b,  // star_of_text,
ctrl_c,  // end_of_text,
ctrl_d,  // end_of_transmission,
ctrl_e,  // enquiry,
ctrl_f,  // acknowledge,
ctrl_g,  // bell,
ctrl_bs, // ctrl backspace,
tab,     // horizontal_tab,
ctrl_j,  // line_feed,
ctrl_k,  // vertical_tab,
ctrl_l,  // formFeed,
enter,   // carriage_return,
ctrl_n,  // shift_out,
ctrl_o,  // shift_in,
ctrl_p,  // data_link_escape,
ctrl_q,  // device_control_1,
ctrl_r,  // device_control_2,
ctrl_s,  // device_control_3,
ctrl_t,  // device_control_4,
ctrl_u,  // negative_acknowledge,
ctrl_v,  // synchrinius_idle,
ctrl_w,  // end_of_trans_block,
ctrl_x,  // cancel,
ctrl_y,  // end_of_medium,
ctrl_z,  // substitute,
escape,
file_separator,
group_separetor,
record_separator,
unit_separator,
//}
// { signs
space,           // ' '
exclamation,     // '!'
double_cuotes,   // '"'
number_sign,     // '#'
dollar_sign,     // '$'
percent_sign,    // '%'
ampersand,       // '&'
apostrophe,      // '\''
round_bracket_open,
round_bracket_close,
asterisk,        // '*'
plus_sign,       // '+'
comma,           // ','
minus_sign,      // '-'
dot,             // '.'
slash,           // '/'
// }
// { numbers
code_0,
code_1,
code_2,
code_3,
code_4,
code_5,
code_6,
code_7,
code_8,
code_9,
// }
// { signs2
colon,         // ':'
semi_colon,    // ';'
less_sign,     // '<'
equals_sign,   // '='
greater_sign,  // '>'
question_mark, // '?'
at,            // '@'
// }
// { capitals
code_A,
code_B,
code_C,
code_D,
code_E,
code_F,
code_G,
code_H,
code_I,
code_J,
code_K,
code_L,
code_M,
code_N,
code_O,
code_P,
code_Q,
code_R,
code_S,
code_T,
code_U,
code_V,
code_W,
code_X,
code_Y,
code_Z,
//}
// { signs 3 
open_bracket,  // '['
back_slash,    // '\\'
close_bracket, // ']'
caret,         // '^'
under_score,   // '_'
grave_accent,  // '`'
// }
// { non_capitals
code_a,
code_b,
code_c,
code_d,
code_e,
code_f,
code_g,
code_h,
code_i,
code_j,
code_k,
code_l,
code_m,
code_n,
code_o,
code_p,
code_q,
code_r,
code_s,
code_t,
code_u,
code_v,
code_w,
code_x,
code_y,
code_z,
//}
// { signs 4
open_figure_bracket,
vertical_bar,
close_figure_bracket,
tilda,
back_space, // delete,
// }
};
pub const Sequence     = enum(u64) {
// { enum
ctrl_alt_v,
ctrl_shift_left,
ctrl_shift_right,
shift_up,
shift_down,
shift_left,
shift_right,
delete,
left,
right,
up,
down,
end,
home,
f1,
alt_v,
alt_m,
alt_M,
ctrl_left,
ctrl_right,
ctrl_up,
ctrl_down,
alt_left,
alt_right,
alt_up,
alt_down,
// }
pub const Parser = struct {
sequence: Sequence = null,
used:     usize     = 0,
pub fn fromDo(buffer: []u8) ?Parser {
if (buffer.len >= 6) {
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x36\x44") == .equal) { // ctrl_shift_left
const parser: Parser = .{.sequence = .ctrl_shift_left, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x36\x43") == .equal) { // ctrl_shift_right
const parser: Parser = .{.sequence = .ctrl_shift_right, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x32\x41") == .equal) { // shift_up 
const parser: Parser = .{.sequence = .shift_up, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x32\x42") == .equal) { // shift_down 
const parser: Parser = .{.sequence = .shift_down, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x32\x44") == .equal) { // shift_left 
const parser: Parser = .{.sequence = .shift_left, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x32\x43") == .equal) { // shift_right
const parser: Parser = .{.sequence = .shift_right, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x35\x44") == .equal) { // ctrl_left
const parser: Parser = .{.sequence = .ctrl_left, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x35\x43") == .equal) { // ctrl_right
const parser: Parser = .{.sequence = .ctrl_right, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x35\x41") == .equal) { // ctrl_up
const parser: Parser = .{.sequence = .ctrl_up, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x35\x42") == .equal) { // ctrl_down
const parser: Parser = .{.sequence = .ctrl_down, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x33\x44") == .equal) { // alt_left
const parser: Parser = .{.sequence = .alt_left, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x33\x43") == .equal) { // alt_right
const parser: Parser = .{.sequence = .alt_right, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x33\x41") == .equal) { // alt_up
const parser: Parser = .{.sequence = .alt_up, .used = 6};
return parser;
}
if (lib.cmp(buffer[0..6], "\x1B\x5B\x31\x3B\x33\x42") == .equal) { // alt_down
const parser: Parser = .{.sequence = .alt_down, .used = 6};
return parser;
}
}
if (buffer.len >= 4) {
if (lib.cmp(buffer[0..4], "\x1B\x5B\x33\x7E") == .equal) { //del
const parser: Parser = .{.sequence = .delete, .used = 4};
return parser;
}
}
if (buffer.len >= 3) {
if (lib.cmp(buffer[0..3], "\x1B\x5B\x44") == .equal) { // left
const parser: Parser = .{.sequence = .left, .used = 3};
return parser;
}
if (lib.cmp(buffer[0..3], "\x1B\x5B\x43") == .equal) { // right
const parser: Parser = .{.sequence = .right, .used = 3};
return parser;
}
if (lib.cmp(buffer[0..3], "\x1B\x5B\x41") == .equal) { // up
const parser: Parser = .{.sequence = .up, .used = 3};
return parser;
}
if (lib.cmp(buffer[0..3], "\x1B\x5B\x42") == .equal) { // down
const parser: Parser = .{.sequence = .down, .used = 3};
return parser;
}
if (lib.cmp(buffer[0..3], "\x1B\x5B\x46") == .equal) { // end
const parser: Parser = .{.sequence = .end, .used = 3};
return parser;
}
if (lib.cmp(buffer[0..3], "\x1B\x5B\x48") == .equal) { // home
const parser: Parser = .{.sequence = .home, .used = 3};
return parser;
}
if (lib.cmp(buffer[0..3], "\x1B\x4F\x50") == .equal) { // f1
const parser: Parser = .{.sequence = .f1, .used = 3};
return parser;
}
}
if (buffer.len >= 2) {
if (lib.cmp(buffer[0..2], "\x1B\x16") == .equal) { // ctrl_alt_v
const parser: Parser = .{.sequence = .ctrl_alt_v, .used = 2};
return parser;
}
if (lib.cmp(buffer[0..2], "\x1B\x76") == .equal) { // alt_v
const parser: Parser = .{.sequence = .alt_v, .used = 2};
return parser;
}
if (lib.cmp(buffer[0..2], "\x1B\x6D") == .equal) { // alt_m
const parser: Parser = .{.sequence = .alt_m, .used = 2};
return parser;
}
if (lib.cmp(buffer[0..2], "\x1B\x4D") == .equal) { // alt_M
const parser: Parser = .{.sequence = .alt_M, .used = 2};
return parser;
}
}
return null;
}
};
};
pub const esc          = "\x1B";
pub const control      = esc ++ "[";
pub const reset        = control ++ "0m";
pub const bold         = control ++ "1m";
pub const dim          = control ++ "2m";
pub const cyrsor_style = struct {
pub const hide               = control ++ "?25l";
pub const show               = control ++ "?25h";
pub const reset              = control ++ "0 q";
pub const blinking_block     = control ++ "1 q";
pub const steady_block       = control ++ "2 q";
pub const blinking_underline = control ++ "3 q";
pub const steady_underline   = control ++ "4 q";
pub const blinking_I_beam    = control ++ "5 q";
pub const steady_I_beam      = control ++ "6 q";
};
pub const color        = struct {
pub const black     = control ++ "30;1m";
pub const red       = control ++ "31;1m";
pub const green     = control ++ "32;1m";
pub const yellow    = control ++ "33;1m";
pub const blue      = control ++ "34;1m";
pub const magenta   = control ++ "35;1m";
pub const cyan      = control ++ "36;1m";
pub const white     = control ++ "37;1m";
pub const zero      = control ++ "39;1m";
pub const black2    = control ++ "90;1m";    
pub const red2      = control ++ "91;1m";
pub const green2    = control ++ "92;1m";
pub const yellow2   = control ++ "93;1m";
pub const blue2     = control ++ "94;1m";
pub const magenta2  = control ++ "95;1m";
pub const cyan2     = control ++ "96;1m";
pub const white2    = control ++ "97;1m";
};
pub const bg_color     = struct {
pub const black     = control ++ "40;1m";
pub const red       = control ++ "41;1m";
pub const green     = control ++ "42;1m";
pub const yellow    = control ++ "43;1m";
pub const blue      = control ++ "44;1m";
pub const magenta   = control ++ "45;1m";
pub const cyan      = control ++ "46;1m";
pub const white     = control ++ "47;1m";
pub const zero      = control ++ "49;1m";
pub const black2    = control ++ "100;1m";
pub const red2      = control ++ "101;1m";
pub const green2    = control ++ "102;1m";
pub const yellow2   = control ++ "103;1m";
pub const blue2     = control ++ "104;1m";
pub const magenta2  = control ++ "105;1m";
pub const cyan2     = control ++ "106;1m";
pub const white2    = control ++ "107;1m";
};
