// zig fmt: off
//{ defines
    const     Prog       = @This();
    const     std        = @import("std");
    pub const ansi       = @import("ansi.zig");
    pub const lib        = @import("lib.zig");
    pub const ParsePath  = @import("ParsePath.zig");
    pub const Line       = @import("Line.zig");
    pub const Console    = @import("Console.zig");
    pub const usage_text = @embedFile("ScalpiEditor_usage.txt");
    pub const Buffer     = struct {
        //{ defines
            pub const size = 25000; // about 10 mb...
        //}
        //{ fields
            lines:  [size]Line   = .{.{}} ** size, // OwO syntax ¯\_(O.o)_/¯
            free:   ?*Line       = undefined,
        //}
        //{ methods
            pub fn init     (self: *Buffer) !void {
                //{ tie all lines to "free" chain 
                    const first = &self.lines[0];
                    const last  = &self.lines[size - 1];

                    // update ends of range
                    first.next  = &self.lines[1];
                    last. prev  = &self.lines[size - 2];

                    { // update others everything in between first and last
                        var pos: usize = 1;
                        while (true) {
                            const current = &self.lines[pos];
                            current.prev  = &self.lines[pos - 1];
                            current.next  = &self.lines[pos + 1];
                            pos += 1;
                            if (pos == size - 1) break;
                        }
                    }
                //}
                self.free = &self.lines[0];
            } // end fn init
            pub fn create   (self: *Buffer) !*Line {
                if (self.free) |free| {
                    self.free = free.next; // update self.free
                    const line = free;
                    try line.init();
                    return line;
                } else {
                    return error.NoFreeSlots;
                }
            }
        //}
    };
    pub const View       = struct {
        //{ defines
            pub const Current = struct {
                line:   *Line = undefined,
                symbol: usize = 0,
            };
            pub const Mode    = enum {
                Line,
                Symbol,
            };
        //}
        //{ fields
            file_name:    [1024]u8    = undefined,
            mode:         Mode        = .Line,
            first:        *Line       = undefined,
            current:      Current     = .{},
            offset:       lib.Coor2u  = .{},
            need_redraw:  bool        = true,
            focus:        bool        = false,
        //}
        //{ methods
            pub fn init                 (self: *View, file_name: []const u8, text: []const u8) !void {
                self.* = .{};
                self.setFileName(file_name);
                self.first = try prog.buffer.create();
                parse_text_to_lines: { // parse_text_to_lines
                    if (text.len == 0) break :parse_text_to_lines;
                    self.current.line = self.first;
                    var pos: usize = 0;
                    while (true) {
                        if (pos == text.len) break;
                        const symbol = text[pos];
                        if (symbol == '\n') {
                            const new_line = try prog.buffer.create();
                            self.current.line.pushNext(new_line);
                            self.current.symbol = 0;
                            self.goToNextLine();
                            pos += 1;
                            continue;
                        }
                        try self.current.line.insert(self.current.symbol, symbol);
                        self.current.symbol += 1;
                        pos += 1;
                    } // end while
                }
                self.current.line = self.first;
                self.current.symbol = 0;
                self.offset.y = 0;
                self.offset.x = 0;
                self.need_redraw = true;
                self.draw();
            } // end fn loadLines
            pub fn draw                 (self: *View) void {
                if(self.need_redraw == false) return;
                self.need_redraw = false;
                self.drawUpperLines();
                self.drawSelectedLine();
                self.drawBottonLines();
                prog.debug();
                self.cursorMoveToCurrent();
            } // end draw lines
            pub fn redraw               (self: *View) void {
                self.need_redraw = true;
                self.draw();
                //~ std.time.sleep(std.time.ns_per_ms * 1);
            }
            pub fn cursorMoveToCurrent  (self: *View) void {
                prog.console.cursorMove(.{.x = self.offset.x, .y = self.offset.y});
            }
            pub fn drawUpperLines       (self: *View) void {
                if (self.offset.y > 0) {
                    var pos:  usize  = self.offset.y - 1;
                    var prev: ?*Line = self.current.line.prev;
                    while(true) {
                        if (prev) |line| {
                            prog.console.cursorMove(.{.x = 0, .y = pos});
                            if (pos == 0) {
                                if (line.prev) |_| {
                                    lib.print(ansi.color.yellow2);
                                    prog.console.print("^^^");
                                    lib.print(ansi.reset);
                                    prog.console.fillSpacesToEndLine();
                                    break;
                                } else {
                                    prog.console.print(line.getText());
                                    prog.console.fillSpacesToEndLine();
                                    prev = line.prev;
                                }
                            } else {
                                prog.console.print(line.getText());
                                prog.console.fillSpacesToEndLine();
                                pos -= 1;
                                prev = line.prev;
                            }
                        } else {
                            break;
                        }
                    } // end while
                } // end if
            }
            pub fn drawSelectedLine     (self: *View) void {
                const text = self.current.line.getText();
                switch(self.mode) {
                    .Line   => {
                        prog.console.cursorMove(.{.x = 0, .y = self.offset.y});
                        lib.print(ansi.color.cyan);
                        prog.console.print(text);
                        lib.print(ansi.reset);
                        prog.console.fillSpacesToEndLine();
                    },
                    .Symbol => {
                        if (self.current.symbol >= text.len) {
                            self.offset.x = text.len;
                            self.current.symbol = self.offset.x;
                        }
                        prog.console.cursorMove(.{.x = 0, .y = self.offset.y});
                        prog.console.fillSpacesToEndLine();
                        if (self.offset.x > self.current.line.used) self.offset.x = self.current.line.used;
                        self.drawLeftSymbols();
                        self.drawCurrentSymbol();
                        self.drawRightSymbols();
                        self.cursorMoveToCurrent();
                    },
                }
            } // end draw selected line
            pub fn drawBottonLines      (self: *View) void {
                const lines_to_end_screen = prog.console.size.y - self.offset.y;
                if (lines_to_end_screen == 0) return;
                var pos:   usize  = self.offset.y + 1; 
                var next:  ?*Line = self.current.line.next;
                while (true) {
                    if (next) |line| {
                        prog.console.cursorMove(.{.x = 0, .y = pos});
                        prog.console.print(line.getText());
                        prog.console.fillSpacesToEndLine();
                        if (pos == prog.console.size.y) break;
                        pos += 1;
                        next = line.next;
                    } else {
                        break;
                    }
                } // end while
            } // end draw botton lines
            pub fn drawLeftSymbols      (self: *View) void {
                if (self.offset.x       == 0) return;
                if (self.current.symbol == 0) return;
                const text  = self.current.line.getText();
                var pos     = self.offset.x - 1;
                var symbol  = self.current.symbol - 1;
                while(true) {
                    prog.console.cursorMove(.{.x = pos, .y = self.offset.y});
                    lib.print(ansi.color.green);
                    prog.console.printRune(text[symbol]);
                    if (symbol == 0) break;
                    if (pos == 0) {
                        lib.print(ansi.color.magenta2);
                        prog.console.printRune('<');
                        lib.print(ansi.reset);
                        break;
                    }
                    pos    -= 1;
                    symbol -= 1;
                } // end while
                lib.print(ansi.reset);
            } // end fn drawLeftSymbols
            pub fn drawCurrentSymbol    (self: *View) void {
                const text  = self.current.line.getText(); 
                prog.console.cursorMove(.{.x = self.offset.x, .y = self.offset.y});
                if (self.current.symbol >= text.len) {
                    lib.print(ansi.bg_color.yellow2);
                    prog.console.printRune(' ');
                    lib.print(ansi.reset);
                } else {
                    lib.print(ansi.color.yellow);
                    prog.console.printRune(text[self.current.symbol]);
                    lib.print(ansi.reset);
                }
            }
            pub fn drawRightSymbols     (self: *View) void {




                const line = self.current.line;
                const text = line.getText();
                if (text.len == 0)  return;
                if (self.offset.x > prog.console.size.x)  unreachable;
                if (self.current.symbol >= text.len - 1)  return;
                if (self.offset.x == prog.console.size.x) return;
                var pos     = self.offset.x       + 1;
                var current = self.current.symbol + 1;
                lib.print(ansi.color.green);
                while(true) {
                    if (current == text.len) break;
                    if (pos == prog.console.size.x - 1) {
                        if (pos < text.len) {
                            prog.console.cursorMove(.{.x = pos, .y = self.offset.y});
                            lib.print(ansi.color.magenta2);
                            prog.console.printRune('>');
                            break;
                        }
                        prog.console.cursorMove(.{.x = pos, .y = self.offset.y});
                        prog.console.printRune(text[current]);
                        break;
                    }
                    prog.console.cursorMove(.{.x = pos, .y = self.offset.y});
                    prog.console.printRune(text[current]);
                    pos     += 1;
                    current += 1;
                } // end while
                lib.print(ansi.reset);
                prog.console.fillSpacesToEndLine();
            } // end fn drawLeftSymbols
            pub fn save                 (self: *View) void {
                { // change status
                    prog.console.cursorMove(.{.x = 0, .y = 0});
                    lib.print(ansi.color.magenta);
                    prog.console.print("saving...");
                    prog.console.fillSpacesToEndLine();
                    lib.print(ansi.reset);
                }
                self.first.unFold();
                //{ create file
                    var file = lib.File {};
                    file.open(self.file_name[0..], .ToWrite) catch unreachable;
                    defer file.close() catch unreachable;
                //}
                //{ write
                    var line:   *Line = self.first;
                    var count:  usize = 0;
                    while(true) {
                        const text = line.getText();
                        file.write(text);
                        count += 1;
                        { // change status
                            prog.console.cursorMove(.{.x = 0, .y = 0});
                            var buffer: [254]u8 = undefined;
                            const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "            %d lines writed.", count));
                            lib.print(ansi.color.magenta);
                            prog.console.print(buffer[0..buffer_count]);
                            lib.print(ansi.reset);
                            prog.console.fillSpacesToEndLine();
                            prog.console.cursorMoveToEnd();
                        }
                        if (line.next) |next|  {
                            file.write("\n");
                            line = next;
                            continue;
                        } 
                        break;
                    } // end while
                //}
                { // change status
                    prog.console.cursorMove(.{.x = 0, .y = 0});
                    var buffer: [254]u8 = undefined;
                    const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "file saved. %d lines writed.", count));
                    lib.print(ansi.color.magenta);
                    prog.console.print(buffer[0..buffer_count]);
                    lib.print(ansi.reset);
                    prog.console.fillSpacesToEndLine();
                    prog.console.cursorMoveToEnd();
                }
            }
            pub fn changeMode           (self: *View, mode: Mode) void {
                self.mode = mode;
                self.redraw();
            }
            pub fn goToPrevLine         (self: *View) void {
                if (self.current.line.prev) |prev| {
                    self.current.line = prev;
                    if (self.offset.y > 0) self.offset.y -= 1;
                    self.redraw();
                } // end if
            } // end fn
            pub fn goToNextLine         (self: *View) void {
                if (self.current.line.next) |next| {
                    self.current.line = next;
                    if (self.offset.y != prog.console.size.y) self.offset.y += 1;
                    self.redraw();
                }
            } // end fn
            pub fn goToPrevSymbol       (self: *View) void {
                // self.current.symbol
                if (self.current.symbol == 0) return;
                self.current.symbol -= 1;

                // self.ofset
                if (self.offset.x > 0) self.offset.x -= 1;
                self.redraw();
            }
            pub fn goToNextSymbol       (self: *View) void {
                // self.current.symbol
                if (self.current.symbol >= Line.size - 1) unreachable;
                if (self.current.symbol >= self.current.line.used) {
                    self.current.symbol =  self.current.line.used;
                    return;
                } else {
                    self.current.symbol += 1;
                }

                // self.offset
                if (self.offset.x != prog.console.size.x-10) self.offset.x += 1;
                self.redraw();
            }
            pub fn insertSymbol         (self: *View, rune: u8) void {
                self.current.line.insert(self.current.symbol, rune) catch return;
                self.goToNextSymbol();
                self.redraw();
            } // end fn
            pub fn popSymbol            (self: *View, pos: usize) void {
                _ = self.current.line.pop(pos) catch return;
                self.redraw();
            } // end fn
            pub fn addPrevLine          (self: *View) !void {
                const new_line = try prog.buffer.create();
                self.current.line.pushPrev(new_line);
                if (self.first == self.current.line) self.first = new_line;
                self.current.line = new_line;
                self.redraw();
            }
            pub fn addNextLine          (self: *View) !void {
                const new_line = try prog.buffer.create();
                self.current.line.pushNext(new_line);
                self.current.line = new_line;
                self.redraw();
            }
            pub fn setFileName          (self: *View, name: []const u8) void {
                std.mem.copy(u8, self.file_name[0..], name);
                self.file_name[name.len] = 0;
            }
        //}
    };
    const MainErrors     = error  {
        BufferNotInit,
        ViewNotInit,
        Unexpected,
    };
