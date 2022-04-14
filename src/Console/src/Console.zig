// { import
  const Self       = @This();
  const std        = @import("std");
  const asBytes    = std.mem.asBytes;
  const Prog       = @import("root");
  const ansi       = Prog.ansi;
  const lib        = Prog.lib;
  const c          = lib.c;
  const Coor2u     = lib.Coor2u;
  const cmp        = lib.cmp;
// }
// { defines
  pub const Cursor = struct {
    pos: Coor2u = .{},
    pub fn init        (pos: Coor2u) Cursor {
      return .{
        .pos = pos
      };
    }
    pub fn move        (self: *Cursor, new_pos: Coor2u) void {
      move_from_x: {
        if (new_pos.x == self.pos.x) break :move_from_x;
        if (new_pos.x > self.pos.x) {
          self.shiftRight(new_pos.x - self.pos.x);
          } else {
          self.shiftLeft(self.pos.x - new_pos.x);
        }
      }
      move_from_y: {
        if (new_pos.y == self.pos.y) break :move_from_y; 
        if (new_pos.y > self.pos.y) {
          self.shiftDown(new_pos.y - self.pos.y);
          } else {
          self.shiftUp(self.pos.y - new_pos.y);
        }
      }
    }
    pub fn shiftLeft   (self: *Cursor, pos: usize) void {
      var buffer: [254]u8 = undefined;
      const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dD", pos));
      Output.print(buffer[0..buffer_count]);
      self.pos.x -= pos;
    }
    pub fn shiftRight  (self: *Cursor, pos: usize) void {
      var buffer: [254]u8 = undefined;
      const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dC", pos)); // ^ESC[6C
      Output.print(buffer[0..buffer_count]);
      self.pos.x += pos;
    }
    pub fn shiftUp     (self: *Cursor, pos: usize) void {
      var buffer: [254]u8 = undefined;
      const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dA", pos));
      Output.print(buffer[0..buffer_count]);
      self.pos.y -= pos;
    }
    pub fn shiftDown   (self: *Cursor, pos: usize) void {
      var buffer: [254]u8 = undefined;
      const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dB", pos));
      Output.print(buffer[0..buffer_count]);
      self.pos.y += pos;
    }
  };
  pub const Output = @import("Output.zig");
  pub const Input  = @import("Input.zig");
