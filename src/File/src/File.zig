const File  = @This();
pub const c = @cImport({
  @cInclude("stdio.h");
});
pub const Method = enum {
  toRead,
  toWrite
};
handle: ?*c.struct__IO_FILE = null,
// { methods
  pub fn fromOpen  (name: [*:0]const u8, method: Method) !File {
    var file: File = .{};
    try file.open(name, method);
    return file;
  }
  pub fn open      (self: *File, name: [*:0]const u8, method: Method) !void {
    switch (method) {
      .toRead  => {
        self.handle = c.fopen(name, "rb") orelse return error.FileNotReadable;
      },
      .toWrite => {
        self.handle = c.fopen(name, "wb") orelse return error.FileNotWritable;
      },
    }
  }
  pub fn close     (self: *File) !void {
    if (self.handle) |handle| {
      var f_close_result = c.fclose(handle);
      if (f_close_result != 0) return error.Unexpected;
    }
    else return error.FileNotOpened;
  }
  pub fn getSize   (self: *File) !usize {
    if (self.handle) |handle| {
      const current_pos = c.ftell(handle);
      if (current_pos < 0) return error.UnexpectedCurrentPos;
      _ = c.fseek(handle, 0, c.SEEK_END);
      const size = c.ftell(self.handle);
      if (size < 0) return error.UnexpectedResult;
      return @intCast(usize, size);
    }
    else return error.FileNotOpened;
  }
  pub fn loadTo    (self: *File, buffer: []u8) !void {
    if (self.handle) |handle| {
      _ = c.fseek(handle, 0, c.SEEK_SET);
      const freadResult = c.fread(buffer.ptr, 1, buffer.len, handle);
      if (freadResult != buffer.len) return error.UnexpectedResult;
    }
    else return error.FileNotOpened;
  }
  pub fn write     (self: *File, data: []const u8) !void {
    if (self.handle) |handle| {
      _ = c.fwrite(data.ptr, 1, data.len, handle);
    } 
    else return error.FileNotOpened;
  }
//}