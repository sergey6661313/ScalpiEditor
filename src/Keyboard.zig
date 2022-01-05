// zig fmt: off
//{ defines
    const Keyboard = @This();
    const std  = @import("std");
    const Prog = @import("root");
    const ansi = @import("ansi.zig");
    const prog = &Prog.prog;
    const lib  = Prog.lib;
    pub const c = lib.c; 
//}
//{ methods
    pub fn updateKeys(_: *Keyboard) void {
        var count: usize  = undefined;
        var bytes: [15]u8 = undefined;
        //{ get count
            var bytesWaiting: c_int = undefined;
            const f_stdin = c.fileno(c.stdin);
            _ = c.ioctl(f_stdin, c.FIONREAD, &bytesWaiting);
            count = @intCast(usize, bytesWaiting);
        //}
        if (count == 0) return;
        { // get bytes
            var pos: usize = 0;
            while(true) {
                const char: c_int = c.getchar();
                bytes[pos] = @ptrCast(*const u8, &char).*;
                pos += 1;
                if(pos == count) break;
            }// end while
        } // end get chars
        switch(bytes[count - 1]) {
            lib.key.esc   => {
                prog.working = false;
            },
            lib.key.down  => {
                const curent_line = prog.buffer.lines.get(prog.selected_line_id);
                const next = curent_line.next;
                if (next) |id| {
                    prog.selected_line_id = id;
                    prog.need_redraw = true;
                    if (prog.amount_drawable_upper_lines < prog.console.size.y) {
                        prog.amount_drawable_upper_lines += 1;
                    }
                }
            },            
            lib.key.up    => {
                const curent_line = prog.buffer.lines.get(prog.selected_line_id);
                const prev = curent_line.prev;
                if (prev) |id| {
                    if (prog.amount_drawable_upper_lines > 0) {
                        prog.amount_drawable_upper_lines -= 1;
                    }
                    prog.selected_line_id = id;
                    prog.need_redraw = true;
                }
            },
            's'           => prog.save(),
            'e'           => prog.changeModeToEdit(),
            else          => {},
        } // end get chars
    } // end fn updateKeys
//}
