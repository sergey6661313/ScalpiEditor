const Keyboard = @This();
const std  = @import("std");
const Prog = @import("root");
const ansi = @import("ansi.zig");
const prog = &Prog.prog;
const lib  = Prog.lib;
pub const c = lib.c; 

last: c_int = 0,

const hex = "0123456789abcdef";

pub fn updateKeys(self: *Keyboard) void {
    const f_stdin = c.fileno(c.stdin); 
    var bytesWaiting: c_int = undefined;
    _ = c.ioctl(f_stdin, c.FIONREAD, &bytesWaiting);
    while(bytesWaiting > 0) : (bytesWaiting -= 1) {
        const char: c_int = c.getchar();
        //~ std.log.info("bytesWaiting = {}, char = {x}",.{bytesWaiting, char});

        //~ if (false) {
        switch(char) {
            lib.key.esc        => {
                if (bytesWaiting == 1) prog.working = false;
            },
            'q'                => {prog.working = false;},
            'j', lib.key.down  => {
                const curent_line = prog.buffer.lines.get(prog.selected_line_id);
                const next = curent_line.next;
                if (next) |id| prog.selected_line_id = id;
                prog.need_redraw = true;
            },            
            'k', lib.key.up    => {
                const curent_line = prog.buffer.lines.get(prog.selected_line_id);
                const next = curent_line.prev;
                if (next) |id| prog.selected_line_id = id;
                prog.need_redraw = true;
            },
            else => {},
        //~ }
        }
        self.last = char;
    }
}
