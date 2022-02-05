const Line = @This();
const std = @import("std");
const Prog = @import("root");
const prog = &Prog.prog;
pub const Text = @import("Text.zig");
pub const RuneIteratorUtf8 = struct {};
text: Text = .{},
next: ?*Line = null,
prev: ?*Line = null,
parent: ?*Line = null,
child: ?*Line = null,
pub fn init(self: *Line) !void {
    self.next = null;
    self.prev = null;
    self.parent = null;
    self.child = null;
}
pub fn pushPrev(self: *Line, new_line: *Line) void {
    { // update chain
        if (self.prev) |prev| {
            prev.next = new_line;
            new_line.prev = prev;
        } // end if
        self.prev = new_line;
        new_line.next = self;
    }
    { // update tree
        if (self.parent) |parent| {
            self.parent = null;
            parent.child = new_line;
            new_line.parent = parent;
        }
    }
} // end fn
pub fn pushNext(self: *Line, new_line: *Line) void {
    { // update chain
        if (self.next) |next| {
            next.prev = new_line;
            new_line.next = next;
        } // end if
        self.next = new_line;
        new_line.prev = self;
    } // update chain
} // end fn add
pub fn getParent(self: *Line) ?*Line {
    var current: ?*Line = self;
    while (current) |line| {
        if (line.parent) |parent| {
            return parent;
        }
        current = line.prev;
    }
    return null;
}
pub fn unFold(self: *Line) void {
    var current = self;
    while (true) {
        if (current.child) |child| {
            current.child = null;
            child.parent = null;
            //{ insert range child..last into current and current.next
            if (current.next) |current_next| { // tie last_child <-> current_next
                var last_child: *Line = child;
                while (true) { // find last_child
                    if (last_child.next) |next| {
                        last_child = next;
                    } else break;
                } // end while
                last_child.next = current_next;
                current_next.prev = last_child;
            } // end if
            //{ tie child <-> current
            child.prev = current;
            current.next = child;
            //}
            //} end insert into last and current.next
        } // end if current_line.child
        if (current.next) |next| {
            current = next;
            continue;
        }
        break;
    } // end while
} // end fn
pub fn foldFromBrackets(self: *Line) void {
    self.unFold();
    var current: ?*Line = self;
    while (current) |line| {
        var close_count = line.text.getRunesCount('}'); // **{
        var open_count = line.text.getRunesCount('{'); // **}
        if (open_count == close_count) {
            current = line.next;
        } else if (open_count > close_count) {
            if (line.next) |next| {
                next.parent = line;
                line.child = next;
                line.next = null;
                next.prev = null;
            }
            current = line.child;
        } else { // for close_count > open_count
            if (line.getParent()) |parent| {
                if (line.next) |next| {
                    next.prev = parent;
                }
                parent.next = line.next;
                current = line.next;
                line.next = null;
            } else { // unexpected
                current = line.next;
                continue;
            }
        }
    }
}
pub fn foldFromTabs(self: *Line) void {
    self.text.set("folded from tabs");
    var current: ?*Line = self;
    var last_tabs: usize = 0;
    while (current) |line| {
        self.unFold();
        var tabs = line.text.getFirstRunesCount('\t');
        if (tabs == last_tabs) {
            current = line.next;
        } 
        else if (tabs > last_tabs) {
            if (line.prev) |prev| {
                prev.child = line;
                line.parent = prev;
                prev.next = null;
                line.prev = null;
                last_tabs = tabs;
                current = line.next;
            } else { // unexpected
                last_tabs = tabs;
                current = line.next;
            }
        } 
        else { // tabs < last_tabs
            if (line.getParent()) |parent| {
                parent.next = line;
                line.prev = parent;
                line.parent = null;
                current = line.next;
                last_tabs = tabs;
            } 
            else { // unexpected
                last_tabs = tabs;
                current = line.next;
            }
        }
    }
}
pub fn moveAllNextLinesToUpperLineAsChild(self: *Line) void {
    if (self.prev) |prev| {
        self.prev = null;
        prev.next = null;
        prev.child = self;
        self.parent = prev;
    }
}
pub fn findParentWithRuneCount(self: *Line, count: usize, rune: u8) ?*Line {
    var current: ?*Line = self;
    while (current) |line| {
        if (line.getParent()) |parent| {
            if (parent.text.getFirstRunesCount(rune) == count) return parent;
        } else break;
    }
    return null;
}
pub fn foldFromSpaces(self: *Line) void {
    var current: ?*Line = self;
    var last_spaces: usize = 0;
    while (current) |line| {
        self.unFold();
        var spaces = line.text.getFirstRunesCount(' ');

        // debug
        var buffer:   [200]u8 = undefined;
        var sprintf_result    = Prog.lib.c.sprintf(&buffer, "spaces: %d\n", spaces);
        var buffer_len        = @intCast(usize, sprintf_result);
        line.text.set(buffer[0..buffer_len]);

        if (spaces == last_spaces) {
            current = line.next;
        } else if (spaces > last_spaces) {
            line.moveAllNextLinesToUpperLineAsChild();
            last_spaces = spaces;
            current = line.next;
        } else { // spaces < last_spaces
            var maybe_parent = self.findParentWithRuneCount(spaces, ' ');
            if (maybe_parent) |parent| {
                parent.next = line;
                line.prev = parent;
                line.parent = null;
                prog.view.line = line;
                prog.view.need_redraw = true;
                prog.view.draw();
                prog.view.line.text.set("spaces < last_spaces");
                std.time.sleep(std.time.ns_per_ms * 200);
                parent.text.set("parent of...");
            }
            last_spaces = spaces;
            current = line.next;
        }
    }
}
