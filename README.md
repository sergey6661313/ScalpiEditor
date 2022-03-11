<pre>
ScalpiEditor - Simple console text editor writed from zig language.
features:
   *  ready for edit simpliest file like configs:
      ⚠️ display only ansi symbols
      ⚠️ no undo/redo
      ⚠️ does not offer to save the file on exit (until it stabilizes)
   *  text folding (from figure brackets, tabs, spaces, ):
      +  Navigete on your code in MC style.
      -  brackets work only if the brackets are nicely placed. (one change nest to one line)
   *  one time memory allocation:
      +  stable working, no memory leaks, freezes, or other.
      -  Limit on the number and size of rows 
   *  uses terminal: tested work in termux, alacritty, evilvte

for compile use zig language ver. 0.9. (https://ziglang.org):
    $ zig build
and find binaries in "zig-out/bin"...

to support me (monero): 87T7qGbATrM3a6BrDyeCjQQfNWtUu3iZbHVBMC6WmEbNNE13QrrtKhBbe4vF58NR8PTFdYk2SozcHexX4Q69jbdQAsrsP7B
</pre>

examples:
[![asciicast](https://asciinema.org/a/467542.svg)](https://asciinema.org/a/467542)
[https://www.youtube.com/watch?v=51ao2416ioE&t=60s