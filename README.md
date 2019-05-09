This is a Chip-8 interpreter written with the Dragonruby game toolkit.
It's super hacky but mostly works. The interpreter speed is tied to the
framerate of the game, but if you press the 9 and 0 keys you can slow down
or speed up the interpreter respectively at the possible risk of making
games unplayable and/or exhibit weird behavior.

The Chip-8 used a hex keyboard that looked more or less like a numpad, I've
mapped the keys for this interpreter like so:
```
 Mine       Original
1 2 3 4 <=> 1 2 3 C
q w e r <=> 4 5 6 D
a s d f <=> 7 8 9 E
z x c v <=> A 0 B F
```

The roms are currently loaded in a hardcoded fashion so you'll have to edit
the first few lines to change roms.
