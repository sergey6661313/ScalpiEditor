//const Self = @This();
const Prog = @import("root");
const ansi = Prog.ansi;

pub const c = @cImport({
  @cInclude("stdio.h");
});
pub fn printRune (rune: u8) void {
  _ = c.fputc(rune, c.stdout);
}
pub fn flush     () void {
  _ = c.fflush(c.stdout);
}
pub fn print     (text: []const u8) void {
  for (text) |ch| {
    printRune(ch);
  }
}
pub fn clearLine () void {
  print(ansi.clear_line);
}
