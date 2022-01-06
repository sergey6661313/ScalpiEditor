// defines
const Line = @This();
pub const max = 254;
// fields
text:        [max]u8  = undefined,
len:         u8       = 0,
id:          usize    = undefined,
parent:      ?usize   = null,
child:       ?usize   = null,
next:        ?usize   = null,
prev:        ?usize   = null,
// methods
pub fn getText(self: *Line) []u8 {
    return self.text[0 .. self.len];
}