// }
size:        Coor2u            = .{ .x = 0, .y = 0 },
cursor:      Cursor            = .{},
last_flags:  c.struct_termios  = undefined,
input:       Input             = .{},
color:       ?[]const u8       = null,
// { methods
  pub fn init                 (self: *Self) !void {
    Output.print(ansi.reset);
    _ = c.tcgetattr(0, &self.last_flags); // save for restore
    
    { // configure flags
      var flags: c.struct_termios = undefined;
      _ = c.tcgetattr(0, &flags); // copy current
      
      const cflag = &flags.c_cflag;
      const iflag = &flags.c_iflag;
      const lflag = &flags.c_lflag;
      const oflag = &flags.c_oflag;
      
      // use 8 bit
      lib.toggleU32(cflag, c.CS8,    .enable);  // use 8 bit
      lib.toggleU32(iflag, c.ISTRIP, .disable); // do not strip
      lib.toggleU32(cflag, c.CSTOPB, .disable); // do not use two stops bits 
      
      // non canonical
      lib.toggleU32(lflag, c.ICANON, .disable); // no wait '\n'
      
      // no auto CR
      lib.toggleU32(oflag, c.ONOCR,  .disable); // on start line
      lib.toggleU32(oflag, c.ONLRET, .disable); // on end line
      
      // disable all converts for input
      lib.toggleU32(iflag, c.INLCR,   .disable); // do not convert NL to CR
      lib.toggleU32(iflag, c.ICRNL,   .disable); // do not convert CR to NL
      lib.toggleU32(iflag, c.XCASE,   .disable); // do not convert register to UP
      lib.toggleU32(iflag, c.IUCLC,   .disable); // do not convert register to down
      
      // disable all converts for output
      lib.toggleU32(oflag, c.OPOST,   .disable); // 
      lib.toggleU32(oflag, c.ONLCR,   .disable); // NL to CR
      lib.toggleU32(oflag, c.OCRNL,   .disable); // CR to NL
      lib.toggleU32(oflag, c.OLCUC,   .disable); // --//--
      lib.toggleU32(oflag, c.XTABS,   .disable); // do not convert tab
      lib.toggleU32(oflag, c.TAB3,    .disable); // do not convert tab
      
      // disable flow control
      lib.toggleU32(iflag, c.IGNBRK,  .enable);  // ignore break control
      lib.toggleU32(iflag, c.BRKINT,  .disable); // do not delete all data after break control
      lib.toggleU32(iflag, c.IXON,    .disable); // disable react to Ctrl+S Ctlr+Q
      lib.toggleU32(lflag, c.ISIG,    .disable); // disable react to Ctrl+C
      
      // ignore checking
      lib.toggleU32(iflag, c.IGNPAR,  .enable);  // ignore framing or parity errors
      lib.toggleU32(cflag, c.PARENB,  .disable); // parity check
      lib.toggleU32(cflag, c.PARODD,  .disable); // parity check
      
      
      // disable all echo
      lib.toggleU32(lflag, c.ECHO,    .disable); // no print pressed keys
      lib.toggleU32(lflag, c.ECHOE,   .disable); // no mashing
      lib.toggleU32(lflag, c.ECHOK,   .disable); // no print 
      lib.toggleU32(lflag, c.ECHOKE,  .disable); // no print NL after BS
      lib.toggleU32(lflag, c.ECHONL,  .disable); // no print NL
      lib.toggleU32(lflag, c.ECHOPRT, .disable); // no print BS (BS SP BS)
      lib.toggleU32(lflag, c.IEXTEN,  .disable); // no any special funcs
      
      // disable bel
      lib.toggleU32(iflag, c.IMAXBEL,  .disable); // no bel
      
      // deleted symbol: enable for del else nul
      lib.toggleU32(oflag, c.OFDEL,   .disable); // use null for deleted symbol
      
      for (flags.c_cc) |*conf| conf.* = 0; // clear c_cc
      flags.c_cc[c.VTIME] = 1;
      flags.c_cc[c.VMIN]  = 0;
      
      _ = c.tcsetattr(0, c.TCSANOW, &flags); // apply
    }
    
    try self.updateSize();
    self.initBlankLines();
    Output.print(ansi.cyrsor_style.blinking_I_beam); // change cursour type
    self.clear();
    self.cursorMove(.{.x = 0, .y = 0});
  }
  pub fn deInit               (self: *Self) void {
    _ = c.tcsetattr(0,  c.TCSANOW, &self.last_flags); // restore buffer settings
  }
  pub fn updateSize           (self: *Self) !void {
    var w: c.winsize = undefined;
    _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
    if (w.ws_col >= 4) {self.size.x = w.ws_col - 3;}
    else return error.ConsoleSizeXIsTooSmall;
    if (w.ws_col >= 4) {self.size.y = w.ws_row - 3;}
    else if (w.ws_col >= 1) {self.size.y = 1;}
    else return error.ConsoleSizeYIsTooSmall;
  }
  pub fn changeColor          (self: *Self, color: []const u8) void {
    Output.print(color);
    self.color = color;
  }
  pub fn initBlankLines       (self: *Self) void {
    self.cursorMove(.{.x = 0, .y = 0});
    var pos_y: usize = 0; 
    while (pos_y < self.size.y) {
      Output.printRune('\n');
      pos_y += 1;
      self.cursor.pos.y += 1;
    } // end while
  } // end fn clear
  
  // cursor
  pub fn cursorMoveToEnd      (self: *Self) void {
    self.cursor.move(.{.x = 0, .y = self.size.y});
  }
  pub fn cursorMoveToStartLine(self: *Self) void {
    self.cursor.move(.{.x = 0, .y = self.cursor.pos.y});
  }
  pub fn cursorMove           (self: *Self, pos: Coor2u) void {
    if (pos.x > self.size.x) unreachable;
    if (pos.y > self.size.y) unreachable;
    self.cursor.move(pos);
  }
  pub fn cursorMoveToNextLine (self: *Self) void {
    self.cursor.move(.{.x = 0, .y = self.cursor.pos.y + 1});
    if (self.cursor.pos.x > self.size.x) unreachable;
    if (self.cursor.pos.y > self.size.y) unreachable;
  }
  
  // prints
  pub fn print                (self: *Self, text: []const u8) void {
    if (text.len > self.size.x) {
      for (text[0..self.size.x - 1]) |rune| {
        self.printRune(rune) catch unreachable;
      }
      Output.print(ansi.color.red);
      self.printRune('>') catch unreachable;
      Output.print(ansi.reset);
    } 
    else {
      for (text) |rune| {
        self.printRune(rune) catch unreachable;
      }
    }
  }
  pub fn printLine            (self: *Self, text: []const u8, pos_y: usize) void {
    self.cursorMove(.{.x = 0, .y = pos_y});
    self.print(text);
    Output.print(ansi.clear_to_end_line);
  } 
  pub fn printRune            (self: *Self, rune: u8) !void {
    if (self.cursor.pos.x >= self.size.x) return error.CursorOverflow;
    if (self.cursor.pos.y >= self.size.y) return error.CursorOverflow;
    switch (rune) {
      10, 13 => {
        const last_color = self.color;
        self.changeColor(ansi.bg_color.blue);
        Output.printRune(' ');
        if (last_color) |color| self.changeColor(color);
      },
      0...9, 
      11...12,
      14...31
      => {
        Output.print(ansi.reset);
        const last_color = self.color;
        self.changeColor(ansi.bg_color.yellow);
        Output.printRune(' ');
        if (last_color) |color| self.changeColor(color);
      },
      127...255
      =>  {
        Output.print(ansi.reset);
        const last_color = self.color;
        self.changeColor(ansi.bg_color.green);
        Output.printRune(' ');
        if (last_color) |color| self.changeColor(color);
      },
      else => {
        Output.printRune(rune);
      },
    }
    self.cursor.pos.x += 1;
  }
  pub fn printInfo            (self: *Self, text: []const u8) void {
    for (text) |rune| {
      switch(rune) {
        10, 13 => {self.cursorMoveToNextLine();},
        else   => {self.printRune(rune) catch unreachable;}
      }
    }
  }
  pub fn clear                (self: *Self) void {
    Output.print(ansi.cyrsor_style.hide); defer {Output.print(ansi.cyrsor_style.show);}
    var pos_y: usize = 0; 
    while (pos_y < self.size.y) {
      self.cursorMove(.{.x = 0, .y = pos_y});
      Output.clearLine();
      pos_y += 1;
    } // end while
  } // end fn clear
// }