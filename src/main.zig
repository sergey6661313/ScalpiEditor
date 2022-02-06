// zig fmt: off
const     Prog           = @This();
const     std            = @import("std");
pub const ansi           = @import("ansi.zig");
pub const lib            = @import("lib.zig");
pub const ParsePath      = @import("ParsePath.zig");
pub const Line           = @import("Line.zig");
pub const Console        = @import("Console.zig");
pub const Buffer         = struct {
    pub const size = 25000; // about 10 mb...
    lines:  [size]Line   = .{.{}} ** size, // OwO syntax ¯\_(O.o)_/¯
    free:   ?*Line       = undefined,
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
    pub fn delete   (self: *Buffer, line: *Line) void {
        // TODO unfold this line and delete every lines
        //{ change links
        if (line.prev) |prev| {
          prev.next = line.next;
        }
        if (line.next) |next| {
          next.prev = line.prev;
        }
        if (line.parent) |parent| {
          parent.child = line.next;
          if (line.next) |next| {
            next.parent = parent;
          }
        }
        line.prev = null;
        line.next = null;
        line.parent = null;
        //}
        // add to free
        line.next = self.free;
        self.free = line;
    } // end fn delete
};
pub const View           = struct {
    pub const Mode            = enum {
      Edit,
      GoToLine,
      History,
    };
    mode:         Mode        = .Edit,
    file_name:    [1024]u8    = undefined,
    first:        *Line       = undefined, // need only for saving file...
    line:         *Line       = undefined,
    symbol:       usize       = 0,
    offset:       lib.Coor2u  = .{.y = 1},
    need_redraw:  bool        = true,
    focus:        bool        = false,
    cutted:       ?*Line      = null,
    pub fn init                 (self: *View, file_name: []const u8, text: []const u8) !void {
        self.* = .{};
        self.setFileName(file_name);
        self.first = try prog.buffer.create();
        parse_text_to_lines: { // parse_text_to_lines
            if (text.len == 0) break :parse_text_to_lines;
            var line = self.first;
            var data_pos:   usize = 0;
            var symbol_pos: usize = 0;
            while (true) {
                if (data_pos == text.len) break;
                const symbol = text[data_pos];
                if (symbol == '\n') {
                    const new_line = try prog.buffer.create();
                    line.pushNext(new_line);
                    line = new_line;
                    data_pos += 1;
                    symbol_pos = 0;
                    continue;
                }
                
                line.text.insert(symbol_pos, symbol) catch {
                    std.log.info("\n\ndata_pos: {}, symbol_pos: {}\n\n",.{data_pos, symbol_pos});
                    return error.NotInit;
                };
                data_pos   += 1;
                symbol_pos += 1;
            } // end while
        }
        self.line     = self.first;
        self.offset.y = 0;
        self.offset.x = 0;
        self.need_redraw = true;
    } // end fn loadLines
    pub fn drawUpperLines       (self: *View) void {
      if (self.offset.y == 0) return;
      var pos_y:     usize  = self.offset.y - 1;
      var last_line: *Line  = self.line;

      // draw lines
      var current:   ?*Line = self.line.prev;
      while (current) |line| {
        self.drawLine(line, pos_y);
        if (pos_y == 0) return;
        pos_y     -= 1;
        current   = line.prev;
        last_line = line;
      }

      // draw parents
      lib.print(ansi.color.blue);
      while (last_line.getParent()) |parent| {
        self.drawLine(parent, pos_y);
        if (pos_y == 0) break;
        pos_y     -= 1;
        last_line = parent;
      }
      lib.print(ansi.reset);
    }
    pub fn drawDownerLines      (self: *View) void {
      var line  = self.line;
      var pos_y = self.offset.y;
      while(true) {
        if (pos_y < prog.console.size.y - 1) {
          if (line.next) |next| {
            pos_y += 1;
            line = next;
            self.drawLine(line, pos_y);
            continue;
          }
        }
        break;
      }
    }
    pub fn draw                 (self: *View) void {
        if(self.need_redraw == false) return;
        self.need_redraw = false;
        prog.console.clear();
        lib.print(ansi.reset);
        self.drawEditedLine(self.line, self.offset.y);
        self.drawUpperLines();
        self.drawDownerLines();
        //~ prog.debug();
        self.cursorMoveToCurrent();
    } // end draw lines
    pub fn cursorMoveToCurrent  (self: *View) void {
        prog.console.cursorMove(.{.x = self.offset.x, .y = self.offset.y});
    }
    pub fn drawLine             (self: *View, line: *Line, offset_y: usize) void {
        const text = line.text.get();
        // draw left-to-right from first visible rune
        prog.console.cursorMove(.{.x = 0, .y = offset_y});
        var pos:      usize = self.symbol - self.offset.x; 
        var offset_x: usize = 0;
        while(offset_x < prog.console.size.x){
            drawSymbol(text, pos);
            pos += 1;
            offset_x += 1;
        }
    }
    pub fn drawEditedLine       (self: *View, line: *Line, offset_y: usize) void {
        const text = line.text.get();
        
        // draw left-to-right from first visible rune
        prog.console.cursorMove(.{.x = 0, .y = offset_y});
        var pos:      usize = self.symbol - self.offset.x; 
        var offset_x: usize = 0;

        if (pos > 0) {
            lib.print(ansi.color.magenta);
            prog.console.printRune('<');
            pos += 1;
            offset_x += 1;
        }

        // left symbols
        lib.print(ansi.color.cyan);
        while(offset_x < self.offset.x) {
            drawSymbol(text, pos);
            pos += 1;
            offset_x += 1;
        }
        
        // current symbol. maybe inverse cursour?
            lib.print(ansi.color.yellow);
            drawSymbol(text, pos);
            pos += 1;
            offset_x += 1;
        
        // right symbols
        lib.print(ansi.color.cyan);
        while(offset_x < prog.console.size.x - 1){
            drawSymbol(text, pos);
            pos += 1;
            offset_x += 1;
        }
        if (text.len > pos) {
            lib.print(ansi.color.magenta);
            prog.console.printRune('>');
        } else {
            prog.console.printRune(' ');          
        }
        lib.print(ansi.reset);
    }
    pub fn drawSymbol           (text: []u8, pos: usize) void {
        if (pos >= text.len) {
            prog.console.printRune(' ');
        } else {
            prog.console.printRune(text[pos]);
        }
    }
    pub fn save                 (self: *View) void {
        self.need_redraw = false;
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
                const text = line.text.get();
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
    pub fn goToPrevLine         (self: *View) void {
        if (self.line.prev) |prev| {
            self.line = prev;
        } 
        else {
            return;
        }

        // correct offset_y:
        if (self.offset.y > 1) self.offset.y -= 1;
        var count_to_upperest_line: usize = 0;
        var line: *Line = self.line;
        while (count_to_upperest_line < 5) {
          if (line.prev) |prev| {
            count_to_upperest_line += 1;
            line = prev;
          } else {
            break;
          }
        }
        if (self.offset.y < count_to_upperest_line + 1) self.offset.y = count_to_upperest_line + 1;

    } // end fn
    pub fn goToNextLine         (self: *View) void {
        if (self.line.next) |next| {
            self.line = next;
        } else {
            return;
        }

        // correct offset_y:
        if (self.offset.y < prog.console.size.y - 1) self.offset.y += 1;
        var count_to_downest_line: usize = 0;
        var line: *Line = self.line;
        while (count_to_downest_line < 5) {
          if (line.next) |next| {
            count_to_downest_line += 1;
            line = next;
          } else {
            break;
          }
        }
        if (prog.console.size.y - self.offset.y < count_to_downest_line) self.offset.y = prog.console.size.y - count_to_downest_line;
    } // end fn
    pub fn goToPrevSymbol       (self: *View) void {
        const used = self.line.text.used;
        if (self.symbol == 0) {
          if (self.line.prev) |_| {
            self.goToPrevLine();
            self.goToEndOfLine();
          }
          return;
        }
        if (self.symbol > used) {
            self.symbol = used;
            if (used < prog.console.size.x - 1) self.offset.x = self.line.text.used;
            return;
        }
        if (self.symbol > 0) self.symbol   -= 1;
        if (self.symbol >= 10) {
            if (self.offset.x > 10) self.offset.x -= 1;
        } else {
            if (self.offset.x > 0) self.offset.x -= 1;
        }
    }
    pub fn goToNextSymbol       (self: *View) void {
        const used = self.line.text.used;
        if (self.symbol >= used) {
            if (self.line.next) |_| {
              self.goToNextLine();
              self.goToStartOfLine();
            }
            return;
        }
        if (self.symbol   < Line.Text.size - 1)      self.symbol   += 1;
        if (used - self.symbol >= 10) {
            if (self.offset.x < prog.console.size.x - 12) self.offset.x += 1;
        } else {
            if (self.offset.x < prog.console.size.x - 2) self.offset.x += 1;
        }
    }
    pub fn insertSymbol         (self: *View, rune: u8) void {
        self.line.text.insert(self.symbol, rune) catch return;
        self.goToNextSymbol();
    } // end fn
    pub fn addPrevLine          (self: *View) void {
        const new_line = prog.buffer.create() catch return;
        self.line.pushPrev(new_line);
        if (self.first == self.line) self.first = new_line;
        self.goToPrevLine();
    }
    pub fn addNextLine          (self: *View) void {
        const new_line = prog.buffer.create() catch return;
        self.line.pushNext(new_line);
        self.goToNextLine();
    }
    pub fn setFileName          (self: *View, name: []const u8) void {
        std.mem.copy(u8, self.file_name[0..], name);
        self.file_name[name.len] = 0;
    }
    pub fn deleteSymbol         (self: *View) void {
        if (self.line.text.used == 0) return;
        self.line.text.delete(self.symbol) catch return;
    }
    pub fn deletePrevSymbol     (self: *View) void {
        if (self.symbol         == 0) {
          var next = self.line;
          if (next.prev) |prev| {
            const next_used = next.text.used;
            const prev_used = prev.text.used;
            if (prev_used + next_used > 252) return;
            std.mem.copy(u8, prev.text.buffer[prev.text.used..], next.text.get());
            prev.text.used += next_used;
            self.cutLine();
            self.goToPrevLine();
            self.symbol = prev_used;
            if (prev_used > prog.console.size.x - 5) {
                self.offset.x = prog.console.size.x - 5;
            } else {
                self.offset.x = prev_used;
            }
          }
          return;
        }
        if (self.line.text.used == 0) return;
        self.goToPrevSymbol();
        self.deleteSymbol();
    }
    pub fn cutLine              (self: *View) void {
        var next_selected_line: *Line = undefined;
        if (self.line.next)          |next| {
            next_selected_line = next;
        } else if (self.line.prev)   |prev| {
            next_selected_line = prev;
        } else if (self.line.parent) |parent| {
            next_selected_line = parent;
        } else {
            self.line.text.set("");
            return;
        }
        prog.buffer.delete(self.line);
        self.line = next_selected_line;
    }
    pub fn clearLine            (self: *View) void {
      self.line.text.used = 0;
    }
    pub fn goToIn               (self: *View) void {
      if (self.line.child) |child| {
        self.line = child;
        self.offset.y = 1;
      }
    }
    pub fn goToOut              (self: *View) void {
      if (self.line.getParent()) |parent| {
        self.line = parent;
        self.offset.y = 6;
      }
    }
    pub fn divide               (self: *View) void {
        var parent = self.line;
        var pos    = self.symbol;
        if (pos > self.line.text.used) pos = self.line.text.used;
        self.addNextLine();
        self.line.text.set(parent.text.get()[pos ..]);
        parent.text.used = pos;
        self.goToStartOfLine();
    }
    pub fn goToStartOfLine      (self: *View) void {
      self.symbol   = 0;
      self.offset.x = 0;
    }
    pub fn goToEndOfLine        (self: *View) void {
      self.symbol   = self.line.text.used;
      if (self.symbol > prog.console.size.x - 2) {
          self.offset.x = prog.console.size.x - 2;
      } else {
          self.offset.x = self.symbol;
      }
    }
    pub fn duplicateLine        (self: *View) void {
      var prev = self.line;
      self.addNextLine();
      self.line.text.set(prev.text.get());
    }
    pub fn swapWithUpper        (self: *View) void {
        self.cutLine();
        self.goToPrevLine();
        self.addPrevLine();
        if (self.offset.y != 0) self.offset.y += 1;
    }
    pub fn swapWithBottom       (self: *View) void {
        self.cutLine();
        self.addNextLine();
    }
    pub fn goToRoot             (self: *View) void {
      self.line     = self.first;
      self.offset.y = 1;
      self.goToStartOfLine();
    }
    pub fn deleteLine           (self: *View) void {
        var next_selected_line: *Line = undefined;
        if (self.line.next)          |next| {
            next_selected_line = next;
        } else if (self.line.prev)   |prev| {
            next_selected_line = prev;
        } else if (self.line.parent) |parent| {
            next_selected_line = parent;
        } else {
            self.line.text.set("");
            return;
        }
        prog.buffer.delete(self.line);
        self.line = next_selected_line;      
    }
    pub fn pasteLine            (self: *View) void {
        const new_line = prog.buffer.create() catch return;
        self.line.pushPrev(new_line);
        if (self.first == self.line) self.first = new_line;
        self.offset.y += 1;
        self.goToPrevLine();
    }
};
pub const CommandLine    = struct {
  text: [254]u8 = undefined,
  used: usize   = 0,
   
};
const     MainErrors     = error  {
    BufferNotInit,
    ViewNotInit,
    Unexpected,
};
pub var   prog: Prog = .{};
working:  bool     = true,
console:  Console  = .{},
buffer:   Buffer   = .{},
view:     View     = .{},
pub fn main                 ()            MainErrors!void {
    const self = &prog;
    self.buffer.init() catch return error.BufferNotInit;
    switch (std.os.argv.len) { // check arguments
        1    => { // show usage text
            const path = "ScalpiEditor_usage.txt";
            const text = @embedFile("ScalpiEditor_usage.txt");
            self.view.init(path, text) catch return error.ViewNotInit;
        },
        else => { // load file
            var   argument    = try lib.getTextFromArgument();
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
    self.console.init(); defer {
        self.console.deInit();
        lib.print(ansi.cyrsor_style.show);
        lib.print("\r\n");
    }
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
    //~ if (true) return;
    var buffer: [254]u8 = undefined;
    lib.print(ansi.color.magenta);
    const debug_lines  = 6;
    var print_offset: usize = self.console.size.y - debug_lines;
    self.console.cursorMove(.{.x = 0, .y = print_offset});
    { // line
        const as_num :usize  = (@ptrToInt(self.view.line) - @ptrToInt(&self.buffer.lines)) / @sizeOf(Line);
        const sprintf_result = lib.c.sprintf(&buffer, "line = %d", as_num);
        const buffer_count   = @intCast(usize, sprintf_result);
        self.console.print(buffer[0..buffer_count]);
        self.console.fillSpacesToEndLine();
    }
    { // current line prev
        self.console.cursorMoveToNextLine();
        if (self.view.line.prev) |prev| {
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
        if (self.view.line.next) |next| {
            const as_num :usize  = (@ptrToInt(next) - @ptrToInt(&self.buffer.lines)) / @sizeOf(Line);
            const sprintf_result = lib.c.sprintf(&buffer, "line.next = %d", as_num);
            const buffer_count   = @intCast(usize, sprintf_result);
            self.console.print(buffer[0..buffer_count]);
        } else {
            self.console.print("line.next = null");
        }
        self.console.fillSpacesToEndLine();
    }
    { // view.offset
        self.console.cursorMoveToNextLine();
        const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "view.offset .x = %d, .y = %d", self.view.offset.x, self.view.offset.y));
        self.console.print(buffer[0..buffer_count]);
        self.console.fillSpacesToEndLine();
    }
    { // line.used
        self.console.cursorMoveToNextLine();
        const used           = self.view.line.text.used;
        const sprintf_result = lib.c.sprintf(&buffer, "line.len = %d", used);
        const buffer_count   = @intCast(usize, sprintf_result);
        self.console.print(buffer[0..buffer_count]);
        self.console.fillSpacesToEndLine();
    }
    { // symbol
        self.console.cursorMoveToNextLine();
        const used = self.view.line.text.used;
        var   sprintf_result: c_int = 0;
        if (self.view.symbol >= used) {
            sprintf_result = lib.c.sprintf(&buffer, "symbol = %d (null)", self.view.symbol);
        } else {
            sprintf_result = lib.c.sprintf(&buffer, "symbol = %d (%c)",   self.view.symbol, self.view.line.text.get()[self.view.symbol]);
        }
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
    self.view.need_redraw = true;
    var   key:    ansi.key = .Ctrl2; // :u64 = 0;
    const buffer: []u8     = @ptrCast([*]u8, &key)[0..8]; // u64
    { // read buffered bytes
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
    switch (key) {
        .CtrlQ           => self.stop(),
        .CtrlS           => self.view.save(),
        //.CtrlR           => self.view.first.foldFromIndent(' '),
        //.CtrlT           => self.view.first.foldFromIndent('\t'),
        .CtrlP           => self.view.first.foldFromBrackets(),
        .CtrlU           => self.view.first.unFold(),
        .ArrowRight,     => self.view.goToNextSymbol(),
        .ArrowLeft,      => self.view.goToPrevSymbol(),
        .ArrowUp,        => self.view.goToPrevLine(),
        .ArrowDown,      => self.view.goToNextLine(),
        .Ctrl8           => self.view.deletePrevSymbol(),
        .Del             => self.view.deleteSymbol(),
        .Home            => self.view.goToStartOfLine(),
        .End             => self.view.goToEndOfLine(),
        .CtrlX           => self.view.cutLine(),
        .CtrlC           => self.view.duplicateLine(),
        .CtrlV           => self.view.pasteLine(),
        .CtrlM           => self.view.divide(), // enter
        .CtrlI           => self.view.goToIn(),
        .CtrlO           => self.view.goToOut(),
        .CtrlD           => self.view.deleteLine(),
        .CtrlJ           => self.view.swapWithBottom(),
        .CtrlK           => self.view.swapWithUpper(),
        .Ctrl7           => self.view.goToRoot(), // slash
        else             => self.view.insertSymbol(buffer[0]),
    } // end switch(mode)
} // end fn updateKeys
