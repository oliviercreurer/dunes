# Dunes (v2.0.0)
Dunes is a function sequencer for Monome Norns
by @olivier and @sonocircuit<br>
llllllll.co/t/dunes/24790

Inspired by [spacetime](https://monome.org/docs/norns/study-3/), Dunes is a sequencer for the creation of emergent patterns, timbres and textures. Commands – assigned per step in the bottom row of the EDIT page – modulate sequence, engine and softcut parameters.

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

__Engine:__

- `G` : Random glide at step
- `d` : Decay -
- `D` : Decay +
- `s` : Wave shape -
- `S` : Wave shape +
- `f` : Wave folds -
- `F` : Wave folds +
- `v` : Reverb mix -
- `V` : Reverb mix +

__Softcut:__

- `X` : Random pan position (-1 - 1)
- `1` : Reset delay rate
- `2` : Multiply delay rate (forward)
- `3` : Multiply delay rate (reverse)
- `4` : Divide delay rate (forward)
- `5` : Divide delay rate (reverse)
- `Z` : Freeze delay buffer
- `z` : Unfreeze delay buffer
- `!` : Insert random command at random step
