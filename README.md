# Dunes (v2.0.0)
Dunes is a function sequencer for Monome Norns by @olivier. Extended version by @sonocircuit <br>
llllllll.co/t/dunes/24790

Inspired by [spacetime](https://monome.org/docs/norns/study-3/), Dunes is a sequencer for the creation of emergent patterns, timbres and textures. Commands – assigned per step in the bottom row of the EDIT page – modulate sequence, engine and softcut parameters.

## Docs:

## Norns interface

**`enc1:`** navigate pages <br>
<br>
**PAGE 1: SEQUENCE** <br>
**`enc2:`** navigate to step <br>
**`enc3:`** select command <br>
**`key1 [hold]:`** ignore command <br>
**`key1 [hold] + E2:`** change note <br>
**`key2:`** stop/start <br>
**`key1 [hold] + K2:`** reset position <br>
**`key3:`** randomize commands <br>
**`key1 [hold] + K3:`** reset commands <br>
**`key3 [longpress]:`** reset all <br>
<br>
**PAGE 2 & 3: DELAY and SYNTH PARAMETERS** <br>
**`enc2:`** change left parameter <br>
**`enc3:`** change right parameter <br>
**`key2:`** toggle row <br>
<br>
**PAGE 4: COMMAND LIST** <br>
**`enc2:`** navigate command list <br>


## Command List

__Sequence:__
- `<` : Octave up
- `>` : Octave down
- `O` : Random octave
- `-` : Half tempo
- `+` : Double tempo
- `=` : Reset tempo
- `M` : Add rest (at step)
- `N` : New note (at step)
- `P` : New pattern
- `#` : Reset position
- `?` : Jump to random step
- `}` : Forward direction
- `{` : Reverse direction
- `!` : Insert random command at random step

__Passersby synth:__

- `G` : Random glide at step
- `d` : Decay -
- `D` : Decay +
- `s` : Wave shape -
- `S` : Wave shape +
- `f` : Wave folds -
- `F` : Wave folds +
- `v` : Reverb mix -
- `V` : Reverb mix +

__Softcut delay:__

- `X` : Random pan position (-1 - 1)
- `1` : Reset delay rate
- `2` : Multiply delay rate (forward)
- `3` : Multiply delay rate (reverse)
- `4` : Divide delay rate (forward)
- `5` : Divide delay rate (reverse)
- `Z` : Freeze delay buffer
- `z` : Unfreeze delay buffer

