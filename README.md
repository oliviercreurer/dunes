# Dunes (v2.0.1)
Dunes is a function sequencer for Monome Norns by @olivier. Extended version by @sonocircuit <br>
llllllll.co/t/dunes/24790

Inspired by [spacetime](https://monome.org/docs/norns/study-3/), Dunes is a sequencer for the creation of emergent patterns, timbres and textures.

## Documentation:

### Norns

**`enc1:`** navigate pages <br>
<br>
**PAGE 1: SEQUENCE** <br>
**`enc2:`** navigate to step <br>
**`enc3:`** select command <br>
**`key1 [hold]:`** ignore command (`#` and `?` are not ignored)<br>
**`key1 [hold] + enc2:`** change note <br>
**`key2:`** stop/start <br>
**`key1 [hold] + key2:`** reset position <br>
**`key3:`** randomize commands <br>
**`key1 [hold] + key3:`** reset commands <br>
**`key3 [longpress]:`** reset all <br>
<br>
**PAGE 2 & 3: DELAY and SYNTH PARAMETERS** <br>
**`enc2:`** change left parameter <br>
**`enc3:`** change right parameter <br>
**`key2:`** toggle row <br>
<br>
**PAGE 4: COMMAND LIST** <br>
**`enc2:`** navigate command list <br>

---

### Grid

![grid layout](https://github.com/sonoCircuits/dunes/blob/master/assets/dunes%20grid%20layout-6.jpg)

- press and hold a `command key` and press the according `sequence step` to assign the command to that step.
- press `alt` and a `sequence step` to jump to the according position
- `base clk mult` sets the multiplication factor of the internal clock. 1 = 4 bar sequence.
- `direction` sets the playback direction.
- `note pattern presets` selects the active note pattern.
- `command sequence presets` selects the active command sequence.
- press and hold `alt` and press a non-selected preset slot to copy the currently selected note pattern / command sequence to the according slot.

---

### Command List

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

__Other:__

- `!` : Insert random command at random step
