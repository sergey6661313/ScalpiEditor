const Self    = @This();
const Glyph   = @import("Glyph.zig");

maybe_glyph:  ?*Glyph = null,
maybe_prev:   ?*Self  = null,
maybe_next:   ?*Self  = null,