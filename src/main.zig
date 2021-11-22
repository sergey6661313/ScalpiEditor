const std = @import("std");
const Prog = @This();
pub const ansi = @import("ansi.zig");
pub const Console = @import("Console.zig");
pub const lib = @import("lib.zig");
pub const c = lib.c; 
pub const printRune = lib.printRune;
pub const print = lib.print;
pub const cmp = lib.cmp;
pub const findSymbol = lib.findSymbol;
pub const Coor2u = lib.Coor2u;
pub const countSymbol = lib.countSymbol;
pub const u64FromCharsDec = lib.u64FromCharsDec;


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
    lib.u64FromCharsDec_tests() catch return error.Unexpected;

    std.log.info("{s}:{}: Hello!", .{ @src().file, @src().line });
    const self = &prog;
    self.console.init();
    defer self.console.deinit();
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
            self.mode = .edit;
            self.console.print(arg);
            self.console.print("\n");
            const parsed_path = try ParsePath.init(arg);
            std.log.info("try file {s} open...",.{parsed_path.file_name});
            var cwd = std.fs.cwd();
            var file = cwd.openFile(parsed_path.file_name, .{
                .read  = true,
                .write = false,
                .lock  = .None,
                .lock_nonblocking = false,
                .intended_io_mode = .blocking,
                .allow_ctty = false,
            }) catch return error.FileNotOpened;
            std.log.info("File {s} opened.",.{parsed_path.file_name});
            // TODO read file size
            // TODO allock memory for file
            // TODO load full file to buffer.
            // TODO create tab with this file
            // TODO parse this file
            // TODO if parsed_path.line goto line;
            file.close();
        }
    } // end else of if (std.os.argv.len == 1)
    self.mainLoop();

    std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
}

pub fn mainLoop(self: *Prog) void {
    while (self.working) {
        // TODO if key == ctrl + w {bufferClose();}
        // TODO if key == ctrl + q {bufferClose(); self.working = false;}
        self.working = false;
    }
}

pub fn bufferClose() void {
    // TODO save file
}


pub const ParsePath = struct {
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
};