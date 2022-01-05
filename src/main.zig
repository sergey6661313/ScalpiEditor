// zig fmt: off
//{ defines
        const Prog       = @This();
        const std        = @import("std");
    pub const ansi       = @import("ansi.zig");
    pub const lib        = @import("lib.zig");
    pub const ParsePath  = @import("ParsePath.zig");
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
            \\This is ScalpiEditor - "heirarhy" text editor.
            \\Navigate on your code in MC-like style
            \\
            \\usage examples:
            \\    ScalpiEditor ~/.bashrc  => open to edit file "~/.bashrc"
            \\
            \\
            \\basic keys: 
            \\              [ctrl] + [q]  =X  exit
            \\                     [ESC]  =X  change mode to block navigation
            \\                      [F2]  =X  change view mode (current, tree)
            \\              [Ctrl] + [s]  =X  save
            \\
            \\block navigation:
            \\                       [↑]  =>  select upper  line
            \\                       [↓]  =>  select bottom line
            \\                   [Enter]  =X  open selected block
            \\      [ctrl] + [BackSpace]  =X  exit of block
            \\
            \\block functions: (recursive)
            \\              [Ctrl] + [x]  =X  cut
            \\              [Ctrl] + [c]  =X  copy 
            \\              [Ctrl] + [v]  =X  paste
            \\              [Ctrl] + [d]  =X  delete
            \\    [shift] + [Ctrl] + [v]  =X  paste inside (create block)
            \\
            \\         [Shift] + [Enter]  =X  create blank line upper current line
            \\          [Ctrl] + [Enter]  =X  create blank line below current line
            \\
            \\line navigation:
            \\                       [←]  =X  move cursour left  (change mode to edit)
            \\                       [→]  =X  move cursour right (change mode to edit)
            \\
            \\marks:
            \\            [Alt] + [slash] =X create new mark
            \\               [ctrl] + [↑] =X jump to prev mark
            \\               [ctrl] + [↓] =X jump to next mark
            \\
            \\
        ;
    //} // end usage text
    const SignalKey      = enum {
            CtrlQ,
            CtrlS,
            CtrlZ,
            CtrlX,
            CtrlC,
            CtrlV,

        pub fn ctrlCHandler(_: c_int) callconv(.C) void {
            prog.terminal_signal_key_pressed = .CtrlC;
            _ = lib.c.signal(lib.c.SIGINT, SignalKey.ctrlCHandler);
        }
    };
