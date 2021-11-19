const std = @import("std");
const asBytes = std.mem.asBytes;
const Prog = @This();

const c = @cImport({
    // canonical c
    @cInclude("stdio.h");

    // linux
    @cInclude("arpa/inet.h");
    @cInclude("fcntl.h");
    @cInclude("netinet/in.h");
    @cInclude("netinet/ip.h");
    @cInclude("termios.h");
    @cInclude("sys/ioctl.h");
    @cInclude("sys/socket.h");
    @cInclude("unistd.h");
});

pub fn printRune(rune: u8) void {
    _ = c.fputc(rune, c.stdout);
    _ = c.fflush(c.stdout);
    std.time.sleep(std.time.ns_per_ms * 1);
}

pub fn print(text: []const u8) void {
    for (text) |ch| {
        _ = c.fputc(ch, c.stdout);
        _ = c.fflush(c.stdout);
        std.time.sleep(std.time.ns_per_ms * 1);
    }
}

pub fn cmp(a: []u8, b: []u8) enum { equal, various } {
    if (a.len != a.len) return .various;
    var pos: usize = 0;
    const last = a.len - 1;
    while (true) {
        if (a[pos] != b[pos]) return .various;
        if (pos == last) return .equal;
        pos += 1;
    }
}

// zig fmt: off
pub const ansi = struct {
    pub const esc     = "\x1B";
    pub const control = esc ++ "[";
    pub const reset   = control ++ "0m";
    pub const bold    = control ++ "1m";
    pub const dim     = control ++ "2m";

    pub const Colors = struct {
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
};
// zig fmt: on

pub const Coor2u = struct {
    x: usize,
    y: usize,

    pub fn isNotSmaller(self: *Coor2u, target: *Coor2u) bool {
        if (self.x < target.x) return false;
        if (self.y < target.y) return false;
        return true;
    }

    pub fn isBigger(self: *Coor2u, target: *Coor2u) bool {
        if (self.x > target.x) return true;
        if (self.y > target.y) return true;
        return false;
    }
};

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

pub const Console = struct {
    size: Coor2u = .{ .x = 0, .y = 0 },
    stdin_system_flags: c.struct_termios = undefined,
    stdout_system_flags: c.struct_termios = undefined,
    cursor: Cursor = .{},

    pub fn init(self: *Console) void {

        // save std in/out settings
        const f_stdin = c.fileno(c.stdin);
        const f_stdout = c.fileno(c.stdout);
        _ = c.tcgetattr(f_stdin, &self.stdin_system_flags);
        _ = c.tcgetattr(f_stdout, &self.stdout_system_flags);

        // turn off line buffering
        var flags: c.struct_termios = undefined;
        c.setbuf(c.stdin, null);
        c.setbuf(c.stdout, null);

        _ = c.tcgetattr(f_stdin, &flags);
        flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
        _ = c.tcsetattr(f_stdin, c.TCSANOW, &flags);

        _ = c.tcgetattr(f_stdout, &flags);
        flags.c_lflag &= ~(@as(c_int, 0) -% c.ICANON);
        _ = c.tcsetattr(f_stdout, c.TCSANOW, &flags);

        _ = self.updateSize();
    }

    pub fn deInit(self: *Console) void {
        // restore buffer settings
        const f_stdin = c.fileno(c.stdin);
        _ = c.tcsetattr(f_stdin, c.TCSANOW, &self.stdin_system_flags);

        const f_stdout = c.fileno(c.stdout);
        _ = c.tcsetattr(f_stdout, c.TCSANOW, &self.stdout_system_flags);
    }

    pub fn updateSize(self: *Console) bool {
        var w: c.winsize = undefined;
        _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
        var new_size: Coor2u = .{
            .x = w.ws_col - 1,
            .y = w.ws_row - 1,
        };

        if (cmp(asBytes(&self.size), asBytes(&new_size)) == .various) {
            self.size = new_size;
            return false;
        }
        return true;
    }

    pub fn print(self: *Console, text: []const u8) void {
        for (text) |rune| {
            switch (rune) {
                '\r' => {
                    self.cursor.x = 0;
                },

                '\n' => {
                    self.cursor.x = 0;
                    self.cursor.y += 1;
                },

                else => {
                    self.cursor.x += 1;
                },
            }
            Prog.printRune(rune);
        }
    }

    pub fn cursorToEnd(self: *Console) void {
        self.cursor.move(0, self.size.y);
    }

    pub fn cursorMove(self: *Console, x: usize, y: usize) void {
        self.cursor.move(x, y);
        if (self.cursor.x > self.size.x) unreachable;
        if (self.cursor.y > self.size.y) unreachable;
    }

    pub const Cursor = struct {
        x: usize = 0,
        y: usize = 0,

        pub fn Init(x: usize, y: usize) Cursor {
            return .{
                .x = x,
                .y = y,
            };
        }

        pub fn move(self: *Cursor, x: usize, y: usize) void {
            if (x != self.x) {
                if (x > self.x) {
                    self.shiftRight(x - self.x);
                } else {
                    self.shiftLeft(self.x - x);
                }
            }

            if (y != self.y) {
                if (y > self.y) {
                    self.shiftDown(y - self.y);
                } else {
                    self.shiftUp(self.y - y);
                }
            }
        }

        pub fn shiftLeft(self: *Cursor, pos: usize) void {
            const target = self.x - pos;
            while (self.x > target) {
                Prog.print(ansi.control ++ "1D");
                self.x -= 1;
            }
        }

        pub fn shiftRight(self: *Cursor, pos: usize) void {
            const target = self.x + pos;
            while (self.x < target) {
                Prog.print(ansi.control ++ "1C");
                self.x += 1;
            }
        }

        pub fn shiftUp(self: *Cursor, pos: usize) void {
            const target = self.y - pos;
            while (self.y > target) {
                Prog.print(ansi.control ++ "1A");
                self.y -= 1;
            }
        }

        pub fn shiftDown(self: *Cursor, pos: usize) void {
            const target = self.y + pos;
            while (self.y < target) {
                Prog.print(ansi.control ++ "1B");
                self.y += 1;
            }
        }
    };
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
    Oops,
}!void {
    std.log.info("{s}:{}: Hello!", .{ @src().file, @src().line });
    const self = &prog;
    self.console.init();
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
            self.console.print(arg);
            self.console.print("\n");
            // TODO try open file
        }
        // TODO change mode to write
    } // end else of if (std.os.argv.len == 1)
    self.mainLoop();
    self.console.deInit();
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
