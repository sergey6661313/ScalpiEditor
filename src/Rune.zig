const Self    = @This();
const Glyph   = @import("Glyph.zig");

glyph:       ?*Glyph = null,
color:       ?[]u8   = null,
tree_child:  ?*Self  = null,
tree_parent: ?*Self  = null,
tree_prev:   ?*Self  = null,
tree_next:   ?*Self  = null,
flat_prev:   ?*Self  = null,
flat_next:   ?*Self  = null,
