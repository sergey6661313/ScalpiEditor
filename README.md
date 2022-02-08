<pre>
ScalpiEditor - Simple console text editor writed from zig language. 
features:
   *  ready for edit simpliest file like configs
      ⚠️ display only ansi symbols
      ⚠️ no undo/redo
      ⚠️ does not offer to save the file on exit (until it stabilizes)
      -  not ability to copy/paste multiple lines/blocks
      -  not ability to paste from external buffer
   *  one time memory allocation. 
      +  stable working, no memory leaks, freezes, or other
      -  Limit on the number and size of rows 
   *  text folding (from figure brackets, tabs, spaces, )
      +  Navigete on your code in MC style.
      -  work only if the brackets/indents are nicely placed.
      -  dangerous operations do unfold 
      -  folding by spaces/tabs work is not stable yet...

for compile use zig language ver. 0.9. (https://ziglang.org):
    $ zig build
and find binaries in "zig-out/bin"...
</pre>

[![asciicast](https://asciinema.org/a/Mck6jByurHgviSTed3If2IcYq.svg)](https://asciinema.org/a/Mck6jByurHgviSTed3If2IcYq)
[![asciicast](https://asciinema.org/a/466962.svg)](https://asciinema.org/a/466962)
[![asciicast](https://asciinema.org/a/466820.svg)](https://asciinema.org/a/466820)
[![asciicast](https://asciinema.org/a/466813.svg)](https://asciinema.org/a/466813)
