// zig fmt: off
const std  = @import("std");
const Prog = @This();
pub const ansi            = @import("ansi.zig");
pub const Console         = @import("Console.zig");
pub const lib             = @import("lib.zig");
pub const ParsePath       = @import("ParsePath.zig");
pub const StatusLine      = @import("StatusLine.zig");
pub const Keyboard        = @import("Keyboard.zig");
pub const c               = lib.c; 
pub const printRune       = lib.printRune;
pub const print           = lib.print;
pub const cmp             = lib.cmp;
pub const Coor2u          = lib.Coor2u;

console:     Console    = .{},
status_line: StatusLine = .{},
mode:        Mode       = .edit,
working:     bool       = true,
file_name:   [1024]u8   = undefined,
keyboard:    Keyboard   = .{},
// zig fmt: off

pub var prog: Prog = .{};


pub const Mode = enum {
    mainMenu, // logo, minihelp, create, open, close
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

pub fn createBufferScreen(self: *Prog, _size: ?*Coor2u) error{
    SizeIsBiggestFromConsole,
    Oops,
}!void {
    var size: Coor2u = undefined;
    if (_size) |s| {
        if (size.isBigger(&self.console.size)) return error.SizeIsBiggestFromConsole;
        size = s.*;
    } else {
        size = self.console.size;
    }

    self.console.cursor.x = 0;
    self.console.cursor.y = 0;

    // screen alloc and clear screen
    {
        print("\n");
        var pos: usize = 0;
        while (true) {
            self.console.print("\n");
            var spaces: usize = 0;
            while (true) {
                self.console.print(" ");
                if (spaces == size.x - 1) break;
                spaces += 1;
            }
            if (pos == size.y - 1) break;
            pos += 1;
        }
    }
}





pub fn main() error{
    BufferNotCreated,
    FileNotOpened,
    Unexpected,
}!void {
    const self = &prog;
    self.console.init();
    defer self.console.deinit();
    self.status_line.pos = self.console.size.y - 2;
    self.createBufferScreen(null) catch return error.BufferNotCreated;
    self.console.cursorToEnd();
    self.status_line.draw();

    // if arguments not exist
    if (std.os.argv.len == 1) { 
        self.mode = .mainMenu;
        self.status_line.draw();
    
    // if arguments exist
    } else {
        // iterate on arguments:
        var argIterator_packed = std.process.ArgIterator.init();
        var argIterator = &argIterator_packed.inner;
        _ = argIterator.skip();
        while (argIterator.next()) |arg| {

            self.mode = .edit;

            self.console.print(arg);
            self.console.print("\n");

            // parse argument
            const parsed_path = try ParsePath.init(arg);
            
            // open file
            const file_name = parsed_path.file_name; 
            // TODO copy file_name to global variable;
            // DODO use zig api for file, but ONLY after zig release
            const handle: *c.struct__IO_FILE = c.fopen(file_name.ptr, "rb") orelse return error.Unexpected; 
            defer {
                var fcloseResult = c.fclose(handle);
                if(fcloseResult != 0) unreachable; // this is NOT unreachable, but zig not supports error in defer 0_o
            }
            
            // read file size
            _ = c.fseek(handle, 0, c.SEEK_END);
            const size = @intCast(usize, c.ftell(handle));
            const err_value = std.math.maxInt(u32);
            if (size == err_value) return error.Unexpected;

            // allock memory for file
            // DODO rewrite this to zig allocator, but ONLY after zig release
            const memory_ptr = c.malloc(size) orelse return error.Unexpected; 
            const buffer = @ptrCast([*]u8, memory_ptr)[0..size];

            // load full file to buffer.
            _ = c.fseek(handle, 0, c.SEEK_SET);
            const freadResult = c.fread(memory_ptr, 1, size, handle);
            if(freadResult != size) return error.Unexpected;
            self.console.print(buffer);

            // TODO create tab with this file
            // TODO parse this file
            // TODO if parsed_path.line goto line;

        }
    } // end else of if (std.os.argv.len == 1)
    self.mainLoop();

    std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
}

pub fn mainLoop(self: *Prog) void {
    while (self.working) {
        self.keyboard.updateKeys();
    }
}





pub fn bufferClose() void {
    // TODO save file
}


