// { import
  const Self  = @This();
  const std   = @import("std");
  const Prog  = @import("root");
  const Line  = @import("Line.zig");
  const Rune  = @import("Rune.zig");
  const prog  = Prog.prog;
  const lib   = Prog.lib;
  const ansi  = Prog.ansi;
// }
// { fields
  text:      ?*Rune      = null,
  
  maybe_next:      ?*Self      = null,
  maybe_prev:      ?*Self      = null,
  maybe_parent:    ?*Self      = null,
  maybe_child:     ?*Self      = null,
  
  maybe_flat_next: ?*Self      = null,
  maybe_flat_prev: ?*Self      = null,
  
  folded:    bool        = false,  
// } 
// { methods
// }