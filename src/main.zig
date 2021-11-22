const std = @import("std");
const Prog = @This();
pub const ansi = @import("ansi.zig");
pub const lib = @import("lib.zig");
pub const c = lib.c; 
pub const printRune = lib.printRune;
pub const print = lib.print;
pub const cmp = lib.cmp;
pub const Coor2u = lib.Coor2u;
pub const Console = @import("Console.zig");


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



console: Console = .{},
status_line: StatusLine = .{},
mode: Mode = .edit,
working: bool = true,

var prog: Prog = undefined;

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

    std.log.info("size is {}", .{size});
    print("\n");
    self.console.cursor.x = 0;
    self.console.cursor.y = 0;

    // screen alloc and clear screen
    {
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

pub const StatusLine = struct {
    pos: usize = 0, // line num. TODO change to buffer size - 2;

    pub fn draw(self: *StatusLine) void {
        prog.console.cursor.move(0, self.pos);
        prog.console.print(prog.mode.ToText());
        prog.console.cursorToEnd();
    }
};

pub fn main() error{
    BufferNotCreated,
    FileNotOpened,
    Unexpected,
}!void {
    std.log.info("{s}:{}: Hello!", .{ @src().file, @src().line });
    const self = &prog;
    self.console.init();
    defer self.console.deInit();
    self.status_line.pos = self.console.size.y - 2;
    self.createBufferScreen(null) catch return error.BufferNotCreated;
    self.console.cursorToEnd();
    self.status_line.draw();
    if (std.os.argv.len == 1) {
        self.mode = .mainMenu;
        self.status_line.draw();
    } else { // end if (std.os.argv.len == 1)
        var argIterator_packed = std.process.ArgIterator.init();
        var argIterator = &argIterator_packed.inner;
        while (argIterator.next()) |arg| {
            // TODO change mode to write

            self.console.print(arg);
            self.console.print("\n");

            // TODO parse ":"
            // TODO try open file
            var cwd = std.fs.cwd();
            var file = cwd.openFile("", .{
                .read  = true,
                .write = false,
                .lock  = .None,
                .lock_nonblocking = false,
                .intended_io_mode = .blocking,
                .allow_ctty = false,
            }) catch return error.FileNotOpened;
            // TODO read file size
            // TODO allock memory for file
            // TODO load full file to buffer.
            // TODO create tab with this file
            file.close();
        }
    } // end else of if (std.os.argv.len == 1)
    self.mainLoop();

    std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
}

pub fn mainLoop(self: *Prog) void {
    while (self.working) {
        self.working = false;
    }
    // TODO if key == q {bufferClose(),
}

pub fn bufferClose() void {
    // TODO save file
}
