// { import
  const Self  = @This();
  const std   = @import("std");
  const Prog  = @import("root");
  const Rune  = @import("Rune.zig");
  const Line  = @import("Line.zig");
  const prog  = Prog.prog;
  const lib   = Prog.lib;
  const ansi  = Prog.ansi;
// }
// { fields
  text:      ?*Rune      = null,
  
  next:      ?*Self  = null,
  prev:      ?*Self  = null,
  parent:    ?*Self  = null,
  child:     ?*Self  = null,
  
  flat_next: ?*Self  = null,
  flat_prev: ?*Self  = null,
  
  folded:    bool        = false,  
// } 
// { methods
// }