//} // end defines
//{ fields
    console:                      Console    = .{},
    working:                      bool       = true,
    buffer:                       Buffer     = .{},
    selected_line_id:             usize      = 0,
    need_redraw:                  bool       = true,
    amount_drawable_upper_lines:  usize      = 0,
    terminal_signal_key_pressed:  ?SignalKey = null,
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
        lib.print("\r\n");
        //{ init systems
            self.console.init(); defer self.console.deInit();
            self.buffer.init() catch return error.BufferNotInit;
        //}
        //~ lib.print(ansi.cyrsor_style.hide);
        //~ defer lib.print(ansi.cyrsor_style.show);
        //{ load text (from argument)
            if (std.os.argv.len == 1) { // load usage text
                //{ set path
                    const path = "ScalpiEditor_usage.txt";
                    std.mem.copy(u8, self.buffer.file_name[0..], path);
                //}
                self.loadLinesToBuffer(usage_text);
            } else { // load file
                //{ get path from arguments
                    var   argument    = try getTextFromArgument();
                    const parsed_path = try ParsePath.init(argument);
                //}
                //{ read file
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
                //}
                //{ create buffer with this file
                    //{ copy file_name
                        std.mem.copy(u8, self.buffer.file_name[0..], parsed_path.file_name);
                    //}
                    //{ load lines
                        self.loadLinesToBuffer(file_data_allocated);
                        lib.c.free(file_data_allocated.ptr);
                        self.buffer.file_name[parsed_path.file_name.len] = 0;
                    //}
                //} // create buffer with this file
            } // end if
        //}
        self.mainLoop();
        lib.print("\r\n");
    }
    pub fn mainLoop             (self: *Prog) void {
        while (self.working) {
            self.updateKeys();
            if(self.need_redraw) self.draw();
            std.time.sleep(std.time.ns_per_ms * 20);
        }
    }
    pub fn draw                 (self: *Prog) void {
        self.need_redraw = false;
        const current_line = prog.buffer.lines.get(self.selected_line_id);
        self.console.updateSize();
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
                        self.console.fillSpacesToEndLine();
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
            lib.print(Prog.ansi.colors.cyan);
            const text = current_line.getText();
            if (text.len == 0) {
                self.console.print("_");
            } else {
                self.console.print(text);
            }
            lib.print(Prog.ansi.reset);
            self.console.fillSpacesToEndLine();
        } // end draw selected line
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
                        self.console.fillSpacesToEndLine();
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
    pub fn save                 (self: *Prog) void {
        //{ change status
            self.console.cursorMove(.{.x = 0, .y = 0});
            self.console.print("saving...");
            self.console.fillSpacesToEndLine();
        //}
        self.unFold(0);
        var file = lib.File {};
        file.open(self.buffer.file_name[0..], .ToWrite) catch unreachable;
        defer file.close() catch unreachable;
        var line_id: usize = 0;
        var count:   usize = 0;
        while(true) {
            const line = self.buffer.lines.get(line_id);
            const text = line.getText();
            file.write(text);
            count += 1;
            if (line.next) |next_id|  {
                file.write("\n");
                line_id = next_id;
                continue;
            } 
            break;
        } // end while
        self.console.cursorMove(.{.x = 0, .y = 0});
        var buffer: [254]u8 = undefined;
        // i used sprintf becouse i just find documentation on this. 
        // i do not found examples/docs to std.fmt :(
        _ = lib.c.sprintf(&buffer, "file saved. %d lines writed.", count);
        self.console.print(&buffer);
        self.console.fillSpacesToEndLine();
    }
    pub fn unFold               (self: *Prog, _line_id: usize) void {
        var current_line_id = _line_id;
        while(true) {
            const current_line = self.buffer.lines.get(current_line_id);
            if (current_line.child) |child_id| {
                const child = self.buffer.lines.get(child_id);
                //{ unChild from current
                    current_line.child = null; 
                //}
                //{ set prev
                    child.prev = current_line_id;
                //}
                //{ insert into last and current.next
                    if (current_line.next) |parent_next_id| {
                        const Line = Buffer.Lines.Line;
                        const parent_next: *Line   = self.buffer.lines.get(parent_next_id);
                        var   last_id:     usize   = child_id;
                        var   last:        *Line   = self.buffer.lines.get(last_id);
                        //{ find last
                            while(true) {
                                if(last.next) |next| {
                                    last_id = next;
                                    last    = prog.buffer.lines.get(last_id);
                                } else break;
                            } // end while
                        //}
                        //{ set last.next
                            last.next = parent_next_id;
                        //}
                        //{ set parent_next.prev
                            parent_next.prev = last_id;
                        //}
                    } // end if
                //} end insert into last and current.next
                current_line.next = child_id;
            } // end if current_line.child
            if (current_line.next)  |next_id|  {
                current_line_id = next_id;
                continue;
            }
            break;
        } // end while
    } // end fn
    pub fn updateKeys           (self: *Prog) void {
        var count: usize  = undefined;
        var buffer: [15]u8 = undefined;
        //{ get count
            var bytesWaiting: c_int = undefined;
            const f_stdin = lib.c.fileno(lib.c.stdin);
            _ = lib.c.ioctl(f_stdin, lib.c.FIONREAD, &bytesWaiting);
            count = @intCast(usize, bytesWaiting);
        //}
        if (count == 0) return;
        const bytes = buffer[0..count];
        { // get bytes
            var pos: usize = 0;
            while(true) {
                const char: c_int = lib.c.getchar();
                bytes[pos] = @ptrCast(*const u8, &char).*;
                pos += 1;
                if(pos == count) break;
            }// end while
        } // end get chars
        if (count > 1) {
            const mk = ansi.MultiKey.fromBytes(bytes);
            switch (mk) {
                .ArrowUp    => self.prevLine(),
                .ArrowDown  => self.nextLine(),
                else => {},
                //=> prog.save(),
            }
        } else {
            switch(bytes[0]) {
                ansi.key.CtrlQ => self.stop(),
                else => {},
            } // end switch
        }
    } // end fn updateKeys
    pub fn stop                 (self: *Prog) void {
        self.working = false;
    }
    pub fn prevLine             (self: *Prog) void {
        const curent_line = self.buffer.lines.get(self.selected_line_id);
        const prev = curent_line.prev;
        if (prev) |id| {
            if (self.amount_drawable_upper_lines > 0) {
                self.amount_drawable_upper_lines -= 1;
            }
            self.selected_line_id = id;
            self.need_redraw = true;
        }
    }
    pub fn nextLine             (self: *Prog) void {
        const curent_line = self.buffer.lines.get(self.selected_line_id);
        const next = curent_line.next;
        if (next) |id| {
            self.selected_line_id = id;
            self.need_redraw = true;
            if (self.amount_drawable_upper_lines < self.console.size.y) {
                self.amount_drawable_upper_lines += 1;
            }
        }
    }
//} end methods
//{ export
    pub var prog: Prog = .{};
//} end export
