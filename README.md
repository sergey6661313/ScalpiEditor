#    Due to the policy of github and the purchase of it by microsoft, we are moving to
     https://chiselapp.com/user/sergey6661313/repository/ScalpiEditor
\
\
\
\
\
\
\
\
#### Author: Scalpi
#### github: (this repo contains is developer code. If you don't want surprises just use the latest "release".)
     https://github.com/sergey6661313/ScalpiEditor
#    ScalpiEditor - text editor for linux terminals (console) writed from zig language.
     ⚠️ display only ansi symbols
     ⚠️ no undo/redo
     ⚠️ does not offer to save the file on exit (until it stabilizes)
#    video:
     https://www.youtube.com/watch?v=51ao2416ioE&t=60s
     [![asciicast](https://asciinema.org/a/467542.svg)](https://asciinema.org/a/467542)
#    download and compile
#### ScalpiEditor use zig language compiller for compile.
     https://ziglang.org/download/
###  stable release
     wget https://github.com/sergey6661313/ScalpiEditor/archive/refs/tags/v0.3.1.tar.gz
     tar -xf v0.3.1.tar.gz # unpack
     rm -rf v0.3.1.tar.gz  # delete archive
     cd ScalpiEditor-0.3.1 # jump inside
###  Or if you're lucky you can use unstable git version. 
     git clone --recurse https://github.com/sergey6661313/ScalpiEditor.git #download
     cd ScalpiEditor #jump inside
###  compile 
#### compilable from zig language developer version "master" i`m use zig-linux-x86_64-0.10.0-dev.1724+51ef31a83
#### when zig 0.10 comes out I will focus on stable releases.
     zig build
#### and find binary in "zig-out/bin"...
#    usage:
     ScalpiEditor FILENAME
#### use [ctrl] + [e] for parse file from "{" and "}" and use arrows and [tab] or [esc] for navigation
##   you may rename and copy binary to "~/bin/se" like this:
     cp ./zig-out/bin/ScalpiEditor ~/bin/se
#### and add this lines to config (".bashrc" file) for easy use:
     export EDITOR="~/bin/se"
     export PATH="~/bin:$PATH"
##   to support me (monero): 
     87T7qGbATrM3a6BrDyeCjQQfNWtUu3iZbHVBMC6WmEbNNE13QrrtKhBbe4vF58NR8PTFdYk2SozcHexX4Q69jbdQAsrsP7B
