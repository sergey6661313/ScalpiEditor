const Allocated = @This();
pub const c = @cImport({
@cInclude("stdlib.h");
});
slice: ?[]u8 = null,
pub fn fromSize  (size: usize)      !Allocated {
var self: Allocated = .{};
if (c.malloc(size)) |ptr| {
self.slice = @ptrCast([*]u8, ptr)[0..size];
return self;
}
else return error.MemoryNotAllocated;
}
pub fn deInit    (self: *Allocated) !void {
if (self.slice) |slice| {
self.slice = null;
_ = c.free(slice.ptr);
}
else return error.MemoryNotAllocated;
}
