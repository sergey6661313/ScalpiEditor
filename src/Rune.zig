const         Self    = @This();
used:         usize   = 0,
buffer:       [16]u8  = undefined,
maybe_prev:   ?*Self  = null,
maybe_next:   ?*Self  = null,