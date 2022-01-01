// zig fmt: off
pub const ansi = @This();

pub const esc     = "\x1B";
pub const control = esc ++ "[";
pub const reset   = control ++ "0m";
pub const bold    = control ++ "1m";
pub const dim     = control ++ "2m";

pub const colors = struct {
    pub const red    = control ++ "31;1m";
    pub const green  = control ++ "32;1m";
    pub const __c33  = control ++ "33;1m";
    pub const __c34  = control ++ "34;1m";
    pub const __c35  = control ++ "35;1m";
    pub const cyan   = control ++ "36;1m";
    pub const white  = control ++ "37;1m";
    pub const __c38  = control ++ "38;1m";
    pub const __c39  = control ++ "39;1m";
};
// zig fmt: on
