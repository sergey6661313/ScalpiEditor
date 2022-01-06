// zig fmt: off
pub const ansi    = @This();
const Prog        = @import("root");
const lib         = Prog.lib;
pub const esc     = "\x1B";
pub const control = esc ++ "[";
pub const reset   = control ++ "0m";
pub const bold    = control ++ "1m";
pub const dim     = control ++ "2m";
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
    pub const black    = control ++ "30;1m";    
    pub const red      = control ++ "31;1m";
    pub const green    = control ++ "32;1m";
    pub const yellow   = control ++ "33;1m";
    pub const blue     = control ++ "34;1m";
    pub const magenta  = control ++ "35;1m";
    pub const cyan     = control ++ "36;1m";
    pub const white    = control ++ "37;1m";
    
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
    pub const black    = control ++ "40;1m";    
    pub const red      = control ++ "41;1m";
    pub const green    = control ++ "42;1m";
    pub const yellow   = control ++ "43;1m";
    pub const blue     = control ++ "44;1m";
    pub const magenta  = control ++ "45;1m";
    pub const cyan     = control ++ "46;1m";
    pub const white    = control ++ "47;1m";
    
    pub const black2    = control ++ "100;1m";
    pub const red2      = control ++ "101;1m";
    pub const green2    = control ++ "102;1m";
    pub const yellow2   = control ++ "103;1m";
    pub const blue2     = control ++ "104;1m";
    pub const magenta2  = control ++ "105;1m";
    pub const cyan2     = control ++ "106;1m";
    pub const white2    = control ++ "107;1m";
};
pub const key          = enum(u64) {
    Ctrl2           =  0,
    CtrlA           =  1,
    CtrlB           =  2,
    CtrlC           =  3,
    CtrlD           =  4,
    CtrlE           =  5,
    CtrlF           =  6,
    CtrlG           =  7,
    CtrlH           =  8,
    CtrlI           =  9,
    CtrlJ           = 10, // /n
    CtrlK           = 11,
    CtrlL           = 12,
    CtrlM           = 13, // /r
    CtrlN           = 14,
    CtrlO           = 15,
    CtrlP           = 16,
    CtrlQ           = 17,
    CtrlR           = 18,
    CtrlS           = 19,
    CtrlT           = 20,
    CtrlU           = 21,
    CtrlV           = 22,
    CtrlW           = 23,
    CtrlX           = 24,
    CtrlY           = 25,
    CtrlZ           = 26,
    esc             = 27,
    CtrlSlash       = 31,
    BackSpace       = 0x000000000000007f,
    F1              = 0x0000000000504f1b,
    F2              = 0x0000000000514f1b,
    F3              = 0x0000000000524f1b,
    F4              = 0x0000000000534f1b,
    F5              = 0x0000000035315b1b,
    F6              = 0x0000000037315b1b,
    F7              = 0x0000000038315b1b,
    F8              = 0x0000000039315b1b,
    F9              = 0x0000000030325b1b,
    F10             = 0x0000000031325b1b,
    F11             = 0x0000000033325b1b,
    F12             = 0x0000000034325b1b,
    Insert          = 0x000000007e325b1b,
    Del             = 0x000000007e335b1b,
    Home            = 0x0000000000485b1b,
    End             = 0x0000000000465b1b,
    PgUp            = 0x000000007e355b1b,
    PgDown          = 0x000000007e365b1b,
    ArrowUp         = 0x0000000000415b1b,
    ArrowDown       = 0x0000000000425b1b,
    ArrowLeft       = 0x0000000000445b1b,
    ArrowRight      = 0x0000000000435b1b,
};
