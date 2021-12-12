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

const Line = struct {
    bytes:     [254]u8 = undefined,
    next_line: ?usize  = null,
    prev_line: ?usize  = null,
};

const lines_max = 254;

console:     Console          = .{},
status_line: StatusLine       = .{},
mode:        Mode             = .edit,
working:     bool             = true,
file_name:   [1024]u8         = undefined,
keyboard:    Keyboard         = .{},
lines:       [lines_max]Line  = .{.{}}**lines_max, // OwO syntax
lines_count: usize            = 0,
lines_index: [lines_max]usize = undefined,
// zig fmt: on

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

    { // init self.lines_index
        var pos: usize = 0;
        while(true) {
            self.lines_index[pos] = pos;
            pos += 1;
            if (pos == lines_max) break;
        }
    }

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
            // parse argument
            const parsed_path = try ParsePath.init(arg);
            std.mem.copy(u8, self.file_name[0..], parsed_path.file_name); // copy file_name to global variable;

            // load
            const file_buffer = loadFile(parsed_path.file_name) catch |loadFile_result| switch (loadFile_result) {
                error.FileNotExist => {
                    return error.FileNotOpened; // TODO replace this to answer to create file.
                },
                error.Unexpected => return error.Unexpected,
            };
            self.mode = .edit;
            self.console.print(file_buffer);
            // TODO check - file map exist?
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

pub fn loadFile(name: []const u8) error{
    FileNotExist,
    Unexpected,
} ![]u8 {
    // TODO check - file exits?
    // open file DODO use zig api for file, but ONLY after zig release
    const handle: *c.struct__IO_FILE = c.fopen(name.ptr, "rb") orelse return error.FileNotExist; 
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
    const buffer = @ptrCast([*]u8, memory_ptr)[0..size]; // how to normal syntax to create slice?

    // load full file to buffer.
    _ = c.fseek(handle, 0, c.SEEK_SET);
    const freadResult = c.fread(memory_ptr, 1, size, handle);
    if(freadResult != size) return error.Unexpected;

    return buffer;
}
