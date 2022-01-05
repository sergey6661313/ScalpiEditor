// zig fmt: off
pub const ansi    = @This();
const Prog        = @import("root");
const lib         = Prog.lib;
pub const esc     = "\x1B";
pub const control = esc ++ "[";
pub const reset   = control ++ "0m";
pub const bold    = control ++ "1m";
pub const dim     = control ++ "2m";
pub const cyrsor_style =  struct {
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
pub const colors       = struct {
    pub const red    = control ++ "31;1m";
    pub const green  = control ++ "32;1m";
    pub const yellow = control ++ "33;1m";
    pub const __c34  = control ++ "34;1m";
    pub const __c35  = control ++ "35;1m";
    pub const cyan   = control ++ "36;1m";
    pub const white  = control ++ "37;1m";
    pub const __c38  = control ++ "38;1m";
    pub const __c39  = control ++ "39;1m";
};
pub const key          = struct {
    pub const CtrlA     =  1;
    pub const CtrlB     =  2;
    pub const CtrlC     =  3;
    pub const CtrlD     =  4;
    pub const CtrlE     =  5;
    pub const CtrlF     =  6;
    pub const CtrlG     =  7;
    pub const CtrlH     =  8;
    pub const CtrlI     =  9;
    pub const CtrlJ     = 10; // /n
    pub const CtrlK     = 11;
    pub const CtrlL     = 12;
    pub const CtrlM     = 13; // /r
    pub const CtrlN     = 14;
    pub const CtrlO     = 15;
    pub const CtrlP     = 16;
    pub const CtrlQ     = 17;
    pub const CtrlR     = 18;
    pub const CtrlS     = 19;
    pub const CtrlT     = 20;
    pub const CtrlU     = 21;
    pub const CtrlV     = 22;
    pub const CtrlW     = 23;
    pub const CtrlX     = 24;
    pub const CtrlY     = 25;
    pub const CtrlZ     = 26;

    pub const esc       = 27;
    pub const CtrlSlash = 31;
    pub const up        = 65;
    pub const down      = 66;
    pub const right     = 67;
    pub const left      = 68;
};
pub const MultiKey     = enum {
    Unexpected,
    ArrowUp,
    ArrowDown,
    ArrowLeft,
    ArrowRight,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    Insert,
    Del,
    Home,
    End,
    PgUp,
    PgDown,
    
    pub fn fromBytes(bytes: []u8) MultiKey {
        if (lib.cmp(bytes, control ++ "A"  ) == .equal) return .ArrowUp;
        if (lib.cmp(bytes, control ++ "B"  ) == .equal) return .ArrowDown;
        if (lib.cmp(bytes, control ++ "D"  ) == .equal) return .ArrowLeft;
        if (lib.cmp(bytes, control ++ "C"  ) == .equal) return .ArrowRight;
        if (lib.cmp(bytes, esc     ++ "OP" ) == .equal) return .F1;
        if (lib.cmp(bytes, esc     ++ "OQ" ) == .equal) return .F2;
        if (lib.cmp(bytes, esc     ++ "OR" ) == .equal) return .F3;
        if (lib.cmp(bytes, esc     ++ "OS" ) == .equal) return .F4;
        if (lib.cmp(bytes, control ++ "15~") == .equal) return .F5;
        if (lib.cmp(bytes, control ++ "17~") == .equal) return .F6;
        if (lib.cmp(bytes, control ++ "18~") == .equal) return .F7;
        if (lib.cmp(bytes, control ++ "19~") == .equal) return .F8;
        if (lib.cmp(bytes, control ++ "20~") == .equal) return .F9;
        if (lib.cmp(bytes, control ++ "21~") == .equal) return .F10;
        if (lib.cmp(bytes, control ++ "23~") == .equal) return .F11;
        if (lib.cmp(bytes, control ++ "24~") == .equal) return .F12;
        if (lib.cmp(bytes, control ++ "2~" ) == .equal) return .Insert;
        if (lib.cmp(bytes, control ++ "3~" ) == .equal) return .Del;
        if (lib.cmp(bytes, control ++ "H"  ) == .equal) return .Home;
        if (lib.cmp(bytes, control ++ "F"  ) == .equal) return .End;
        if (lib.cmp(bytes, control ++ "5~" ) == .equal) return .PgUp;
        if (lib.cmp(bytes, control ++ "6~" ) == .equal) return .PgDown;
        return .Unexpected;
    }
};
