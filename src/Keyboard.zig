const Keyboard = @This();
const Prog = @import("root");
const prog = &Prog.prog;
const lib = Prog.lib;
pub const c = lib.c; 

last: c_int = 0,

pub fn updateKeys(self: *Keyboard) void {
    const f_stdin = c.fileno(c.stdin); 
    var bytesWaiting: c_int = undefined;
    _ = c.ioctl(f_stdin, c.FIONREAD, &bytesWaiting);
        while(bytesWaiting > 0) : (bytesWaiting -= 1) {
        const char = c.getchar();
        switch(char) {
            'q', 208, 185 => prog.working = false,
            else => {},
        }
        self.last = char;
    }
    // TODO if key == ctrl + w {bufferClose();}
    // TODO if key == ctrl + q {bufferClose(); self.working = false;}
}