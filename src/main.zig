// license:
//~ This code can be freely redistributed except for:
//~ 1) letters, numbers, special characters, signs.
//~ 2) Under no circumstances should you mention about spaces!
//~ 3) do not use without lubrication. 

// defines
    const Prog       = @This();
    const std        = @import("std");
pub const ansi       = @import("ansi.zig");
pub const Console    = @import("Console.zig");
pub const lib        = @import("lib.zig");
pub const ParsePath  = @import("ParsePath.zig");
pub const Keyboard   = @import("Keyboard.zig");
pub const Line       = struct {
    bytes: [254]u8 = undefined,
};
pub const Mode       = enum {
    fileNavigation,
    navigation,
    edit,
    command,

    pub fn ToText(m: Mode) []const u8 {
        return switch (m) {
            .mainMenu => "main menu", // logo, minihelp, create, open, close
            .fileNavigation => "file navigation",
            .navigation => "navigation",
            .edit => "edit",
            .command => "command",
        };
    }
};
pub const Screen     = struct {
    console: Console = .{},
    
    // methods
    pub fn deInit(self: *Screen) void {
        self.console.deinit();
    }
    pub fn init(self: *Screen) !void {
        self.console.init(); 
        self.console.cursor.x = 0;
        self.console.cursor.y = 0;
        try self.resize();
    }
    pub fn resize(self: *Screen) !void {
        self.alloc();
        self.console.cursorToEnd();
    }
    pub fn alloc(self: *Screen) void { // alloc and clear
        lib.print("\n");
        { // print \n\n\n\n\n...            
            var pos: usize = 0;
            while (pos != self.console.size.y) { 
                self.console.print("\n");
                var spaces: usize = 0;
                while (true) {
                    self.console.print(" ");
                    if (spaces == self.console.size.x - 1) break;
                    spaces += 1;
                }
                pos += 1;
            }
        }
    } // end fn alloc
};
pub const Lines      = struct {
    // defines
    pub const max = 40000; // about 10 mb...
    
    // fields
    lines: [max]Line = .{.{}} ** max, // ¯\_(O_o)_/¯
    count: usize = 0,
    index: [max]usize = undefined,
    
    // methods
    pub fn init(self: *Lines) !void {
        { // init index
            var pos: usize = 0;
            while (true) {
                self.index[pos] = pos;
                pos += 1;
                if (pos == max) break;
            }
        }
    }
    pub fn get(self: *Lines, pos: usize) *Line {
        return &self.lines[self.index[pos]];
    }
};
pub const Buffer     = struct {
    mode:      Mode     = .edit,
    file_name: [1024]u8 = undefined,
    lines:     Lines    = .{},

    // methods
    pub fn init   (self: *Buffer) !void {
        try self.lines.init();
    }
    pub fn close  () void {
        // TODO save file
    }
};
        
// fields
screen:   Screen   = .{},
working:  bool     = true,
keyboard: Keyboard = .{},
buffer:   Buffer   = .{},

// methods
pub fn getTextFromArgument  () error{Unexpected} ![]const u8 {
    var argIterator_packed = std.process.ArgIterator.init();
    var argIterator = &argIterator_packed.inner;
    _ = argIterator.skip(); // skip name of programm
    var arg = argIterator.next() orelse return error.Unexpected;
    return arg;
}
pub fn main                 () error{
    ScreenNotInit,
    BufferNotInit,
    Unexpected,
                            } !void {
    const self = &prog;
    // exit if argument not exist. // Dear Andrewrk, please add to ZIG language the ability to write comments on the left side of the line ... This is perfectly folded  code (in editor) and viev as one line. and no one reasons to have discription in upper line before same line.
    if (std.os.argv.len == 1) {
        lib.print(
            \\  This is ScalpiEditor file-text editor.
            \\  For edit file run ScalpiEditor with file name as argument
            \\    ScalpiEditor ~/.bashrc
            \\  or use next keys:
            \\    "--help"     for open documentation
            \\    "--settings" for open settings edittor
            \\
        );
        return;
    }
    // parse argument
    var argument = try getTextFromArgument();
    const parsed_path = try ParsePath.init(argument);
    // read file
    const file_data_allocated = lib.loadFile(parsed_path.file_name) catch |loadFile_result| switch (loadFile_result) { 
        error.FileNotExist => { // exit
            lib.print( // print "File not exist"
                \\  File not exist. 
                \\  ScalpiEditor does not create files itself. 
                \\  You can create file with command: 
                \\     touch file_name
                \\
            );
            return;
        },
        error.Unexpected => return error.Unexpected,
    };
    lib.print(file_data_allocated);
    // init systems
    self.screen.init() catch return error.ScreenNotInit; defer self.screen.deInit();
    // create buffer with this file
    self.buffer.init() catch return error.BufferNotInit;
    std.mem.copy(u8, self.buffer.file_name[0..], parsed_path.file_name);
    // TODO check - file map exist?
    
    // const map_buffer =
    // TODO parse this file
    // TODO if parsed_path.line goto line;
    _ = &self;
    
    self.mainLoop();
    std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
}
pub fn mainLoop             (self: *Prog) void {
    while (self.working) {
        // TODO draw buffer 
        self.keyboard.updateKeys();
    }
}

// export 
pub var prog: Prog = .{};
