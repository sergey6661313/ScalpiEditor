const AllocatedFileData = @This();

// depencies
const File          = @import("File/src/File.zig");
const Allocated     = @import("Allocated/src/Allocated.zig");

pub fn fromName (name: [*:0]const u8) !Allocated {
  var file = File.fromOpen(name, .toRead) catch return error.FileNotOpened;
  defer file.close() catch unreachable;
  const size      = try file.getSize();
  const allocated = try Allocated.fromSize(size); 
  if (allocated.slice) |buffer| {
    try file.loadTo(buffer);
    return allocated;
  }
  else return error.MemoryNotAllocated;
}