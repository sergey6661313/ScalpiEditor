// { import
  const Self  = @This();
  const std   = @import("std");
  const Prog  = @import("root");
  const Line  = @import("Line.zig");
  const Text  = @import("Text.zig");
  const prog  = Prog.prog;
  const lib   = Prog.lib;
  const ansi  = Prog.ansi;
  const Rune  = @import("Rune.zig");
// }
// { fields
  text:    ?*Text      = null,
  next:    ?*Self      = null,
  prev:    ?*Self      = null,
  parent:  ?*Self      = null,
  child:   ?*Self      = null,
  num:     ?usize      = null,
  folded:  bool        = false,  
// } 
// { methods
// }