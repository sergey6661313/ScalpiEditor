const Line = @This();
const std  = @import("std");
const Prog = @import("root");
const prog = &Prog.prog;
pub const Text = struct {
    pub const size      = 254;
    buffer:   [size]u8  = undefined,
    used:     usize     = 0,
    pub fn insert (self: *Text, pos: usize, rune: u8) !void {
        if (self.used > size) unreachable;
        if (pos       > size) unreachable;
        if (self.used == size - 1) return error.LineIsFull;
        if (pos > self.used)   return error.UnexpectedPos;
        if (pos < self.used)   { // shiftSymbolsToRight
            const from = self.buffer[pos      ..  self.used    ];
            const dest = self.buffer[pos + 1  ..  self.used + 1];
            std.mem.copyBackwards(u8, dest, from);
        }
        self.buffer[pos] = rune;
        self.used += 1;
    }
    pub fn delete (self: *Text, pos: usize) !void {
        if (self.used >  size)    unreachable;
        if (self.used == 0)       return error.LineIsEmpty;
        if (pos >  size - 1)      unreachable;
        if (pos >  self.used - 1) return error.UnexpectedPos;
        if (pos != self.used - 1) { // shiftSymbolsToLeft
            const from = self.buffer[pos + 1  ..  self.used    ];
            const dest = self.buffer[pos      ..  self.used - 1];
            std.mem.copy(u8, dest, from);
        }
        self.used -= 1;
    } // end fn
    pub fn get    (self: *Text) []u8 {
        return self.buffer[0 .. self.used];
    }
    pub fn set    (self: *Text, text: []const u8) void {
        if (text.len > size) unreachable;
        std.mem.copy(u8, self.buffer[0..], text);
        self.used = text.len;
    }
};
text:   Text      = .{},
next:   ?*Line    = null,
prev:   ?*Line    = null,
parent: ?*Line    = null,
child:  ?*Line    = null,
pub fn init     (self: *Line) !void {
  self.next   = null;
  self.prev   = null;
  self.parent = null;
  self.child  = null;
}
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
