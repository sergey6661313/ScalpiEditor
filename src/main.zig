// zig fmt: off
//{ defines
        const Prog       = @This();
        const std        = @import("std");
    pub const ansi       = @import("ansi.zig");
    pub const lib        = @import("lib.zig");
    pub const ParsePath  = @import("ParsePath.zig");
    pub const Keyboard   = @import("Keyboard.zig");
    pub const Console    = @import("Console.zig");
    pub const Buffer     = struct {
        //{ defines
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
                    count:   usize      = 0,
                    last_created_line: usize = 0,
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
                            //{ update prev/next
                            if(self.count > 0) {
                                added_line.prev = self.last_created_line;
                                const last_line = self.get(self.last_created_line); 
                                last_line.next = id;
                            }
                            //}
                        //}
                        //{ copy text
                            for(text) |symbol, pos| {
                                added_line.text[pos] = symbol;
                            }
                        //}
                        self.last_created_line = id;
                        self.count += 1;
                        return id;
                    } // end fn add
                //}
            };
        //}
        //{ fields
            mode:      Mode     = .navigation,
            file_name: [1024]u8 = undefined,
            lines:     Lines    = .{},
        //}
        //{ methods
            pub fn init   (self: *Buffer) !void {
                try self.lines.init();
            }
        //}
    };
    const MainErrors     = error {
        ScreenNotInit,
        BufferNotInit,
        Unexpected,
    };
    //{ usage text
    pub const usage_text = 
        \\This is ScalpiEditor - "heirarhy" text editor. (NOT EDITOR YET!)
        \\Navigate in your code on MC-like style
        \\
        \\basic keys:
        \\    Esc      - quit
        \\    ↑        - select upper  line
        \\    ↓        - select bottom line
        \\    Enter    - open selected block
        \\
        \\usage examples:
        \\    ScalpiEditor ~/.bashrc    - open to edit file "~/.bashrc"
        // TODO \\    ScalpiEditor --help       - open documentation
        // TODO \\    ScalpiEditor --settings   - open settings
        \\
        \\
    ;
    //} // end usage text
//} // end defines
//{ fields
    console:  Console  = .{},
    working:  bool     = true,
    keyboard: Keyboard = .{},
    buffer:   Buffer   = .{},
    selected_line_id: usize = 0,
    need_redraw:      bool  = true,
    amount_drawable_upper_lines:  usize = 0,
//} end fields
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
      text:  []const u8,
    ) void {
        const last_symbol_pos: usize = text.len - 1;
        var   pos: usize = 0;
        var   start_next_line: usize = 0;
        while(true) {
            const symbol = text[pos];
            if(symbol == '\n') {
                _ = self.buffer.lines.add(text[start_next_line .. pos]);
                start_next_line = pos + 1;
            }
            if (pos == last_symbol_pos) {
                if (symbol != '\n') {
                    _ = self.buffer.lines.add(text[start_next_line .. pos]);
                }
                break;
            }
            pos += 1;
        }
    } // end fn loadLinesToBuffer
    pub fn main                 () MainErrors!void {   
        const self = &prog;
        lib.print("\n");
        //{ init systems
        self.console.init(); defer self.console.deInit();
        self.buffer.init() catch return error.BufferNotInit;
        lib.print(ansi.control ++ "?25l"); // hide cursor
        defer lib.print(ansi.control ++ "?25h"); // show cursor
        //}
        //{ load text (from argument)
        if (std.os.argv.len == 1) { // load usage text
            std.mem.copy(u8, self.buffer.file_name[0..], "usage");
            self.loadLinesToBuffer(usage_text);
        } else { // load file
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
            //{ create buffer with this file
            std.mem.copy(u8, self.buffer.file_name[0..], parsed_path.file_name);
            self.loadLinesToBuffer(file_data_allocated);
            lib.c.free(file_data_allocated.ptr);
            //}
        }
        //}
        self.mainLoop();
        std.log.info("{s}:{}: Bye!", .{ @src().file, @src().line });
    }
    pub fn mainLoop             (self: *Prog) void {
        while (self.working) {
            self.keyboard.updateKeys();
            if(self.need_redraw) self.draw();
            std.time.sleep(std.time.ns_per_ms * 20);
        }
    }
    pub fn draw                 (self: *Prog) void {
        self.need_redraw = false;
        self.console.clear();
        const current_line = prog.buffer.lines.get(self.selected_line_id);
        { // draw upper lines
            if (self.amount_drawable_upper_lines > 0) {
                var pos:          usize  = self.amount_drawable_upper_lines - 1;
                var prev_line_id: ?usize = current_line.prev;
                while(true) {
                    if (prev_line_id) |id| {
                        const line = self.buffer.lines.get(id);
                        const text = line.getText();
                        self.console.cursorMove(.{.x = 0, .y = pos});
                        self.console.print(text);
                        if (pos == 0) break;
                        pos -= 1;
                        prev_line_id = line.prev;
                    } else {
                        break;
                    }
                } // end while
            } // end if
        }
        { // draw selected lines
            self.console.cursorMove(.{.x = 0, .y = self.amount_drawable_upper_lines});
            self.console.print(Prog.ansi.colors.cyan);
            const text = current_line.getText();
            if (text.len == 0) {
                self.console.print("_");
            } else {
                self.console.print(text);
            }
            self.console.print(Prog.ansi.reset);
            self.console.fillSpaces();
        }
        { // draw botton lines
            //~ self.console.print("...");
            const to_end_screen = self.console.size.y - self.amount_drawable_upper_lines;
            if (to_end_screen > 0) {
                var pos:          usize  = self.amount_drawable_upper_lines + 1; 
                var next_line_id: ?usize = current_line.next;
                while (true) {
                    if (next_line_id) |id| {
                        const line = self.buffer.lines.get(id);
                        const text = line.getText();
                        self.console.cursorMove(.{.x = 0, .y = pos});
                        self.console.print(text);
                        if (pos == self.console.size.y) break;
                        pos += 1;
                        next_line_id = line.next;
                    } else {
                        break;
                    }
                } // end while
            } // end if
        } // end draw botton lines
    } // end draw lines
//} end methods
//{ export 
    pub var prog: Prog = .{};
//} end export
