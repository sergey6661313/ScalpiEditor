const StatusLine = @This();
const Prog = @import("root");
const prog = &Prog.prog;

// TODO draw name of current file (maybe scrolling text if size is very big)
pos: usize = 0, // line num. TODO change to buffer size - 2;

pub fn draw(self: *StatusLine) void {
    prog.console.cursor.move(0, self.pos);
    prog.console.print(prog.mode.ToText());
    prog.console.cursorToEnd();
}