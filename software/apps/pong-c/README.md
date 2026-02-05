# eSC-V port for pong.c

Original: https://github.com/pbogre/pong.c

## Requirements

A C Compiler. The program has been tested on MacOS Ventura 13.0.1
If you happen to try this software on different systems, please let me know about its performance.

## Instructions

### Installing

Compile using gcc: `gcc -o pong pong.c`.

If you wish to be able to run `pong` from any directory, either put the binary in a folder like `/usr/bin` or add the folder with the binary to your environment

### Keybinds

For single player mode, use the `w` and `s` keys to move up and down respectively. In pvp mode, the second player may use `UP` and `DOWN` for the same actions.

### Arguments

- `-pvp`: Enables player v. player.
- `-eve`: Enables enemy v. enemy. This will just let two bots fight it out
- `-debug | -d`: Enables debug mode. Shows more information below the game
- `-w [width]`: Sets width of the field.
- `-h [height]`: Sets height of the field.
- `-u [updates]`: Sets game update frequency. Basically, lower values = faster games.
- `-fow [fog of war]`: Sets the fog of war of bots. Basically, lower values = better bots.

### Examples

- `pong -w 128 -h 64 -d`

- `pong -pvp -debug`

- `pong -eve -fow 1 -u 10`

## To-Do:

- show keybinds during game
- show gifs in examples
