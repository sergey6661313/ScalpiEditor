// TODO: add words instead lines.text
// TODO: remove buffer_lines.lines (use allocated memory and "first") {
  // create "flat_next" and "flat_prev" fix used functions and test this
  // fix "go to line from number" to work without '&' (use loop from first line and flat_next in loop)
  // defragmentate lines in memory for deinit (if need free)
  // rename buffer_lines.find_text to line_for_text_finding
// }

// { imports
  const     Prog         = @This();
  const     std          = @import("std");
  pub const lib          = @import("lib/src/lib.zig");
  pub const ansi         = @import("ansi/src/ansi.zig");
  pub const ParsePath    = @import("ParsePath.zig");
  
  pub const Text         = @import("Text.zig"); // old
  pub const Line         = @import("Line.zig");
  pub const Rune         = @import("Rune.zig");
  pub const Glyph        = @import("Glyph.zig");
  
  pub const Console      = @import("Console/src/Console.zig");
  pub const MapableFile  = @import("MapableFile/src/MapableFile.zig");
  pub const File         = @import("File/src/File.zig");
// }
// { defines
  pub const Window       = struct {
    size: lib.Coor2u = .{},
    pos:  lib.Coor2u = .{},
  };
  pub const BufferGlyphs = struct {
    const Self = @This();
    blanks: ?*Glyph = null,    
  };
  pub const BufferRunes  = struct {
    const Self = @This();
    blanks: ?*Rune = null,    
  };
  pub const BufferLines  = struct {
    const Self = @This();
    pub const size = 25000;
    lines:         [size]Line,
    
    blanks:        ?*Line,
    cutted:        ?*Line,
    to_goto:       ?*Line,
    to_find:       ?*Line,
    
    pub fn allocateNewLines (self: *Self) void {
      _ = self;
    }
    pub fn fromAlloc    () !*Self {
      const allocated    = lib.c.aligned_alloc(8, @sizeOf(Self)) orelse return error.NeedMoreMemory;
      var buffer: *Self = @ptrCast(*Self, @alignCast(8, allocated));
      return buffer;
    }
    pub fn init         (self: *Self) !void {
      self.cutted        = null;
      self.to_goto       = null;
      self.to_find       = null;
      for (self.lines) |*line| { // init all lines:
        line.* = .{};
      }
      self.addBlanks(self.lines[0..]);
      if (false) { //tie all lines to "free" chain
        if (self.lines.len < 2) return error.TooSmallLines;
        { // update ends of range
          const first = &self.lines[0];
          first.next  = &self.lines[1];
          
          const last  = &self.lines[size - 1];
          last.prev   = &self.lines[size - 2];
        }
        { // update others everything in between first and last
          for (self.lines[1..self.lines.len-1]) |*current, id| {
            const pos     = id + 1;
            current.prev  = &self.lines[pos - 1];
            current.next  = &self.lines[pos + 1];
          }
        }
      }
      self.blanks = &self.lines[0];
    } // end fn init
    pub fn delete       (self: *Self, line: *Line) void {
      if (line.child) |_| self.deleteBlock(line) 
      else self.deleteLine(line);
    } // end fn delete
    pub fn create       (self: *Self) !*Line {
      if (self.blanks) |blank| {
        self.blanks   = blank.next; // update self.free
        const line    = blank;
        line.* = .{};
        return line;
      } 
      else return error.NoFreeSlots;
    }
    pub fn deleteBlock  (self: *Self, line: *Line) void {
      const start_line = line;
      const end_line = start_line.next;
      prog.view.unFold();
      var current: ?*Line = start_line;
      while (current) |cur_line| {
        if (current == end_line) break;
        current = cur_line.next;
        self.deleteLine(cur_line);
      }
    } // end fn deleteBlock
    pub fn deleteLine   (self: *Self, line: *Line) void {
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
      //{ add to free
        line.next   = self.blanks;
        self.blanks = line;
      //}
    } // end fn deleteLine
    pub fn cut          (self: *Self, line: *Line) void {
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
      //{ add to cutted
        line.next = self.cutted;
        self.cutted = line;
      //}
    }
    pub fn lineToPos    (self: *Self, line: *Line) usize {
      const ptr = @ptrToInt(line) - @ptrToInt(&self.lines);
      const pos = ptr / @sizeOf(Line);
      return pos;
    }
    pub fn addBlanks    (self: *Self, blanks: []Line) void {
      if (blanks.len == 0) unreachable;
      if (blanks.len >  1) {
        { // update others everything in between first and last
          for (blanks[1..blanks.len-1]) |*current, id| {
            const pos     = id + 1;
            current.prev  = &blanks[pos - 1];
            current.next  = &blanks[pos + 1];
          }
        }
        { // update ends of range
          const first = &blanks[0];
          first.next  = &blanks[1];
          
          const last  = &blanks[blanks.len - 1];
          last.prev   = &blanks[blanks.len - 2];
        }
      }
      if (self.blanks) |blank| {
        const last  = &blanks[blanks.len - 1];
        last.next   = blank;
        blank.prev  = &blanks[blanks.len];
      }
      self.blanks = &blanks[0];
    }
  };
  pub const Theme        = struct {
    const current   = ansi.color.green;
    const folded    = ansi.bg_color.black2;
    const headers   = ansi.color.cyan;
  };
  pub const View         = struct {
    const Self = @This();
    pub const Indent   = struct {
      pub const IndentType = enum {
        space,
        tab,
      };
      indent_type: IndentType = .space,
      size:        usize      = 4,
    };
    pub const Mode     = enum {
      edit,
      to_find,
      to_line,
      history,
      select,
      normal,
      easy_motion_vertical,
      easy_motion_horizontal,
    };
    pub const FoldMode = enum {
      byNone,
      byBrackets,
      byIndent,
    };
    // { fields
      file_name:   Text        = .{},
      window:      Window      = .{.size = .{.x=3, .y=1}, .pos = .{.x=0, .y=0}},
      
      // modes
      mode:        Mode        = .edit,
      foldMode:    FoldMode    = .byNone,
      indent:      Indent      = .{},
      
      selected:    usize       = 0,
      
      lines:              *Line   = undefined,
      line:               *Line   = undefined, // current working line
      bakup_line:         *Line   = undefined,
      last_working_line:  ?*Line  = null,
      marked_line:        ?*Line  = null,
      
      // current pos
      offset:      lib.Coor2u  = .{.x = 0, .y = 3 },
      symbol:      usize       = 0,
    // }
    // { methods
      pub fn fromAlloc            () !*View {
        const allocated = lib.c.aligned_alloc(8, @sizeOf(View)) orelse return error.NeedMoreMemory;
        var view: *View = @ptrCast(*View, @alignCast(8, allocated));
        return view;
      }
      pub fn init                 (self: *View, file_name: []const u8, text: []const u8) !void {
        self.* = .{};
        self.file_name.set(file_name) catch unreachable; 
        self.lines = try prog.buffer_lines.create();
        parse_text_to_lines: {
          if (text.len == 0) break :parse_text_to_lines;
          var line_num:   usize = 0;
          var line:       *Line = self.lines;
          var start_line: usize = 0;
          var data_pos:   usize = 0;
          while (true) { // find first '\n'
            if (data_pos > text.len - 1) {
              const end_line: usize = data_pos;
              line.text.set(text[start_line..end_line]) catch {
                return error.LineIsToLong;
              };
              line_num += 1;
              break :parse_text_to_lines;
            }
            else if (text[data_pos] == '\n') {
              const end_line: usize = data_pos;
              if (end_line > start_line) {
                line.text.set(text[start_line..end_line]) catch {
                  return error.LineIsToLong;
                };
              }
              start_line = end_line + 1;
              line_num += 1;
              data_pos += 1;
              break;
            }
            data_pos += 1;
          }
          while (true) { // find other '\n'
            if (data_pos > text.len - 1) {
              const end_line: usize = data_pos;
              if (end_line > start_line) {
                const new_line = try prog.buffer_lines.create();
                new_line.text.set(text[start_line..end_line]) catch {
                  return error.LineIsToLong;
                };
                line.pushNext(new_line);
                line = new_line;
              }
              start_line = end_line + 1;
              line_num += 1;
              break;
            }
            else if (text[data_pos] == '\n') {
              const end_line: usize = data_pos;
              if (end_line > start_line) {
                const new_line = try prog.buffer_lines.create();
                new_line.text.set(text[start_line..end_line]) catch {
                  return error.LineIsToLong;
                };
                line.pushNext(new_line);
                line = new_line;
              }
              else {
                const new_line = try prog.buffer_lines.create();
                line.pushNext(new_line);
                line = new_line;
              }
              start_line = end_line + 1;
              line_num += 1;
            }
            data_pos += 1;
          } // end while
        }
        self.line = self.lines;
        self.bakup_line = try prog.buffer_lines.create();
      } // end fn loadLines
      pub fn save                 (self: *View) !void {
        prog.need_redraw = false;
        defer {Console.Output.flush();}
        { // change status
          prog.console.cursorMove(.{ .x = 0, .y = 0 });
          Console.Output.print(ansi.reset);
          Console.Output.print(ansi.color.blue2);
          prog.console.print("saving...");
          Console.Output.print(ansi.clear_to_end_line);
          Console.Output.print(ansi.reset);
        }
        const file_name = self.file_name.getSantieled();
        var file = File.fromOpen(file_name, .toWrite) catch unreachable;
        defer file.close() catch unreachable;
        //{ write
          var line: *Line = self.lines;
          var count: usize = 0;
          writing: while (true) {
            const text = line.text.get();
            try file.write(text);
            count += 1;
            if (line.child) |child| {
              try file.write("\n");
              line = child;
            } 
            else if (line.next) |next| {
              try file.write("\n");
              line = next;
            } 
            else { // get parent with next
              while (true) {
                line = line.getParent() orelse break :writing;
                line = line.next orelse continue;
                try file.write("\n");
                break;
              } // end while
            } // end else
          } // end while
        //}
        { // change status
          prog.console.cursorMove(.{ .x = 0, .y = 0 });
          var buffer: [254]u8 = undefined;
          const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "file saved. %d lines writed.", count));
          Console.Output.print(ansi.reset);
          Console.Output.print(ansi.color.blue2);
          prog.console.print(buffer[0..buffer_count]);
          Console.Output.print(ansi.clear_to_end_line);
          prog.console.cursorMoveToEnd();
        }
      }
      pub fn changeMode           (self: *View, mode: Mode) void {
        switch (mode) {
          .edit    => {},
          .to_find => {
            self.last_working_line = self.line;
          },
          .to_line => {
            self.last_working_line = self.line;
            if (prog.buffer_lines.to_goto == null) { // create
              const new_line = prog.buffer_lines.create() catch return;
              prog.buffer_lines.to_goto = new_line;
            }
            self.line = prog.buffer_lines.to_goto.?;
            self.goToEndOfLine();
          },
          .history => {},
          .select  => {},
          .normal  => {},
          .easy_motion_vertical   => {
            self.draw_vertical_help_motion();
          },
          .easy_motion_horizontal => {
            self.draw_horizontal_help_motion();
          },
        }
        self.mode = mode;
      }
      pub fn cursorMoveToCurrent  (self: *View) void {
        prog.console.cursorMove(.{ .x = self.offset.x, .y = self.offset.y });
      }
      // { go to line from number
        pub fn getLineNum           (self: *View) usize {
          return (@ptrToInt(self.line) - @ptrToInt(&prog.buffer.lines)) / @sizeOf(Line);
        }
        pub fn goToLineFromNumber   (self: *View, _num: usize) void {
          var num: usize   = _num + prog.buffer_lines.lineToPos(self.lines) - 1;
          self.line        = &prog.buffer_lines.lines[num];
          self.goToSymbol(self.line.text.countIndent(1));
          self.offset.y    = 6;
          prog.need_clear  = true;
          prog.need_redraw = true;
          self.bakup();
        }
        pub fn goToLineFromInput    (self: *View) void {
          if (self.line.text.used == 0) return;
          var num: usize = @truncate(usize, lib.u64FromCharsDec(self.line.text.get()) catch return);
          self.changeMode(.edit);
          self.goToLineFromNumber(num);
        }
      // }
      // { mark
        pub fn markThisLine         (self: *View) void {
          self.marked_line = self.line;
        }
        pub fn goToMarked           (self: *View) void {
          if (self.marked_line) |mark| {
            self.line = mark;
            prog.need_clear  = true;
            prog.need_redraw = true;
          }
        }
      // }
      // { edit
        pub fn insertSymbol      (self: *View, rune: u8) !void {
          if (self.symbol > self.line.text.used) self.goToSymbol(self.line.text.used);
          try self.line.text.insert(self.symbol, rune);
          self.goToNextSymbol();
          prog.need_redraw  = true;
        } // end fn
        pub fn deleteSymbol      (self: *View) void {
          if (self.line.text.used == 0) return;
          self.line.text.delete(self.symbol) catch return;
          prog.need_redraw  = true;
        }
        pub fn deletePrevSymbol  (self: *View) void {
          if (self.symbol == 0) {
            if (self.line == self.lines) return;
            if (self.line.parent) |_| return;
            var next = self.line;
            if (self.line.prev) |prev| {
              if (prev.text.countNonIndent() == 0) {
                if (prev == self.lines) self.lines = self.line;
                prog.buffer_lines.delete(prev);
              }
              else {
                const next_used = next.text.used;
                const prev_used = prev.text.used;
                if (prev_used + next_used > Line.Text.size - 3) return;
                if (prev_used != 0) { // move cursor
                  self.goToPrevLine();
                  self.goToEndOfLine();
                  self.goToNextLine();
                }
                std.mem.copy(u8, prev.text.buffer[prev.text.used..], next.text.get());
                prev.text.used += next_used;
                self.deleteLine();
                if (self.line.next) |_| self.goToPrevLine();
                self.goToSymbol(prev_used);
              }
            }
            prog.need_clear  = true;
          }
          else {
            if (self.line.text.used == 0) return;
            self.goToPrevSymbol();
            self.deleteSymbol();
          }
          prog.need_redraw  = true;
        }
        pub fn joinLines         (self: *View) void {
          self.deleteIndent();
          self.goToStartOfLine();
          self.deletePrevSymbol();
        }
        pub fn clearLine         (self: *View) void {
          self.line.text.used = 0;
          self.goToStartOfLine();
          prog.need_redraw  = true;
        }
        pub fn addPrevLine       (self: *View) !void {
          const new_line = try prog.buffer_lines.create();
          self.line.pushPrev(new_line);
          if (self.lines == self.line) self.lines = new_line;
          self.goToPrevLine();
          self.goToStartOfLine();
          prog.need_redraw  = true;
        }
        pub fn addNextLine       (self: *View) !void {
          const new_line = try prog.buffer_lines.create();
          self.line.pushNext(new_line);
          self.goToNextLine();
          self.goToStartOfLine();
          prog.need_clear   = true;
          prog.need_redraw  = true;
        }
        pub fn divide            (self: *View) !void {
          const indent = self.line.text.countIndent(1);
          if (self.symbol <= indent) { // just add prev line
            const last_symbol = self.symbol;
            const last_offset = self.offset.x;
            try self.addPrevLine();
            try self.line.changeIndentToCutie();
            self.goToNextLine();
            self.symbol = last_symbol;
            self.offset.x = last_offset;
          } 
          else if (self.symbol >= self.line.text.used) { // just add next line
            if (self.line.text.buffer[self.symbol - 1] == ':') {
              if (self.line.child) |_| return;
              const new_line  = prog.buffer_lines.create() catch return;
              // { link
                self.line.child = new_line;
                new_line.parent = self.line;
              // }
              self.goToIn();
              self.indentToCutie();
              self.goToSymbol(self.line.text.used);
              prog.need_clear  = true;
            }
            else {
              try self.addNextLine();
              self.indentToCutie();
              self.goToStartOfText();
              prog.need_redraw  = true;
            }
          } 
          else if (self.line.text.buffer[self.symbol] == '}' and self.line.text.buffer[self.symbol - 1] == '{') {
            if (self.line.child) |_| return;
            const pos       = self.symbol;
            const last_line = self.line;
            
            const new_line          = prog.buffer_lines.create() catch return;
            // { link
              self.line.child = new_line;
              new_line.parent = self.line;
            // }
            // { copy text and fill spaces
              const text_to_new_line  = last_line.text.get()[pos..];
              std.mem.copy(u8, new_line.text.buffer[indent..], text_to_new_line);
              for (new_line.text.buffer[0 .. indent]) |*rune| rune.* = ' '; // spam spaces
              new_line.text.used  = indent + text_to_new_line.len;
              last_line.text.used = pos;
            // }
            
            self.line = new_line;
            try self.addPrevLine();
            self.indentToCutie();
            self.goToSymbol(self.line.text.used);
            prog.need_clear  = true;
          }
          else { 
            if (self.line.child) |_| return;
            var   parent = self.line;
            var   pos    = self.symbol;
            const text   = self.line.text.get()[pos..];
            try self.addNextLine();
            self.line.text.used = indent + text.len;
            std.mem.copy(u8, self.line.text.buffer[indent..], text);
            for (self.line.text.buffer[0..indent]) |*rune| rune.* = ' ';
            self.goToSymbol(indent);
            parent.text.used = pos;
          }
          prog.need_redraw  = true;
        }
        pub fn swapWithBottom    (self: *View) void {
          if (self.line.next) |_| {
            self.cut();
            self.goToNextLine();
            self.pasteLine();
          }
          prog.need_redraw  = true;
        }
        pub fn swapWithUpper     (self: *View) void {
          if (self.line.prev) |_| {
            self.cut();
            self.goToPrevLine();
            self.pasteLine();
          }
          prog.need_redraw  = true;
        }
        pub fn deleteLine        (self: *View) void {
          var next_selected_line: *Line = undefined;
          if (self.line.next) |next| {
            next_selected_line = next;
          } 
          else if (self.line.prev) |prev| {
            next_selected_line = prev;
          } 
          else if (self.line.parent) |parent| {
            next_selected_line = parent;
          } 
          else {
            self.line.text.set("") catch unreachable;
            return;
          }
          self.clearLine();
          if (self.lines == self.line) self.lines = next_selected_line;
          prog.buffer_lines.delete(self.line);
          self.line = next_selected_line;
          prog.need_redraw  = true;
        }
        pub fn deleteWord        (self: *View) void {
          if (self.symbol > self.line.text.used) {return;}
          while(true) { // delete current symbol
            if (self.symbol == self.line.text.used) {break;}
            switch(self.line.text.buffer[self.symbol]) {
              ' ', '	', '\\', 
              '+', '-', '/', '*', '^',
              '(', ')', '[', ']', '{', '}', 
              '!', '@', '#', '$', '%', '&',
              ':', ';', '"', '\'',
              ',', '.'  
              => {break;},
              else => {self.deleteSymbol();},
            }
          }
          while(true) { // delete prev    symbol
            if (self.symbol == 0) {break;}
            const prev_symbol = self.line.text.buffer[self.symbol - 1];
            switch(prev_symbol) {
              ' ', '	', '\\', 
              '+', '-', '/', '*', '^',
              '(', ')', '[', ']', '{', '}', 
              '!', '@', '#', '$', '%', '&',
              ';', ':', '"', '\'',
              ',', '.'  
              => {break;},
              else => {self.deletePrevSymbol();},
            }
          }
          prog.need_redraw = true;
        }
      //}
      // { draw
        pub fn draw             (self: *View) void {
          defer {
            self.cursorMoveToCurrent();
            Console.Output.print(ansi.cyrsor_style.show);
            Console.Output.flush();
          }

          if (self.symbol < self.offset.x) { // unexpected
            self.offset.x = 0;
            self.symbol = 0;
          }
          Console.Output.print(ansi.cyrsor_style.hide); 
          defer Console.Output.print(ansi.cyrsor_style.show);

          // draw edit line
          prog.console.cursorMove(.{ .x = 0, .y = self.offset.y }); defer self.cursorMoveToCurrent();
          self.drawEditedLine();
          
          // draw other lines
          if (prog.console.size.y <= 1) return;
          self.drawUpperLines();
          self.drawDownerLines();
          
        } // end draw lines
        pub fn drawUpperLines   (self: *View) void {
          var pos_y: usize = self.offset.y;
          var line: *Line  = self.line;
          while (true) { // draw lines
            if (pos_y == 0) return;
            line = line.prev orelse break;
            pos_y -= 1;
            prog.console.cursorMove(.{ .x = 0, .y = pos_y });
            self.drawLine(line);
          }
          while (true) { // draw parents
            if (pos_y == 0) return;
            line = line.getParent() orelse break;
            pos_y -= 1;
            prog.console.cursorMove(.{ .x = 0, .y = pos_y });
            self.drawParentLine(line);
          }
          Console.Output.print(ansi.reset);
          while (true) { // clear other upp lines
            if (pos_y == 0) return;
            pos_y -= 1;
            prog.console.cursorMove(.{ .x = 0, .y = pos_y });
            Console.Output.print(ansi.clear_line);
          } 
        }
        pub fn drawDownerLines   (self: *View) void {
          var pos_y: usize = self.offset.y;
          var line: *Line  = self.line;
          while (true) { // draw lines
            if (pos_y >= prog.console.size.y - 1) return;
            line = line.next orelse break;
            pos_y += 1;
            prog.console.cursorMove(.{ .x = 0, .y = pos_y });
            self.drawLine(line);
          }
          Console.Output.print(ansi.reset);
          while (true) { // clear other upp lines
            if (pos_y >= prog.console.size.y - 1) return;
            pos_y += 1;
            prog.console.cursorMove(.{ .x = 0, .y = pos_y });
            Console.Output.print(ansi.clear_line);
          } 
        }
        pub fn drawLine         (self: *View, line: *Line) void {
          
          // change color
          Console.Output.print(ansi.reset);
          if (line.child) |_| {Console.Output.print(ansi.bg_color.black2);}
          
          
          if (line.text.used == 0) {
            Console.Output.print(ansi.clear_line);
            return;
          }
          
          // draw left-to-right from first visible rune
          prog.console.cursorMoveToStartLine();
          const text = line.text.get();
          if (self.symbol < self.offset.x) { // unexpected
            self.offset.x    = 0;
            self.symbol      = 0;
            prog.need_redraw = true;
            return;
          }
          var pos: usize = self.symbol - self.offset.x; // first visible rune
          var offset_x: usize = 0;
          while (true) {
            if (pos >= text.len) break;
            if (offset_x >= prog.console.size.x - 1) break;
            prog.console.printRune(text[pos]) catch unreachable;
            pos += 1;
            offset_x += 1;
          }
          Console.Output.print(ansi.clear_to_end_line);
          
        }
        pub fn drawEditedLine   (self: *View) void {    // delete?
          
          // change color
          Console.Output.print(ansi.reset);
          var text_color: []const u8 = Prog.Theme.current; 
          if (self.line.child) |_| {Console.Output.print(ansi.bg_color.black2);}
          
          if (self.line.text.used == 0) {
            Console.Output.print(ansi.clear_line);
            return;
          }
          
          // draw left-to-right from first visible rune
          prog.console.cursorMoveToStartLine();
          const text = self.line.text.get();
          var pos: usize = self.symbol - self.offset.x;
          var offset_x: usize = 0;
          if (pos > 0) { // draw '<'
            Console.Output.print(ansi.color.magenta);
            prog.console.printRune('<') catch unreachable;
            pos += 1;
            offset_x += 1;
          }
          //{ left symbols
            Console.Output.print(text_color);
            while (true) {
              if (offset_x >= self.offset.x) break;
              if (offset_x >= prog.console.size.x - 1) break;
              if (pos >= text.len) break;
              prog.console.printRune(text[pos]) catch unreachable;
              pos += 1;
              offset_x += 1;
            }
          //}
          //{ current symbol. maybe inverse cursour?
            if (offset_x >= prog.console.size.x - 1) return;
            Console.Output.print(ansi.color.yellow);
            if (pos < text.len) {prog.console.printRune(text[pos]) catch unreachable;}
            pos += 1;
            offset_x += 1;
          //}
          //{ right symbols
            Console.Output.print(text_color);
            while (true) {
              if (offset_x >= prog.console.size.x - 1) break;
              if (pos >= text.len) break;
              prog.console.printRune(text[pos]) catch unreachable;
              pos += 1;
              offset_x += 1;
            }
          //}
          if (text.len > pos) { // draw '>'
            Console.Output.print(ansi.color.magenta);
            prog.console.printRune('>') catch unreachable;
          }
          else {
            Console.Output.print(ansi.clear_to_end_line);
          }
          
        } // drawEditedLine
        pub fn drawParentLine   (self: *View, parent: *Line) void {
          // change color
          Console.Output.print(ansi.reset);
          Console.Output.print(Theme.headers);
          
          // draw
          prog.console.cursorMoveToStartLine();
          const text = parent.text.get();
          var indent = parent.text.countIndent(1);
          var symbol: usize = indent;
          if (indent >= self.symbol - self.offset.x) {symbol = self.symbol - self.offset.x;}
          var offset_x: usize = 0;
          while (true) { 
            if (symbol   >= text.len) {
              Prog.Console.Output.print(ansi.clear_to_end_line);
              break;
            }
            if (offset_x >= prog.console.size.x) break; 
            prog.console.printRune(text[symbol]) catch unreachable;

            symbol += 1;
            offset_x += 1;
          }
        }
      // }
      // { navigation
        pub fn goToIn           (self: *View) void {
          //const line_indent  = self.line.text.countIndent(1);
          const child        = self.line.child orelse return;
          const child_indent = child.text.countIndent(1);
          self.goToSymbol(child_indent);
          //if (line_indent < child_indent) {self.offset.x = child_indent - line_indent;} 
          //else self.offset.x = 0;
          self.symbol        = child_indent;
          self.line          = child;
          if (prog.console.size.y > 6) {self.offset.y = 6;}
          else if (prog.console.size.y > 3) {self.offset.y = 3;}
          else if (prog.console.size.y > 1) {self.offset.y = 1;}
          else {self.offset.y = 0;}
          self.bakup();
          prog.need_redraw   = true;
          prog.need_clear    = true;
        }
        pub fn goToOut          (self: *View) void {
          if (self.line.getParent()) |parent| {
            const parent_indent = parent.text.countIndent(1);
            self.line     = parent;
            self.goToSymbol(parent_indent);
            self.offset.y = 6;
            //if (parent.getParent()) |grand_parent| {
              //const grand_parent_indent = grand_parent.text.countIndent(1);
              //if (grand_parent_indent <= parent_indent) {self.offset.x = parent_indent - grand_parent_indent;} 
              //else self.offset.x = self.symbol;
            //} 
            //else self.offset.x = self.symbol;
          } 
          else {
            self.goToRoot();
          }          
          self.bakup();
          prog.need_redraw = true;
          prog.need_clear  = true;
        }
        pub fn goToPrevLine     (self: *View) void {
          if (self.line.prev) |prev| {
            self.line = prev;
            prog.need_redraw = true;
          } 
          else {return;}
          if (self.offset.y > 5) {self.offset.y -= 1;}
          else {
            prog.need_clear  = true;
          }
          self.bakup();
        } // end fn
        pub fn goToNextLine     (self: *View) void {
          if (self.line.next) |next| {
            self.line = next;
            //{ correct offset_y:
              if (self.offset.y < prog.console.size.y - 1) self.offset.y += 1;
              
              // count downest_lines
              var count_to_downest_line: usize = 0;
              var line: *Line = self.line;
              while (count_to_downest_line < 5) {
                if (line.next) |down_next| {
                  count_to_downest_line += 1;
                  line = down_next;
                } 
                else {break;}
              }
              
              if (prog.console.size.y - self.offset.y < count_to_downest_line) {
                self.offset.y = prog.console.size.y - count_to_downest_line;
                prog.need_clear  = true;
              }
              prog.need_redraw = true;
              self.bakup();
            //}
          } 
          else {
            self.goToEndOfLine();
          }
        } // end fn
        pub fn goToPrevSymbol   (self: *View) void {
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
            prog.need_redraw  = true;
            return;
          }
          if (self.symbol > 0) self.symbol -= 1;
          if (self.symbol >= 10) {if (self.offset.x > 10) {self.offset.x -= 1;}} 
          else {if (self.offset.x > 0) self.offset.x -= 1;}
          prog.need_redraw  = true;
        }
        pub fn goToNextSymbol   (self: *View) void {
          const used = self.line.text.used;
          if (self.symbol >= used) {
            if (self.line.next) |_| {
              self.goToNextLine();
              self.goToStartOfLine();
            }
            return;
          }
          if (self.symbol < Line.Text.size - 1) self.symbol += 1;
          if (used - self.symbol >= 10) {
            if (self.offset.x < prog.console.size.x - 12) self.offset.x += 1;
            } else {
            if (self.offset.x < prog.console.size.x - 2) self.offset.x += 1;
          }
          prog.need_redraw  = true;
        }
        pub fn CtrlShiftLeft    (self: *View) void {
          const indent = self.line.text.countIndent(1);
          if (self.symbol > indent) self.goToSymbol(indent)
          else self.goToStartOfLine();
          prog.need_redraw = true;
        }
        pub fn CtrlShiftRight   (self: *View) void {
          const indent = self.line.text.countIndent(1);
          if (self.symbol < indent) self.goToSymbol(indent)
          else self.goToEndOfLine();
          prog.need_redraw = true;
        }
        pub fn goToStartOfLine  (self: *View) void {
          self.symbol = 0;
          self.offset.x = 0;
          prog.need_redraw  = true;
        }
        pub fn goToEndOfLine    (self: *View) void {
          self.symbol = self.line.text.used;
          if (self.symbol > prog.console.size.x - 2) {self.offset.x = prog.console.size.x - 2;}
          else {self.offset.x = self.symbol;}
          prog.need_redraw  = true;
        }
        pub fn goToSymbol       (self: *View, pos: usize) void {
          self.symbol = pos;
          if (self.symbol > prog.console.size.x - 2) {
            self.offset.x = prog.console.size.x - 2;
          } 
          else {self.offset.x = self.symbol;}
        }
        pub fn goToRoot         (self: *View) void {
          self.line = self.lines;
          self.offset.y = 5;
          self.goToStartOfLine();
          prog.need_clear  = true;
          prog.need_redraw = true;
          self.bakup();
        }
        pub fn goToFirstLine    (self: *View) void {
          while (self.line.prev) |_| self.goToPrevLine();
          self.goToStartOfLine();
          prog.need_clear  = true;
          prog.need_redraw = true;
          self.bakup();
        }
        pub fn goToLastLine     (self: *View) void {
          while (self.line.next) |_| self.goToNextLine();
          self.goToEndOfLine();
          prog.need_clear  = true;
          prog.need_redraw = true;
          self.bakup();
        }
        pub fn findNext         (self: *View) void {
          const text = self.line.text.get();
          var line   = self.line;
          if (line.text.find(text, self.symbol)) |pos|   { // goto pos and return
            self.line = line;
            self.goToSymbol(pos);
            return;
          }
          else { // iterate and find
            while(true) {
              // iterate
              if (line.child) |child| { // goto child
                line = child;
              } 
              else if (line.next)  |next|  { // goto next
                line = next;
              }
              else { // find parent with next
                var next: *Line = undefined;
                while (true) {
                  line = line.getParent() orelse return;
                  next = line.next        orelse continue;
                  break;
                }
                line = next;
              }
              // find
              if (line.text.find(text, 0)) |pos| { // goto pos and return
                self.line = line;
                self.goToSymbol(pos);
                return;
              }
            }
          }
          self.changeMode(.edit);
          prog.need_clear  = true;
          prog.need_redraw = true;
          self.bakup();
        }
        pub fn goToStartOfWord  (self: *View) void {
          if (self.symbol == 0) {return;}
          if (self.symbol > self.line.text.used) {self.goToSymbol(self.line.text.used);}
          const first_rune = self.line.text.buffer[self.symbol];
          if (first_rune == ' ') {
            self.goToPrevSymbol();
            while (true) {
              if (self.symbol == 0) {break;}
              const rune = self.line.text.buffer[self.symbol];
              if (rune != ' ') break;
              self.goToPrevSymbol();
            }
          }
          else {
            self.goToPrevSymbol();
            while(true) {
              if (self.symbol == 0) {break;}
              const next_symbol = self.line.text.buffer[self.symbol - 1];
              switch(next_symbol){
                ' ', '	', '\\', 
                '=', '+', '-', '/', '*', '^',
                '!', '@', '#', '$', '%', '&',
                '(', ')', '[', ']', '{', '}', 
                '"', '\'',
                ';', ':', '.', ','  
                => {break;},
                else => {},
              }
              self.goToPrevSymbol();
            }
          }
          prog.need_redraw = true;
        }
        pub fn goToEndOfWord    (self: *View) void {
          if (self.symbol >= self.line.text.used) {return;}
          const first_rune = self.line.text.buffer[self.symbol];
          if (first_rune == ' ') {
            while(true) {
              self.goToNextSymbol();
              if (self.symbol >= self.line.text.used) {break;}
              const rune = self.line.text.buffer[self.symbol];
              if (rune != ' ') break;
            }
          }
          else while(true) {
            self.goToNextSymbol();
            if (self.symbol >= self.line.text.used) {break;}
            const rune = self.line.text.buffer[self.symbol];
            switch(rune){
              ' ', '	', '\\', 
              '=', '+', '-', '/', '*', '^',
              '(', ')', '[', ']', '{', '}', 
              '!', '@', '#', '$', '%', '&',
              '"', '\'',
              ';', ':', '.', ','  
              => {break;},
              else => {},
            }
          }
          prog.need_redraw = true;
        }
        pub fn goToStartOfText  (self: *View) void {
          const indent = self.line.text.countIndent(1);
          self.goToSymbol(indent);
        }
        pub fn goToNextFlatLine (self: *View) void {
          self.line = self.line.flat_next orelse return;
        }
        pub fn goToPrevFlatLine (self: *View) void {
          self.line = self.line.flat_prev orelse return;
        }
      //}
      // { folding
        pub fn unFold            (self: *View) void {
          var current = self.lines;
          while (true) {
            if (current.child) |child| {
              current.child = null;
              child.parent = null;
              //{ insert range child..last into current and current.next
                if (current.next) |current_next| { // tie last_child <-> current_next
                  var last_child: *Line = child;
                  while (true) { // find last_child
                    if (last_child.next) |next| {
                      last_child = next;
                    } else break;
                  } // end while
                  last_child.next = current_next;
                  current_next.prev = last_child;
                } // end if
                //{ tie child <-> current
                  child.prev = current;
                  current.next = child;
                //}
              //} end insert into last and current.next
            } // end if current_line.child
            if (current.next)  |next| {
              current = next;
              continue;
            }
            break;
          } // end while
          prog.need_redraw = true;
          prog.need_clear  = true;
        } // end fn
        pub fn foldFromBrackets  (self: *View) void {
          self.unFold();
          var current: ?*Line = self.lines;
          while (current) |line| {
            var close_count = line.text.getRunesCount('}'); // **{
            var open_count = line.text.getRunesCount('{'); // **}
            if (open_count == close_count) {
              current = line.next;
            } 
            else if (open_count > close_count) {
              if (line.next) |next| {
                next.parent = line;
                line.child = next;
                line.next = null;
                next.prev = null;
              }
              current = line.child;
            } 
            else { // for close_count > open_count
              if (line.getParent()) |parent| {
                if (line.next) |next| {
                  next.prev = parent;
                }
                parent.next = line.next;
                current = line.next;
                line.next = null;
              } 
              else { // unexpected
                current = line.next;
                continue;
              }
            }
          }
          prog.need_redraw = true;
          prog.need_clear  = true;
          self.foldMode = .byBrackets;  
        }
      //}
      // { clipboard
        pub fn duplicate      (self: *View) void {
          const first      = self.line; 
          const copy_first = prog.buffer_lines.create() catch return;
          copy_first.text.set(first.text.get()) catch unreachable;
          self.line.pushNext(copy_first);
          if (first.child) |first_child| {
            var current         = first_child;
            var copy_current    = prog.buffer_lines.create() catch return;
            copy_current.text.set(current.text.get()) catch unreachable;
            copy_current.parent = copy_first;
            copy_first.child    = copy_current;
            copying: while (true) {
              if (current.child) |child| {
                var copy_child = prog.buffer_lines.create() catch return;
                copy_child.text.set(child.text.get()) catch unreachable;
                copy_child.parent  = copy_current;
                copy_current.child = copy_child;
                current       = child;
                copy_current  = copy_child;
              } 
              else if (current.next) |next| {
                var copy_next = prog.buffer_lines.create() catch return;
                copy_next.text.set(next.text.get()) catch unreachable;
                copy_next.prev    = copy_current;
                copy_current.next = copy_next;
                current       = next;
                copy_current  = copy_next;
              }
              else { // find parent with next
                var next: *Line = undefined;
                while (true) {
                  current     = current.getParent()      orelse break :copying;
                  if (current == first) break: copying;
                  copy_current = copy_current.getParent() orelse unreachable;
                  next        = current.next orelse continue;
                  break;
                }
                var copy_next     = prog.buffer_lines.create() catch return;
                copy_next.text.set(next.text.get()) catch unreachable;
                copy_next.prev    = copy_current;
                copy_current.next = copy_next;
                current           = next;
                copy_current      = copy_next;
              }
            }
          }
          self.line = copy_first;
          prog.need_redraw = true;
        }
        pub fn cut            (self: *View) void {
          if (self.line.parent) |parent| {
            parent.child = self.line.next;
          }
          var next_selected_line: *Line = undefined;
          // { select next selected line
            if (self.line.next) |next| {
              next_selected_line = next;
              } else if (self.line.prev) |prev| {
              next_selected_line = prev;
              } else if (self.line.parent) |parent| {
              next_selected_line = parent;
              } else {
              self.line.text.set("") catch unreachable;
              return;
            }
          // }
          if (self.lines == self.line) self.lines = next_selected_line;
          prog.buffer_lines.cut(self.line);
          self.line = next_selected_line;
          prog.need_clear  = true;
          prog.need_redraw = true;
        }
        pub fn pasteLine      (self: *View) void {
          if (prog.buffer_lines.cutted) |cutted| {
            prog.buffer_lines.cutted = cutted.next;
            cutted.next = null;
            self.line.pushPrev(cutted);
            if (self.lines == self.line) self.lines = cutted;
            self.offset.y += 1;
            self.goToPrevLine();
            self.indentToCutie();
          }
          prog.need_redraw = true;
        }
        pub fn externalCopy   (self: *View) !void {
          var file = File.fromOpen(prog.path_to_clipboard.getSantieled(), .toWrite) catch return;
          defer file.close() catch unreachable;
          if (prog.buffer_lines.cutted) |cutted| {
            // { working with lines
              var current: *Line = cutted;
              try file.write(current.text.get());
              copying: while (true) {
                if (current.child) |child| {
                  try file.write("\n");
                  try file.write(child.text.get());
                  current = child;
                } 
                else if (current.next) |next| {
                  try file.write("\n");
                  try file.write(next.text.get());
                  current = next;
                }
                else { // find parent with next
                  var next: *Line = undefined;
                  while (true) {
                    current     = current.getParent()      orelse break :copying;
                    next        = current.next orelse continue;
                    break;
                  }
                  try file.write("\n");
                  try file.write(next.text.get());
                  current = next;
                }
              }
            // }
            { // change status
              prog.need_redraw = false;
              prog.console.cursorMove(.{ .x = 0, .y = 0 });
              Console.Output.print(ansi.reset);
              Console.Output.print(ansi.color.blue2);
              prog.console.print("cuted text saved to ~/clipboard.tmp");
              Console.Output.print(ansi.clear_to_end_line);
              Console.Output.print(ansi.reset);
            }
          }
          else {
            // { working with lines
              const first = self.line;
              try file.write(first.text.get());
              if (first.child) |first_child| {
                var current: *Line = first_child;
                try file.write("\n");
                try file.write(current.text.get());
                copying: while (true) {
                  if (current.child) |child| {
                    try file.write("\n");
                    try file.write(child.text.get());
                    current = child;
                  } 
                  else if (current.next) |next| {
                    try file.write("\n");
                    try file.write(next.text.get());
                    current = next;
                  }
                  else { // find parent with next
                    var next: *Line = undefined;
                    while (true) {
                      current = current.getParent() orelse break :copying;
                      if (current == first) break: copying;
                      next = current.next orelse continue;
                      break;
                    }
                    try file.write("\n");
                    try file.write(next.text.get());
                    current = next;
                  }
                }
              }
            // }
            { // change status
              prog.need_redraw = false;
              prog.console.cursorMove(.{ .x = 0, .y = 0 });
              Console.Output.print(ansi.reset);
              Console.Output.print(ansi.color.blue2);
              prog.console.print("this block saved to ~/clipboard.tmp");
              Console.Output.print(ansi.clear_to_end_line);
              Console.Output.print(ansi.reset);
            }
          }
          prog.need_redraw = false;
          Console.Output.flush();
        }
        pub fn externalPaste  (self: *View) !void {
          const line = self.line;
          var mapable_file = MapableFile.fromRead(prog.allocator, prog.path_to_clipboard.get()) catch |e| {
            { // change status
              prog.console.cursorMove(.{ .x = 0, .y = 0 });
              Console.Output.print(ansi.reset);
              Console.Output.print(ansi.color.red2);
              prog.console.print("file ~/clipboard.tmp not reedable.");
              Console.Output.print(ansi.clear_to_end_line);
              Console.Output.print(ansi.reset);
            }
            return e;
          };
          defer prog.allocator.free(mapable_file.data.?);
          try self.addPrevLine();
          const slice = mapable_file.data.?;
          for (slice) |rune| { // parse lines
            switch(rune) {
              10, 13 => {try self.addNextLine();},
              else   => {try self.insertSymbol(rune);},
            }
          }
          self.line = line;
          prog.need_clear  = true;
          prog.need_redraw = true;
        }
      //}
      // { bakup
        pub fn bakup   (self: *View) void {
          self.bakup_line.text.set(self.line.text.get()) catch {};
        }
        pub fn restore (self: *View) void {
          self.line.text.set(self.bakup_line.text.get()) catch {};
          prog.need_redraw = true;
        }
      // }
      // { indent
        pub fn foldFromIndent    (self: *View, tabsize: usize) void {
          self.unFold();
          var last_indent = self.lines.text.countIndent(tabsize);
          var line: *Line = self.lines.next orelse return;
          while (true) {
            const prev = line.prev orelse unreachable;
            if (line.text.countNonIndent() == 0) {} // skip blank lines
            else { // change to child or parent
              const indent = line.text.countIndent(tabsize);
              if (indent != last_indent) {
                if (indent > last_indent) {
                  prev.child = line;
                  prev.next = null;
                  line.parent = line.prev;
                  line.prev = null;
                  } else if (indent < last_indent) {
                  var parent = line.getParent() orelse unreachable;
                  var line_parent = parent;
                  while (true) {
                    var parent_indent = parent.text.countIndent(tabsize);
                    if (parent_indent == indent) {
                      prev.next = null;
                      parent.next = line;
                      line.prev = parent;
                      break;
                      } else if (parent_indent > indent) {
                      parent = parent.getParent() orelse unreachable;
                      continue;
                      } else if (parent_indent < indent) {
                      if (parent == line_parent) break;
                      var last = parent.getLastChild() orelse unreachable;
                      prev.next = null;
                      last.next = line;
                      line.prev = last;
                    }
                  }
                }
                last_indent = indent;
              }
            }
            line = line.next orelse break;
          }
          prog.need_redraw = true;
          prog.need_clear  = true;
          self.foldMode    = .byIndent;  
        }
        pub fn indentToCutie     (self: *View) void {
          var current = self.line;
          current.changeIndentToCutie() catch {};
          var first   = current;
          if (first.child) |first_child| {
            current = first_child;
            traversal: while (true) {
              if (current.child)     |child| {
                current.changeIndentToCutie() catch {};
                current = child;
              }
              else if (current.next) |next|  {
                current.changeIndentToCutie() catch {};
                current = next;
              }
              else {
                if (self.foldMode == .byBrackets) {
                  const parent = current.getParent() orelse break :traversal;
                  const indent = parent.text.countIndent(1);
                  current.text.changeIndent(indent) catch {};
                }
                else {
                  current.changeIndentToCutie() catch {};
                }
                while (true) { // find parent with next
                  current = current.getParent() orelse break :traversal;
                  if (current == first) break :traversal;
                  if (current.next) |next| {
                    current = next; 
                    break;
                  }
                }
              }
            }
          }
          prog.need_redraw = true;
        }
        pub fn deleteIndent      (self: *View) void {
          var current = self.line;
          current.text.changeIndent(0) catch {};
          var first   = current;
          if (first.child) |first_child| {
            current = first_child;
            traversal: while (true) {
              if (current.child)     |child| {
                current.text.changeIndent(0) catch {};
                current = child;
              }
              else if (current.next) |next|  {
                current.text.changeIndent(0) catch {};
                current = next;
              }
              else {
                current.text.changeIndent(0) catch {};
                while (true) { // find parent with next
                  current = current.getParent() orelse break :traversal;
                  if (current == first) break :traversal;
                  if (current.next) |next| {
                    current = next; 
                    break;
                  }
                }
              }
            }
          }
          prog.need_redraw = true;
        }
      // }
      // { easy motion
        pub fn draw_horizontal_help_motion   (self: *View) void {
          var pos:  usize = 0;
          var rune: u8    = 0x61;
          Console.Output.print(ansi.color.magenta);
          while(true) {
            prog.console.cursorMove(.{ .x = pos, .y = self.offset.y });
            prog.console.printRune(rune) catch unreachable;
            if (rune >= 0x7A) break; rune += 1;
            if (pos >= prog.console.size.x - 3) break; pos  += 3;
          }
          self.cursorMoveToCurrent();
          Console.Output.flush();
        }
        pub fn draw_vertical_help_motion     (self: *View) void {
          var pos: usize = 0;
          Console.Output.print(ansi.color.magenta);
          while(true) {
            prog.console.cursorMove(.{ .x = self.offset.x, .y = pos });
            prog.console.printRune(0x61 + @truncate(u8, pos)) catch unreachable;
            if (pos >= 0x7A - 0x61) break;
            if (pos == prog.console.size.y - 1) break;
            pos += 1;
          }
          self.cursorMoveToCurrent();
          Console.Output.flush();
        }
        pub fn easyMotionHorizontal          (self: *View, key: u8) void {
          var pos = key - 0x61;
          self.goToSymbol(self.symbol - self.offset.x + pos * 3);
          self.changeMode(.edit);
          prog.need_redraw = true;
          prog.need_clear  = true;
        }
        pub fn easyMotionVertical            (self: *View, key: u8) void {
          var pos = key - 0x61;
          if (self.offset.y == pos) {}
          else if (self.offset.y > pos) {
            var i = self.offset.y - pos;
            while (i > 0) : (i -= 1) {
              self.goToPrevLine();
            }
          }
          else { // (self.offset.y < pos)
            var i = pos - self.offset.y;
            while (i > 0) : (i -= 1) {
              self.goToNextLine();
            }
          }
          self.changeMode(.edit);
          prog.need_redraw = true;
          prog.need_clear  = true;
        }
      // }
      pub fn drawRunes(self: *View) void {
        var maybe_rune = self.line.text.runes;
        Prog.Console.Output.print(ansi.color.red);
        while(maybe_rune) |rune| {       
          _ = rune;
          prog.console.cursorMove(.{.x = 0, .y = self.offset.y});
        }
        self.cursorMoveToCurrent();
      }
    // }
  }; // end view
  pub const CommandLine  = struct {
    text: [254]u8 = undefined,
    used: usize = 0,
  };
  pub const Debug        = struct {
    visible: bool = false,
    pub fn draw    (self: *Debug) void {
      if (self.visible == false) {return;}
      const debug_lines = 4;
      var buffer: [254]u8 = undefined;
      Console.Output.print(ansi.reset);
      Console.Output.print(ansi.color.blue2);
      Console.Output.print(ansi.cyrsor_style.hide); 
      defer {
        Console.Output.print(ansi.cyrsor_style.show);
        Console.Output.flush();
      }
      
      var print_offset: usize = prog.console.size.y - debug_lines;
      prog.console.cursorMove(.{ .x = 0, .y = print_offset });
      { // line
        const as_num         = prog.view.line.countNum();
        const sprintf_result = lib.c.sprintf(&buffer, "line = %d", as_num);
        const buffer_count   = @intCast(usize, sprintf_result);
        prog.console.print(buffer[0..buffer_count]);
        Console.Output.print(ansi.clear_to_end_line);
      }
      { // view.offset
        prog.console.cursorMoveToNextLine();
        const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, "view.offset .x = %d, .y = %d", prog.view.offset.x, prog.view.offset.y));
        prog.console.print(buffer[0..buffer_count]);
        Console.Output.print(ansi.clear_to_end_line);
      }
      { // symbol
        prog.console.cursorMoveToNextLine();
        const used = prog.view.line.text.used;
        var sprintf_result: c_int = 0;
        if (prog.view.symbol >= used) {
          sprintf_result = lib.c.sprintf(&buffer, "symbol = %d (null)", prog.view.symbol);
        } 
        else {
          sprintf_result = lib.c.sprintf(&buffer, "symbol = %d (%c)", prog.view.symbol, prog.view.line.text.get()[prog.view.symbol]);
        }
        const buffer_count = @intCast(usize, sprintf_result);
        prog.console.print(buffer[0..buffer_count]);
        Console.Output.print(ansi.clear_to_end_line);
      }
      { // input
        prog.console.cursorMoveToNextLine();
        var buffer_pos: usize = 0;
        var pos: usize = 0;
        while (pos < 8) {
          _ = lib.c.sprintf(&buffer[buffer_pos], "%02X", prog.console.input.debug_buffer[pos]);
          buffer_pos += 2;
          pos += 1;
        }
        prog.console.print(buffer[0..buffer_pos]);
        Console.Output.print(ansi.clear_to_end_line);
      }
    }
    pub fn toggle  (self: *Debug) void {
      self.visible = !self.visible;
      prog.need_redraw = true;
    }
  };
