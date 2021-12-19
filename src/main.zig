// Dear Andrewrk, please add to ZIG language the ability to write comments on the left side of the line ... 
// TODO 

const Prog = @This();

// defines
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

//fields
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
pub fn init                 (self: *Prog) error{
    ScreenNotInit,
    BufferNotInit,
                            }!void {
    self.screen.init() catch return error.ScreenNotInit;
    self.buffer.init() catch return error.BufferNotInit;
}
pub fn deInit               (self: *Prog) void {
    self.screen.deInit();
}
pub fn main                 () error{
    NotInit,
    Unexpected,
                            } !void {
    const self = &prog;
    if (std.os.argv.len == 1) { // exit if argument not exist
        lib.print( // print mini info
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
    // read file from argument
    var argument = try getTextFromArgument();
    const parsed_path = try ParsePath.init(argument);
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
    self.init() catch return error.NotInit; defer self.deInit();
    _ = &self;
    // std.mem.copy(u8, self.file_name[0..], parsed_path.file_name); // copy file_name self variable;
    // TODO create buffer with this file
    // TODO check - file map exist?
    // const map_buffer =
    // TODO parse this file
    // TODO if parsed_path.line goto line;
    
    self.mainLoop();
    std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
}
pub fn mainLoop             (self: *Prog) void {
    while (self.working) {
        self.keyboard.updateKeys();
    }
}

//export 
pub var prog: Prog = .{};
