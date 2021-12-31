// zig fmt: off
//{ defines
    const Prog       = @This();
    const std        = @import("std");
pub const ansi       = @import("ansi.zig");
pub const lib        = @import("lib.zig");
pub const ParsePath  = @import("ParsePath.zig");
pub const Keyboard   = @import("Keyboard.zig");
pub const Screen     = struct {
    pub const Console  = @import("Console.zig");
    console: Console   = .{},
    
    // methods
    pub fn deInit  (self: *Screen) void {
        self.console.deinit();
    }
    pub fn init    (self: *Screen) !void {
        self.console.init(); 
        self.console.cursor.x = 0;
        self.console.cursor.y = 0;
        try self.resize();
    }
    pub fn resize  (self: *Screen) !void {
        self.alloc();
        self.console.cursorToEnd();
    }
    pub fn alloc   (self: *Screen) void { // alloc and clear
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
pub const Buffer     = struct {
    pub const Mode      = enum {
        navigation,
        editLine,
        command,

        pub fn ToText(m: Mode) []const u8 {
            return switch (m) {
                .mainMenu       => "main menu", // logo, minihelp, create, open, close
                .fileNavigation => "file navigation",
                .navigation     => "navigation",
                .edit           => "edit",
                .command        => "command",
            };
        }
    };
    pub const Lines     = struct {
        //{ defines
        pub const Line    = struct {
            text:        [254]u8  = undefined,
            len:         u8       = 0,
            id:          usize    = undefined,
            parent:      ?usize   = null,
            child:       ?usize   = null,
            next:        ?usize   = null,
            prev:        ?usize   = null,
            
            pub fn getText(self: *Line) []u8 {
                return self.text[0 .. self.len];
            }
        };
        pub const max     = 20000; // about 10 mb...
        //}
        //{ fields
        array:   [max]Line  = .{.{}} ** max, // ¯\_(O.o)_/¯
        index:   [max]usize = undefined,
        first:   usize      = 0,
        last_created_line: usize = 0,
        count:   usize      = 0,
        //}
        //{ methods
        pub fn init (self: *Lines) !void {
            { // define "index" and "id" fields
                var pos: usize = 0;
                while (true) {
                    // update index
                    self.index[pos] = pos;
                    // update line.id
                    const line = &self.array[pos];
                    line.id    = pos;
                    // loop iteratio
                    pos += 1;
                    if (pos == max) break;
                }
                
            }
        }
        pub fn get  (self: *Lines, pos: usize) *Line {
            return &self.array[self.index[pos]];
        }
        pub fn add  (self: *Lines, text: []const u8) usize {
            //{ create line
            const id: usize = self.count;
            const added_line = self.get(id);
            added_line.* = .{};
            //}
            //{ set fields
            added_line.len = @intCast(u8, text.len);
            added_line.id  = id;
            //}
            //{ copy text
            for(text) |symbol, pos| {
                added_line.text[pos] = symbol;
            }
            //}
            //{ inc self.count
            self.count += 1;
            //}
            const last_line = self.get(self.last_created_line); 
            self.last_created_line = id;
            last_line.next = id;
            return id;
        } // end fn add
        //}
    };
    
    // fields
    mode:      Mode     = .navigation,
    file_name: [1024]u8 = undefined,
    lines:     Lines    = .{},

    // methods
    pub fn init   (self: *Buffer) !void {
        try self.lines.init();
    }
};
const MainErrors     = error {
    ScreenNotInit,
    BufferNotInit,
    Unexpected,
};
//}
//{ fields
screen:   Screen   = .{},
working:  bool     = true,
keyboard: Keyboard = .{},
buffer:   Buffer   = .{},
//}
//{ methods
pub fn getTextFromArgument  () error{Unexpected} ![]const u8 {
    var argIterator_packed = std.process.ArgIterator.init();
    var argIterator = &argIterator_packed.inner;
    _ = argIterator.skip(); // skip name of programm
    var arg = argIterator.next() orelse return error.Unexpected;
    return arg;
}
pub fn loadLinesToBuffer    (
  self: *Prog, 
  fda:  []u8 // file_data_allocated;
) void {
    const last_symbol_pos: usize = fda.len - 1;
    var   pos: usize = 0;
    var   start_next_line: usize = 0;
    while(true) {
        const symbol = fda[pos];
        if(symbol == '\n') {
            const text = fda[start_next_line .. pos];
            _ = self.buffer.lines.add(text);
            start_next_line = pos + 1;
        }
        if (pos == last_symbol_pos) {
            if (symbol != '\n') {
                const text = fda[start_next_line .. pos];
                _ = self.buffer.lines.add(text);
            }
            break;
        }
        pos += 1;
    }
} // end fn loadLinesToBuffer
pub fn main                 () MainErrors!void {   
    const self = &prog;
    //{ exit if argument not exist. 
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
    //}
    //{ get path from arguments
    var argument = try getTextFromArgument();
    const parsed_path = try ParsePath.init(argument);
    //}
    //{ read file
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
    //}
    //{ init systems
    self.screen.init() catch return error.ScreenNotInit; defer self.screen.deInit();
    //}
    //{ create buffer with this file
    self.buffer.init() catch return error.BufferNotInit;
    std.mem.copy(u8, self.buffer.file_name[0..], parsed_path.file_name);
    self.loadLinesToBuffer(file_data_allocated);
    //}
    { // draw lines
        const console = &self.screen.console;
        console.cursorMove(0, 0);
        //const folder = self.buffer.lines.getCurrentFolder();
        // TODO create iterator for lines
        var pos: usize = 0;
        std.log.info("self.screen.console.size = {}",.{self.screen.console.size});
        var line_id: ?usize = 0;
        while(true) {
            if(pos == self.screen.console.size.y ) {
                console.print("...");
                break;
            }
                if (line_id) |id| {
                pos += 1;
                console.print("line -- ");
                const line = prog.buffer.lines.get(id);
                console.print(line.getText());                
                console.print("\r\n");
                line_id = line.next;
            } else {
                break;
            }
        } // end while
    } // end draw lines
    self.mainLoop();
    std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
}
pub fn mainLoop             (self: *Prog) void {
    while (self.working) {
        // TODO draw buffer 
        self.keyboard.updateKeys();
    }
}
//} end methods
//{ export 
pub var prog: Prog = .{};
//}
//{ TODOs
// * file "map" for speedup
//}
