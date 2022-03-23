// { defines
  const Console    = @This();
  const std        = @import("std");
  const asBytes    = std.mem.asBytes;
  const Prog       = @import("root");
  const ansi       = Prog.ansi;
  const lib        = Prog.lib;
  const c          = lib.c;
  const Coor2u     = lib.Coor2u;
  const cmp        = lib.cmp;
// }
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
    lib.print(buffer[0..buffer_count]);
    self.pos.x -= pos;
  }
  pub fn shiftRight  (self: *Cursor, pos: usize) void {
    var buffer: [254]u8 = undefined;
    const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dC", pos)); // ^ESC[6C
    lib.print(buffer[0..buffer_count]);
    self.pos.x += pos;
  }
  pub fn shiftUp     (self: *Cursor, pos: usize) void {
    var buffer: [254]u8 = undefined;
    const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dA", pos));
    lib.print(buffer[0..buffer_count]);
    self.pos.y -= pos;
  }
  pub fn shiftDown   (self: *Cursor, pos: usize) void {
    var buffer: [254]u8 = undefined;
    const buffer_count: usize = @intCast(usize, lib.c.sprintf(&buffer, ansi.control ++ "%dB", pos));
    lib.print(buffer[0..buffer_count]);
    self.pos.y += pos;
  }
};
pub const Input  = struct {
  pub const KeyTag      = enum {
    sequence,
    byte,
    ascii_key,
  };
  pub const Key         = union(KeyTag) {
    sequence:   ansi.Sequence,
    byte:       u8,
    ascii_key:  ansi.AsciiKey,
  }; 
  ungrabed:     usize   = 0,
  unreaded:     usize   = 0,
  buffer:       [8]u8   = .{0}**8,
  debug_buffer: [8]u8   = .{0}**8,
  is_paste:     bool    = false,
  pub fn updateUnreaded  (self: *Input) void  {
    var bytesWaiting: c_int = undefined;
    _ = lib.c.ioctl(0, lib.c.FIONREAD, &bytesWaiting);
    var count = @intCast(usize, bytesWaiting);
    self.unreaded = count;
    if (self.unreaded > 8) {self.is_paste = true;}
    else {self.is_paste = false;}
  }
  pub fn grab            (self: *Input) ?Key  {
    while (self.ungrabed <  8 and self.unreaded >  0) {
      _ = lib.c.read(0, &self.buffer[self.ungrabed], 1);
      self.ungrabed += 1;
      self.unreaded -= 1;
    }
    if (self.ungrabed == 0) return null;
    if (ansi.Sequence.Parser.fromDo(self.buffer[0..self.ungrabed])) |parser| {
      self.shift(parser.used);
      const key: Key = .{.sequence = parser.sequence};
      return key;
    }
    else if (self.buffer[0] > 127) {
      const byte = self.buffer[0];
      self.shift(1);
      const key: Key = .{.byte = byte};
      return key;
    }
    else { // return ascii
      const ascii_key = @intToEnum(ansi.AsciiKey, self.buffer[0]);
      self.shift(1);
      const key: Key = .{.ascii_key = ascii_key};
      return key;
    }
  }
  pub fn shift           (self: *Input, val: usize) void {
    std.mem.copy(u8, self.debug_buffer[0..],     self.debug_buffer[val..]);
    std.mem.copy(u8, self.debug_buffer[8-val..], self.buffer      [0..val]);
    std.mem.copy(u8, self.buffer      [0..],     self.buffer      [val..]);
    self.ungrabed -= val;
  }
};
size:        Coor2u            = .{ .x = 0, .y = 0 },
cursor:      Cursor            = .{},
last_flags:  c.struct_termios  = undefined,
input:       Input             = .{},
// { methods
  pub fn init                 (self: *Console) void {
    lib.print(ansi.reset);
    var flags: c.struct_termios = undefined;
    _ = c.tcgetattr(0, &flags);
    _ = c.tcgetattr(0, &self.last_flags); // save for restore
    { // configure flags
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
      
      
      // disable all converts
      lib.toggleU32(oflag, c.OPOST,   .disable); // do not convert any
      lib.toggleU32(iflag, c.INLCR,   .disable); // do not convert NL to CR
      lib.toggleU32(oflag, c.ONLCR,   .disable); // --//--
      lib.toggleU32(iflag, c.ICRNL,   .disable); // do not convert CR to NL
      lib.toggleU32(oflag, c.OCRNL,   .disable); // --//--
      lib.toggleU32(iflag, c.XCASE,   .disable); // do not convert register
      lib.toggleU32(iflag, c.IUCLC,   .disable); // --//--
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
      
      
      for (flags.c_cc) |*conf| conf.* = 0; // clear c_cc
      flags.c_cc[c.VTIME] = 1;
      flags.c_cc[c.VMIN]  = 0;
    }
    _ = c.tcsetattr(0, c.TCSANOW, &flags);
    self.updateSize();
    self.initBlankLines();
    lib.print(ansi.cyrsor_style.blinking_I_beam); // change cursour type
    lib.print(ansi.mouse.enable);
    self.clear();
    self.cursorMove(.{.x = 0, .y = 0});
  }
  pub fn deInit               (self: *Console) void {
    _ = c.tcsetattr(0,  c.TCSANOW, &self.last_flags); // restore buffer settings
    lib.print(ansi.mouse.disable);
  }
  pub fn updateSize           (self: *Console) void {
    var w: c.winsize = undefined;
    _ = c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &w);
    self.size.x = w.ws_col - 1;
    self.size.y = w.ws_row - 3;
  }
  pub fn printRune            (self: *Console, rune: u8) void {
    if (self.cursor.pos.x >= self.size.x) unreachable;
    if (self.cursor.pos.y >= self.size.y) unreachable;
    switch (rune) {
      10, 13 => {
        lib.print(ansi.bg_color.red2);
        lib.printRune(' ');
        lib.print(ansi.reset);
      },
      0...9, 
      11...12,
      14...31,
      127...255
      =>  {
        lib.print(ansi.bg_color.black2);
        lib.printRune(' ');
        lib.print(ansi.reset);
      },
      else => {
        lib.printRune(rune);
      },
    }
    //~ lib.printRune(rune);
    self.cursor.pos.x += 1;
  }
  pub fn print                (self: *Console, text: []const u8) void {
    if (text.len > self.size.x) {
      for (text[0..self.size.x - 1]) |rune| {
        self.printRune(rune);
      }
      lib.print(ansi.color.red);
      self.printRune('>');
      lib.print(ansi.reset);
    } 
    else {
      for (text) |rune| {
        self.printRune(rune);
      }
    }
  }
  pub fn cursorMoveToEnd      (self: *Console) void {
    self.cursor.move(.{.x = 0, .y = self.size.y});
  }
  pub fn cursorMove           (self: *Console, pos: Coor2u) void {
    if (pos.x > self.size.x) unreachable;
    if (pos.y > self.size.y) unreachable;
    self.cursor.move(pos);
  }
  pub fn cursorMoveToNextLine (self: *Console) void {
    self.cursor.move(.{.x = 0, .y = self.cursor.pos.y + 1});
    if (self.cursor.pos.x > self.size.x) unreachable;
    if (self.cursor.pos.y > self.size.y) unreachable;
  }
  pub fn clear                (self: *Console) void {
    lib.print(ansi.reset);
    lib.print(ansi.cyrsor_style.hide); defer {lib.print(ansi.cyrsor_style.show);}
    var pos_y: usize = 0; 
    while (pos_y < self.size.y) {
      self.cursorMove(.{.x = 0, .y = pos_y});
      self.fillSpacesToEndLine();
      pos_y += 1;
    } // end while
  } // end fn clear
  pub fn initBlankLines       (self: *Console) void {
    self.cursorMove(.{.x = 0, .y = 0});
    var pos_y: usize = 0; 
    while (pos_y < self.size.y) {
      lib.printRune('\n');
      pos_y += 1;
      self.cursor.pos.y += 1;
    } // end while
  } // end fn clear
  pub fn fillSpacesToEndLine  (self: *Console) void {
    while (self.cursor.pos.x < self.size.x) {
      lib.printRune(' ');
      self.cursor.pos.x += 1;
    }
  }
  pub fn printLine            (self: *Console, text: []const u8, pos_y: usize) void {
    self.cursorMove(.{.x = 0, .y = pos_y});
    self.print(text);
    self.fillSpacesToEndLine();
  } 
  pub fn printInfo            (self: *Console, text: []const u8) void {
    for (text) |rune| {
      switch(rune) {
        10, 13 => self.cursorMoveToNextLine(),
        else   => self.printRune(rune)
      }
    }
  }
// }