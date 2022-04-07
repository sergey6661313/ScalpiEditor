Author: Scalpi
github: https://github.com/sergey6661313/ScalpiEditor  

# ScalpiEditor - console text editor for linux writed from zig language.
  ⚠️ display only ansi symbols
  ⚠️ no undo/redo
  ⚠️ does not offer to save the file on exit (until it stabilizes)
  
  
# motivation:
  This text editor was created for quick navigation through the sources 
  It allows code blocks to be treated like folders.
    

# download and compile: 
  ## download:
    git clone --recurse https://github.com/sergey6661313/ScalpiEditor.git
    cd ScalpiEditor
  ## compile: (use zig language ver. 0.9 (https://ziglang.org)):
    zig build
  and find binary in "zig-out/bin"...
  
# usage:
  ScalpiEditor FILENAME
you may copy and rename binary to "~/bin/se" like this:
  ```bash
    $ cp ./zig-out/bin/ScalpiEditor ~/bin/se
  ```
and this lines to config (".bashrc" file) for easy use:
  ```bash
    export EDITOR="~/bin/se"
    export PATH="~/bin:$PATH"
  ```  

## to support me (monero): 
  87T7qGbATrM3a6BrDyeCjQQfNWtUu3iZbHVBMC6WmEbNNE13QrrtKhBbe4vF58NR8PTFdYk2SozcHexX4Q69jbdQAsrsP7B

# examples:
  https://www.youtube.com/watch?v=51ao2416ioE&t=60s
  [![asciicast](https://asciinema.org/a/467542.svg)](https://asciinema.org/a/467542)