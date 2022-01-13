//{ defines
    const     Line    = @This();
    const     std     = @import("std");
    pub const size    = 254;
    const Prog = @import("root");
    const prog = &Prog.prog;
    
//}
//{ fields
    text:   [size]u8  = undefined,
    used:   usize     = 0,
    next:   ?*Line    = null,
    prev:   ?*Line    = null,
    parent: ?*Line    = null,
    child:  ?*Line    = null,
//}
//{ methods
    pub fn init     (self: *Line) !void {
        self.* = .{};
    }
    pub fn getText  (self: *Line) []u8 {
        return self.text[0 .. self.used];
    }
    pub fn setText  (self: *Line, text: []const u8) !void {
        if (text.len > size) return error.TextIsBiggerOfBuffer;
        std.mem.copy(u8, self.text[0..], text);
        self.used = text.len;
    }
    pub fn insert   (self: *Line, pos: usize, rune: u8) !void {
        if (self.used >  size) unreachable;
        if (self.used == size) return error.LineIsFull;
        if (pos > size - 1)    unreachable;
        if (pos > self.used)   return error.UnexpectedPos;
        if (pos < self.used)   { // shiftSymbolsToRight
            const from = self.text[pos      ..  self.used    ];
            const dest = self.text[pos + 1  ..  self.used + 1];
            std.mem.copyBackwards(u8, dest, from);
        }
        self.text[pos] = rune;
        self.used += 1;
    }
    pub fn pop      (self: *Line, pos: usize) !u8 {
        if (self.used >  size)   unreachable;
        if (self.used == 0)      return error.LineIsEmpty;
        if (pos > size - 1)      unreachable;
        if (pos > self.used - 1) return error.UnexpectedPos;
        const rune = self.text[pos];
        if (pos != self.used - 1) { // shiftSymbolsToLeft
            const from = self.text[pos + 1  ..  self.used    ];
            const dest = self.text[pos      ..  self.used - 1];
            std.mem.copy(u8, dest, from);
        }
        self.used -= 1;
        return rune;
    } // end fn
    pub fn pushPrev (self: *Line, new_line: *Line) void {
        { // update chain
            if (self.prev) |prev| {
                prev.next = new_line;
                new_line.prev = prev;
            } // end if 
            self    .prev = new_line;
            new_line.next = self;
        }
        { // update tree
            if (self.parent) |parent| {
                self.parent     = null;
                parent.child    = new_line;
                new_line.parent = parent;
            }
        }
    } // end fn 
    pub fn pushNext (self: *Line, new_line: *Line) void {
        { // update chain
            if (self.next) |next| {
                next.prev = new_line;
                new_line.next = next;
            } // end if 
            self    .next = new_line;
            new_line.prev = self;
        } // update chain
    } // end fn add
    pub fn unFold   (self: *Line) void {
        var current = self;
        while(true) {
            prog.view.redraw();
            if (current.child) |child| {
                current.child = null;
                //{ insert range child..last into current and current.next
                    if (current.next) |current_next| { // tie last_child <-> current_next
                        var last_child: *Line = child;
                        while(true) { // find last_child
                            if(last_child.next) |next| {
                                last_child = next;
                            } else break;
                        } // end while
                        last_child  .next = current_next; 
                        current_next.prev = last_child;
                    } // end if
                    //{ tie child <-> current
                        child.prev   = current;
                        current.next = child;
                    //}
                //} end insert into last and current.next
            } // end if current_line.child
            if (current.next)  |next|  {
                current = next;
                continue;
            }
            break;
        } // end while
    } // end fn
//}