//} end defines
//{ fields
    working:       bool      = true,
    console:       Console   = .{},
    buffer:        Buffer    = .{},
    view:          View      = .{},
//} end fields
//{ methods
    pub fn getTextFromArgument  () error{Unexpected} ![]const u8 {
        var argIterator_packed = std.process.ArgIterator.init();
        var argIterator = &argIterator_packed.inner;
        _ = argIterator.skip(); // skip name of programm
        var arg = argIterator.next() orelse return error.Unexpected;
        return arg;
    }
    pub fn main                 () MainErrors!void {
        const self = &prog;
        //~ const prog_size: usize = @sizeOf(Prog) / 1024;
        //~ _ = lib.c.printf("static size = %d kb\r\n", prog_size);
        //~ lib.print("\r\n");
        self.console.init(); defer {
            self.console.deInit();
            lib.print(ansi.cyrsor_style.show);
            lib.print("\r\n");
        }
        self.buffer.init() catch return error.BufferNotInit;
        switch (std.os.argv.len) { // check arguments
            1    => { // use usage text
                const path = "ScalpiEditor_usage.txt";
                self.view.init(path, usage_text) catch return error.ViewNotInit;
            },
            else => { // load file
                var   argument    = try getTextFromArgument();
                const parsed_path = try ParsePath.init(argument);
                const file_data_allocated = lib.loadFile(parsed_path.file_name) catch |loadFile_result| switch (loadFile_result) { 
                    error.FileNotExist => { // exit
                        lib.print( // print "File not exist"
                            \\  File not exist. 
                            \\  ScalpiEditor does not create files itself.
                            \\  You can create file with "touch" command: 
                            \\     touch file_name
                            \\
                            \\
                        );
                        return;
                    },
                    error.Unexpected => return error.Unexpected,
                };
                defer lib.c.free(file_data_allocated.ptr);
                self.view.init(parsed_path.file_name, file_data_allocated) catch return error.ViewNotInit;
            }, // end load file
        } // end switch
        self.mainLoop();
    } // end fn main
    pub fn mainLoop             (self: *Prog) void {
        while (true) {
            self.console.updateSize();
            self.updateKeys();
            if (self.working == false) return; 
            self.view.draw();
            std.time.sleep(std.time.ns_per_ms * 20);
        }
    }
    pub fn stop                 (self: *Prog) void {
        self.view.need_redraw = false;
        self.working = false;
        self.console.cursorMoveToEnd();
    }
    pub fn debug                (self: *Prog) void {
        if (true) return;
        var buffer: [254]u8 = undefined;
        lib.print(ansi.color.magenta);
        const debug_lines  = 7;
        var print_offset: usize = self.console.size.y - debug_lines + 1;
        self.console.cursorMove(.{.x = 0, .y = print_offset});
        { // current line
            const as_num :usize = (@ptrToInt(self.view.current.line) - @ptrToInt(&self.buffer.lines)) / @sizeOf(Line);
            const sprintf_result = lib.c.sprintf(&buffer, "current line = %d", as_num);
            const buffer_count   = @intCast(usize, sprintf_result);
            self.console.print(buffer[0..buffer_count]);
            self.console.fillSpacesToEndLine();
        }
        { // current line prev
            self.console.cursorMoveToNextLine();
            if (self.view.current.line.prev) |prev| {
                const as_num :usize  = (@ptrToInt(prev) - @ptrToInt(&self.buffer.lines)) / @sizeOf(Line);
                const sprintf_result = lib.c.sprintf(&buffer, "line.prev = %d", as_num);
                const buffer_count   = @intCast(usize, sprintf_result);
                self.console.print(buffer[0..buffer_count]);
            } else {
                self.console.print("line.prev = null");
            }
            self.console.fillSpacesToEndLine();
        }
        { // current line next
            self.console.cursorMoveToNextLine();
            if (self.view.current.line.next) |next| {
                const as_num :usize  = (@ptrToInt(next) - @ptrToInt(&self.buffer.lines)) / @sizeOf(Line);
                const sprintf_result = lib.c.sprintf(&buffer, "line.next = %d", as_num);
                const buffer_count   = @intCast(usize, sprintf_result);
                self.console.print(buffer[0..buffer_count]);
            } else {
                self.console.print("line.next = null");
            }
            self.console.fillSpacesToEndLine();
        }
        { // self.view.mode
            self.console.cursorMoveToNextLine();
            switch (self.view.mode) {
                .Line    => {
                    self.console.print("mode = Line");
                },
                .Symbol  => {
                    self.console.print("mode = Symbol");
                },
            }
            self.console.fillSpacesToEndLine();
        }
        { // view.offset.x
            self.console.cursorMoveToNextLine();
            const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "view.offset .x = %d, .y = %d", self.view.offset.x, self.view.offset.y));
            self.console.print(buffer[0..buffer_count]);
            self.console.fillSpacesToEndLine();
        }
        { // line.used
            self.console.cursorMoveToNextLine();
            const used           = self.view.current.line.used;
            const sprintf_result = lib.c.sprintf(&buffer, "line.len = %d", used);
            const buffer_count   = @intCast(usize, sprintf_result);
            self.console.print(buffer[0..buffer_count]);
            self.console.fillSpacesToEndLine();
        }
        { // current_symbol
            self.console.cursorMoveToNextLine();
            const used           = self.view.current.symbol;
            const sprintf_result = lib.c.sprintf(&buffer, "symbol = %d", used);
            const buffer_count   = @intCast(usize, sprintf_result);
            self.console.print(buffer[0..buffer_count]);
            self.console.fillSpacesToEndLine();
        }
        lib.print(ansi.reset);
        self.console.fillSpacesToEndLine();
    }
    pub fn updateKeys           (self: *Prog) void {
        _ = self;
        var count: usize  = undefined;
        { // get count
            var bytesWaiting: c_int = undefined;
            const f_stdin = lib.c.fileno(lib.c.stdin);
            _ = lib.c.ioctl(f_stdin, lib.c.FIONREAD, &bytesWaiting);
            count = @intCast(usize, bytesWaiting);
        } // end get count
        if (count == 0) return;
        var   key:    ansi.key = .Ctrl2; // :u64 = 0;
        const buffer: []u8     = @ptrCast([*]u8, &key)[0..8]; // u64
        { // read buffered bytes
            if (count == 0) return;
            var pos: usize = 0;
            while(true) {
                const char: c_int = lib.c.getchar();
                if(pos < 8) {
                    buffer[pos] = @ptrCast(*const u8, &char).*;
                }
                pos += 1;
                if (pos == count) break;
            }// end while
        } // end get chars
        switch (self.view.mode) {
            .Line   => {
                switch (key) {
                    .CtrlQ           => self.stop(),
                    .CtrlS           => self.view.save(),
                    .H               => self.view.goToPrevSymbol(),
                    .L               => self.view.goToNextSymbol(),
                    .ArrowUp,   .K   => self.view.goToPrevLine(),
                    .ArrowDown, .J   => self.view.goToNextLine(),
                    .I               => self.view.changeMode(.Symbol),
                    .ArrowLeft       => self.view.changeMode(.Symbol),
                    .ArrowRight      => self.view.changeMode(.Symbol),
                    .ShiftEnter      => {_ = self.view.addPrevLine() catch return;},
                    .AltEnter        => {_ = self.view.addNextLine() catch return;},
                    else             => {},
                } // end switch(key)
            }, // end .Line =>
            .Symbol => {
                switch (key) {
                    .CtrlQ      => self.stop(),
                    .CtrlS      => self.view.save(),
                    .CtrlD      => {if (self.view.current.line.used > 0) self.view.popSymbol(self.view.current.symbol);     self.view.goToPrevSymbol();},
                    .BS         => {if (self.view.current.symbol > 0)    self.view.popSymbol(self.view.current.symbol - 1); self.view.goToPrevSymbol();},
                    .Del        => self.view.popSymbol(self.view.current.symbol),
                    .esc        => self.view.changeMode(.Line),
                    .ArrowUp    => self.view.goToPrevLine(),
                    .ArrowDown  => self.view.goToNextLine(),
                    .ArrowLeft  => self.view.goToPrevSymbol(),
                    .ArrowRight => self.view.goToNextSymbol(),
                    .ShiftEnter => {_ = self.view.addPrevLine() catch return;},
                    .AltEnter   => {_ = self.view.addNextLine() catch return;},
                    else        => {
                        const rune = buffer[0]; 
                        switch(rune) {
                            0    => {},
                            else => self.view.insertSymbol(rune),
                        }
                    }
                } // end switch(key)
            }, // end .Symbol
        } // end switch(mode)
    } // end fn updateKeys
//} end methods
//{ export
    pub var prog: Prog = .{};
//} end export