// }
pub var prog: *Prog = undefined;
// { fields
  // mem
  arena:             std.heap.ArenaAllocator,
  allocator:         std.mem.Allocator,
  
  // beffers
  buffer_lines:      BufferLines,
  buffer_runes:      BufferRunes,
  buffer_glyphs:     BufferGlyphs,
  
  working:           bool,
  console:           Console,
  debug:             Debug,
  need_clear:        bool,
  need_redraw:       bool,
  view:              View,
  path_to_clipboard: Line.Text,
  usage_line:        *Line,
// }
pub fn main () !void {
  Prog.Console.Output.print(" - - - - - - - - - - - - - - ");
  Prog.Console.Output.flush();
  
  const allocated    = lib.c.aligned_alloc(8, @sizeOf(Prog)) orelse return error.NeedMoreMemory;
  prog = @ptrCast(*Prog, @alignCast(8, allocated));
  defer lib.c.free(prog);
  
  defer Console.Output.print(ansi.reset);
  defer Console.Output.print(ansi.bg_color.zero);
  defer Console.Output.print("\r\n");
  
  try prog.init();
  defer (prog.deinit() catch {});
  try prog.run();
} // end fn main
// { methods
  pub fn init           (self: *Prog) !void {
    self.arena         = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    self.allocator     = self.arena.allocator();
    self.working       = true;
    self.need_clear    = true;
    self.need_redraw   = true;
    self.console       = .{};
    self.debug         = .{};
    try self.buffer_lines.init();
    { // load usage text
      const path = "ScalpiEditor_usage.txt";
      const text = @embedFile(path);
      self.view.init(path, text) catch return error.ViewNotInit;
      self.usage_line = self.view.lines;
    }
    self.updatePathToClipboard();
    //lib.print(ansi.mouse.grab);
  }
  pub fn deinit         (self: *Prog) !void {
    _ = self;
    Console.Output.print(ansi.mouse.release);
  }
  pub fn run            (self: *Prog) !void {
    try self.console.init(); defer {self.console.deInit();}
    if (std.os.argv.len > 1) { // work with arguments
      var   argument            = try lib.getTextFromArgument();
      const parsed_path         = ParsePath.fromText(argument) catch {
        const text = (
          \\  file name not parsed. 
          \\
          \\  Scalpi editor does not open multiple files in one time.
          \\  you can use [Ctrl] + [F2] to change tty.
          \\  or use tmux, byobu, GNU_Screen, dtach, abduco, mtm, or eny you want terminal multiplexor...
          \\  or if you use X or wayland just open multiple terminals and use it...
          \\
          \\
        );
        self.console.printInfo(text);
        return;
      };
      const file_name           = parsed_path.file_name.?.get();
      var   mapable_file        = MapableFile.fromRead(prog.allocator, file_name) catch {
        const text = ( 
          \\  File not exist or blocked by system.
          \\  ScalpiEditor does not create files itself.
          \\  You can create file with "touch" command:
          \\     touch file_name
          \\
          \\
        );
        self.console.printInfo(text);
        return;
      };
      defer mapable_file.deInit(prog.allocator);
      var   text: []const u8 = undefined;
      if    (mapable_file.data) |data| {text = data;}
      else  {text = "";}
      self.view.init(file_name, text) catch return error.ViewNotInit;
      if    (parsed_path.line) |line| {
        self.view.goToLineFromNumber(line);
      }
    }
    try self.mainLoop();
    self.console.cursorMoveToEnd();
  } // end fn initAndRun
  pub fn mainLoop       (self: *Prog) !void {
    while (true) {
      try self.console.updateSize();
      self.updateKeys();
      if (self.working == false) return;
      if (self.need_redraw == true) {
        self.need_redraw = false;
        self.view.draw();
        self.view.cursorMoveToCurrent();
      }
      if (self.debug.visible == true) {
        prog.debug.draw();
      }
      std.time.sleep(std.time.ns_per_ms * 10);
    }
  }
  pub fn stop           (self: *Prog) void {
    self.need_redraw = false;
    self.working = false;
  }
  pub fn updateKeys     (self: *Prog) void {
    self.console.input.updateUnreaded();
    while (self.console.input.grab()) |key| {
      self.onKey(key);
    }
  } // end fn updateKeys
  pub fn onMouse        (self: *Prog) void {
    const mode   = self.console.input.buffer[3];
    if (mode != ' ') return;
    
    var coor_x = self.console.input.buffer[4];
    if (coor_x < 33) {
      var buffer: [254]u8 = undefined;
      var count = @intCast(usize, lib.c.sprintf(&buffer, "x = %d", coor_x));
      Console.Output.print(ansi.color.yellow);
      Console.Output.print(buffer[0..count]);
      return;
    }
    coor_x -= 33;
    self.view.goToSymbol(self.view.symbol - self.view.offset.x + coor_x);
    
    var coor_y = self.console.input.buffer[5];
    if (coor_y < 35) {
      var buffer: [254]u8 = undefined;
      var count = @intCast(usize, lib.c.sprintf(&buffer, "x = %d", coor_x));
      Console.Output.print(ansi.color.yellow);
      Console.Output.print(buffer[0..count]);
      return;
    }
    coor_y -= 35;
    if (self.view.offset.y == coor_y) {}
    else if (self.view.offset.y > coor_y) {
      var i = self.view.offset.y - coor_y;
      while (i > 0) : (i -= 1) {
        self.view.goToPrevLine();
      }
    }
    else { // (self.view.offset.y < coor_y)
      var i = coor_y - self.view.offset.y;
      while (i > 0) : (i -= 1) {
        self.view.goToNextLine();
      }
    }
    
    prog.need_redraw = true;
  }
  pub fn onKey          (self: *Prog, cik: Console.Input.Key) void {
    switch (self.view.mode) {
      .edit    => {
        switch (cik) {
          .sequence  => |sequence| {
            switch (sequence) {
              .mouse            => {self.onMouse();},
              .f1               => {self.view.line = self.usage_line; self.need_clear = true; self.need_redraw = true;},
              .f1_rxvt          => {self.view.line = self.usage_line; self.need_clear = true; self.need_redraw = true;},
              .f1_tty           => {self.view.line = self.usage_line; self.need_clear = true; self.need_redraw = true;},
              .f2               => {self.debug.toggle();},
              .f2_rxvt          => {self.debug.toggle();},
              .f2_tty           => {self.debug.toggle();},
              .f3               => {self.view.goToPrevFlatLine();},
              .f4               => {self.view.goToNextFlatLine();},
              .f5               => {self.view.drawRunes();},
              .f9               => {self.view.changeMode(.normal);},
              .f10              => {self.stop();},
              
              .delete           => {self.view.deleteSymbol();},
              .shift_delete     => {self.view.clearLine();},
              
              .end              => {self.view.goToEndOfLine();},
              .home             => {self.view.goToStartOfLine();},
              
              .down             => {self.view.goToNextLine();},
              .up               => {self.view.goToPrevLine();},
              .left             => {self.view.goToPrevSymbol();},
              .right            => {self.view.goToNextSymbol();},
              .ctrl_shift_left  => {self.view.CtrlShiftLeft();},
              .ctrl_shift_right => {self.view.CtrlShiftRight();},
              .ctrl_left        => {self.view.goToStartOfWord();},
              .ctrl_left_rxvt   => {self.view.goToStartOfWord();},
              .ctrl_right       => {self.view.goToEndOfWord();},
              .ctrl_right_rxvt  => {self.view.goToEndOfWord();},
              .ctrl_up          => {self.view.goToFirstLine();},
              .ctrl_down        => {self.view.goToLastLine();},
              .alt_up           => {self.view.swapWithUpper();},
              .alt_down         => {self.view.swapWithBottom();},
              
              .alt_n            => {self.view.insertSymbol('\n') catch {};},
              .alt_r            => {self.view.insertSymbol('\r') catch {};},
              .alt_v            => {self.view.externalPaste() catch {};},
              .alt_m            => {self.view.markThisLine();},
              .alt_j            => {self.view.goToMarked();},
              .alt_p            => {self.view.deleteIndent();},
              
              else              => {self.need_redraw = true;},
            }
          },
          .byte      => |byte| {
            self.view.insertSymbol(byte) catch {};
            self.need_redraw = true;
          },
          .ascii_key => |key|  {
            switch (key) {
              .ctrl_q     => {self.stop();},
              .ctrl_s     => {self.view.save() catch {};},
              .ctrl_g     => {self.view.changeMode(.to_line);},
              .ctrl_f     => {self.view.changeMode(.to_find);},
              .ctrl_u     => {self.view.unFold();},
              .ctrl_r     => {self.view.foldFromIndent(1);},
              .ctrl_e     => {self.view.foldFromBrackets();},
              .ctrl_j     => {self.view.joinLines();},
              .enter      => {
                switch (self.console.input.is_paste) {
                  true   => {self.view.addNextLine() catch {};},
                  false  => {self.view.divide() catch {};},
                }
              },
              .back_space => {self.view.deletePrevSymbol();},
              .ctrl_bs    => {self.view.deletePrevSymbol();},
              .ctrl_p     => {self.view.indentToCutie();},
              .ctrl_d     => {self.view.duplicate();},
              .ctrl_x     => {self.view.cut();},
              .ctrl_c     => {self.view.externalCopy() catch {};},
              .ctrl_v     => {self.view.pasteLine();},
              .ctrl_t     => {self.view.insertSymbol('\t') catch {};},
              .escape     => {self.view.goToOut();},
              .tab        => {self.view.goToIn();},
              .ctrl_y     => {self.view.deleteWord();},
              .ctrl_l     => {self.view.changeMode(.easy_motion_horizontal);},
              .ctrl_k     => {self.view.changeMode(.easy_motion_vertical);},
              .ctrl_z     => {self.view.restore();},
              .ctrl_o     => {self.debug.toggle();},
              else        => {
                var byte = @enumToInt(key);
                self.view.insertSymbol(byte) catch {};
                self.need_redraw = true;
              },
            }
          },
        }
      },
      .to_find => {
        switch (cik) {
          .sequence  => |sequence| {
            switch (sequence) {
              .ctrl_left     => self.view.goToStartOfLine(),
              .ctrl_right    => self.view.goToEndOfLine(),
              .delete        => self.view.deleteSymbol(),
              .shift_delete  => {self.view.clearLine();},
              else        => {},
            }
          },
          .byte      => |byte| {
            self.view.insertSymbol(byte) catch {};
          },
          .ascii_key => |key|  {
            switch (key) {
              .escape     => self.view.changeMode(.edit),
              .ctrl_q     => self.stop(),
              .back_space => self.view.deletePrevSymbol(),
              .ctrl_bs    => self.view.deletePrevSymbol(),
              .ctrl_j     => self.view.findNext(),
              .enter      => self.view.findNext(),
              else        => {
                var byte = @enumToInt(key);
                self.view.insertSymbol(byte) catch {};
              },
            }
          },
        }
      },
      .to_line => {
        switch (cik) {
          .sequence  => |sequence| {
            switch (sequence) {
              .ctrl_left     => self.view.goToStartOfLine(),
              .ctrl_right    => self.view.goToEndOfLine(),
              .delete        => self.view.deleteSymbol(),
              .shift_delete  => {self.view.clearLine();},
              else           => {},
            }
          },
          .byte      => |byte| {
            self.view.insertSymbol(byte) catch {};
          },
          .ascii_key => |key|  {
            switch (key) {
              .escape     => self.view.changeMode(.edit),
              .ctrl_q     => self.stop(),
              .back_space => self.view.deletePrevSymbol(),
              .ctrl_bs    => self.view.deletePrevSymbol(),
              .ctrl_j     => self.view.goToLineFromInput(),
              .enter      => self.view.goToLineFromInput(),
              else        => {
                var byte = @enumToInt(key);
                self.view.insertSymbol(byte) catch {};
              },
            }
          },
        }
      },
      .history => {},
      .select  => {},
      .normal  => {
        switch (cik) {
          .sequence  => |sequence| {
            switch (sequence) {
              .delete       => self.view.deleteSymbol(),
              .shift_delete => {self.view.clearLine();},
              .end          => self.view.goToEndOfLine(),
              .home         => self.view.goToStartOfLine(),
              .down         => self.view.goToNextLine(),
              .up           => self.view.goToPrevLine(),
              .left         => self.view.goToPrevSymbol(),
              .right        => self.view.goToNextSymbol(),
              else          => {},
            }
          },
          .byte      => |_| {},
          .ascii_key => |key|  {
            switch (key) {
              .code_q     => {self.stop();},
              .code_s     => {self.view.save() catch {};},
              .code_i     => {self.view.changeMode(.edit);},
              .code_g     => {self.view.changeMode(.to_line);},
              .code_u     => {self.view.unFold();},
              .code_y     => {self.view.foldFromIndent(4);},
              .code_r     => {self.view.foldFromIndent(1);},
              .code_e     => {self.view.foldFromBrackets();},
              .code_j     => {self.view.divide() catch {};},
              .enter      => {self.view.divide() catch {};},
              .back_space => {self.view.deletePrevSymbol();},
              .ctrl_bs    => {self.view.deletePrevSymbol();},
              .code_p     => {self.view.line.changeIndentToCutie() catch {};},
              .code_d     => {self.view.duplicate();},
              .code_x     => {self.view.cut();},
              .code_c     => {self.view.externalCopy() catch {};},
              .code_v     => {self.view.pasteLine();},
              .code_t     => {self.view.insertSymbol('\t') catch {};},
              .escape     => {self.view.goToOut();},
              .tab        => {self.view.goToIn();},
              .code_l     => {self.view.goToLastLine();},
              else        => {},
            }
          },
        }
      },
      .easy_motion_vertical   => {
        switch (cik) {
          .sequence  => |_| {},
          .byte      => |_| {},
          .ascii_key => |key|  {
            const num = @enumToInt(key);
            if (num >= 0x61 and num <= 0x7A) {self.view.easyMotionVertical(num);}
            else switch (key) {
              .ctrl_l       => {self.view.changeMode(.easy_motion_horizontal);},
              .ctrl_k       => {self.view.changeMode(.easy_motion_vertical);},
              .escape       => {self.view.changeMode(.edit);},
              .ctrl_q       => {self.stop();},
              else          => {},
            }
          },
        }
      },
      .easy_motion_horizontal => {
        switch (cik) {
          .sequence  => |_| {},
          .byte      => |_| {},
          .ascii_key => |key|  {
            const num = @enumToInt(key);
            if (num >= 0x61 and num <= 0x7A) {self.view.easyMotionHorizontal(num);}
            else switch (key) {
              .ctrl_l       => {self.view.changeMode(.easy_motion_horizontal);},
              .ctrl_k       => {self.view.changeMode(.easy_motion_vertical);},
              .escape       => {self.view.changeMode(.edit);},
              .ctrl_q       => {self.stop();},
              else          => {},
            }
          },
        }
      },
    }
  }
  pub fn updatePathToClipboard  (self: *Prog) void {
    var len_c_int = lib.c.sprintf(&self.path_to_clipboard.buffer, "%s/clipboard.tmp", lib.c.getenv("HOME"));
    var len = @intCast(usize, len_c_int);
    self.path_to_clipboard.used = len;
  }
// }