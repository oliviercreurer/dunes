--
--  DUNES
--  Function sequencer
--  V 1.0 @olivier
--  llllllll.co/t/?  
--
--  Navigation:
--
--  E1: Navigate pages
--  E2: Navigate to step
--  E3: Select command
--
--  K1 (hold) + E1: Change note
--  K2: Reset
--  K2 (hold): Stop/start
--  K3: Randomize all commands
--

engine.name = "Passersby"
Passersby = include "passersby/lib/passersby_engine"

hs = include('lib/dunes_hs')
hs.init()

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local pages = {"EDIT", "COMMANDS/SEQUENCE", "COMMANDS/ENGINE", "COMMANDS/SOFTCUT"}

local baseFreq = 440
local position = 1
local pageNum = 1
local edit = 1
local STEPS = 16
local step = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
local scaleGroup = 1
local noteSel = 1
local metronome = 1

local KEYDOWN1 = 0
local KEYDOWN2 = 0

local pattern = {}
local rests = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

local octave = 0
-- local transpose = 0
local offset = 20

local wave = 0.0
local decay = 1
local folds = 0.5
local verb = 0.05

local speedLhigh = {0.125,0.06}
local speedLlow = {1,2}
local speedH = 0.125
local speedL = 1
local pan = 0.5
local delayRate = 1


-- COMMANDS

-- SEQUENCE COMMANDS
function octdec() octave = util.clamp(octave - 12, -12, 12) end
function octinc() octave = util.clamp(octave + 12, -12, 12) end
function metrodec() counter.time = util.clamp(counter.time * 2, 0.125, 1) end
function metroinc() counter.time = util.clamp(counter.time / 2, 0.125, 1) end
function nPattern() newPattern() end
function nNote() pattern[position] = notes[scaleGroup][math.random(#notes[scaleGroup])] + offset end
function posRand() position = math.random(STEPS) end
function posFirst() position = 1 end
function posLast() position = 16 end
function rest() end

-- ENGINE COMMANDS
function decaydec() decay = util.clamp(decay - 0.10, 0.25,1.5) end
function decayinc() decay = util.clamp(decay + 0.10, 0.25,1.5) end
function wShapedec() wave = util.clamp(wave - 0.1, 0, 0.6) end
function wShapeinc() wave = util.clamp(wave + 0.1, 0, 0.6) end
function wFolddec() folds = util.clamp(folds - 0.10, 0, 1) end
function wFoldinc() folds = util.clamp(folds + 0.10, 0, 1) end
function verbdec() verb = util.clamp(verb - 0.05, 0.05, 0.5) end
function verbinc() verb = util.clamp(verb + 0.05, 0.05, 0.5) end

--SOFTCUT COMMANDS
function panrnd() pan = (math.random(2,8)/10) end
function delaydec() delayRate = util.clamp(delayRate * 2,0.5,2) end
function delayinc() delayRate = util.clamp(delayRate / 2,0.5,2) end

act = {octdec,octinc,metrodec,metroinc,nPattern,nNote,posRand,posFirst,posLast,rest,decaydec,decayinc,wShapedec,wShapeinc,wFolddec,wFoldinc,verbdec,verbinc,panrnd,delaydec,delayinc} -- metrodec,metroinc,nPattern,cutinc,cutdec,posrand,release,newNote,addRest,removeRest,ampinc,ampdec,pw}
COMMANDS = 21
label = {"<", ">", "-", "+", "P", "N", "?", "[", "]", "M", "d", "D", "s", "S", "f", "F", "v", "V", "1", "2", "3"}
description = {"Oct -", "Oct +", "Metro -", "Metro +", "New patt.", "New note", "Rnd step", "First step", "Last step", "Rest", "Decay -", "Decay +", "Shape -", "Shape +", "Folds -", "Folds +", "Reverb -", "Reverb +", "Pan", "Rate -", "Rate +"}

function init()
  params:add_separator()
  params:add_option("scale", "scale", names, 1)
  params:set_action("scale", function(x) scaleGroup = x end)
  params:add_separator()
  Passersby.add_params()
  counter = metro.init(count, 0.25, -1)
  counter:start()
  newPattern()
  engineReset()
end

function count()
  position = (position % STEPS) + 1
  act[step[position]]()
  if act[step[position]] ~= act[10] then
    rests[position-1] = 0
    engine.noteOn(1,(midi_to_hz(pattern[position] + offset + octave)),1)
  else
    rests[position-1] = 1
  end
  if metronome == 1 then
    counter:start()
  else
    counter:stop()
  end
  engine.waveShape(wave)
  engine.waveFolds(folds)
  engine.decay(decay)
  engine.reverbMix(verb)
  softcut.pan(1, pan)
  softcut.rate(1,delayRate)
  redraw()
end

function newPattern()
  for i=1,16 do
    table.insert(pattern,i,(notes[scaleGroup][math.random(#notes[scaleGroup])] + offset)) -- (#notes[scaleGroup])
  end
end

function drawMenu()
  for i=1,#pages do
    screen.move(i*4+108,8)
    screen.line_rel(1,0)
    if i == pageNum then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.stroke()
  end
  screen.move(1,10)
  screen.level(1)
  screen.text(pages[pageNum])
end

function drawEdit()
  for i=1,#step do
    screen.level((i == edit) and 15 or 1)
    screen.move(i*8-8+1,60)
    screen.text(label[step[i]])
  end
  drawSeq()
end

function drawHelp()
    if pageNum == 2 then
      screen.level(15)
      screen.move(1,20)
      for i=1,5 do
        screen.move(1,i*9+15)
        screen.text(label[i])
      end
      screen.move(10,20)
      screen.level(4)
      for i=1,5 do
        screen.move(10,i*9+15)
        screen.text(description[i])
      end
      screen.move(32,20)
      screen.level(15)
      for i=6,10 do
        screen.move(64,((i-5)*9)+15)
        screen.text(label[i])
      end
      screen.move(10,20)
      screen.level(4)
      for i=6,10 do
        screen.move(74,((i-5)*9)+15)
        screen.text(description[i])
      end
    elseif pageNum == 3 then
      screen.level(15)
      screen.move(1,20)
      for i=11,15 do
        screen.move(1,(i-10)*9+15)
        screen.text(label[i])
      end
      screen.move(10,20)
      screen.level(4)
      for i=11,15 do
        screen.move(10,(i-10)*9+15)
        screen.text(description[i])
      end
      screen.move(32,20)
      screen.level(15)
      for i=16,18 do
        screen.move(64,((i-15)*9)+15)
        screen.text(label[i])
      end
      screen.move(10,20)
      screen.level(4)
      for i=16,18 do
        screen.move(74,((i-15)*9)+15)
        screen.text(description[i])
      end
    elseif pageNum == 4 then
      screen.level(15)
      screen.move(1,20)
      for i=19,21 do
        screen.move(1,(i-18)*9+15)
        screen.text(label[i])
      end
      screen.move(10,20)
      screen.level(4)
      for i=19,21 do
        screen.move(10,(i-18)*9+15)
        screen.text(description[i])
      end
    end
end

function drawSeq()
  for i=1,#step do
    screen.move(i*8-8+1,45-((pattern[i])/3)+5)
    if i == position then
      screen.level(15)
      screen.line_rel(0,0)
    else
      -- screen.level(1)
      if rests[i-1] == 1 then
        screen.level(0)
      else
        screen.level(4)
      end
    end
    screen.line_rel(4,0)
    screen.stroke()
  end
end

function redraw()
  screen.clear()
  drawMenu()
  if pageNum == 1 then
    drawEdit()
  else
    drawHelp()
  end
  screen.update()
end

function enc(n,d)
  if n == 1 then
    if KEYDOWN1 == 0 then
      pageNum = util.clamp(pageNum + d,1,#pages)
    else
      noteSel = util.clamp(noteSel + d,1,#notes[scaleGroup])
      pattern[edit] = notes[scaleGroup][noteSel] + offset
    end
  elseif n == 2 then
    if KEYDOWN2 == 0 then
      edit = util.clamp(edit + d, 1, STEPS)
    end
  elseif n == 3 then
    step[edit] = util.clamp(step[edit]+d, 1, COMMANDS)
    print(scaleGroup)
  end
  redraw()
  print(pageNum)
end

down_time = 0

function key(n,d)
  if n == 1 then
    KEYDOWN1 = d
  elseif n == 2 then
    KEYDOWN2 = d
    if d == 1 then
      down_time = util.time()
    else
      hold_time = util.time() - down_time
      if hold_time < 1 then
        engineReset()
        for i=1,#step do
          step[i] = 1
        end
      else
        metronome = 1 - metronome
        count()
      end
    end
  elseif n == 3 and d == 1 then
    randomize_steps()
  end
  print(hold_time)
end

function engineReset()
  counter.time = 0.25
  engine.amp(0.8)
  rests = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  newPattern()
  wave = 0.0
  decay = 1
  folds = 0.5
  verb = 0.05
  octave = 0
  delayRate = 1
  pan = 0.5
  softcut.buffer_clear_channel(1)
end

function noteSelect()

end

function randomize_steps()
  for i=1,16 do
    step[i] = math.random(COMMANDS)
  end
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

notes = { {0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31,33,35,36,38,40,41,43,45,47,48},
          {0,2,3,5,7,8,10,12,14,15,17,19,20,22,24,26,27,29,31,32,34,36,38,39,41,43,44,46,48},
          {0,2,3,5,7,9,10,12,14,15,17,19,21,22,24,26,27,29,31,33,34,36,38,39,41,43,45,46,48},
          {0,1,3,5,7,8,10,12,13,15,17,19,20,22,24,25,27,29,31,32,34,36,37,39,41,43,44,46,48},
          {0,2,4,6,7,9,11,12,14,16,18,19,21,23,24,26,28,30,31,33,35,36,38,40,42,43,45,47,48},
          {0,2,4,5,7,9,10,12,14,16,17,19,21,22,24,26,28,29,31,33,34,36,38,40,41,43,45,46,48},
          {0,3,5,7,10,12,15,17,19,22,24,27,29,31,34,36,39,41,43,46,48,51,53,55,58,60,63,65,67},
          {0,2,4,7,9,12,14,16,19,21,24,26,28,31,33,36,38,40,43,45,48,50,52,55,57,60,62,64,67},
          {0,2,5,7,10,12,14,17,19,22,24,26,29,31,34,36,38,41,43,46,48,50,53,55,58,60,62,65,67},
          {0,3,5,8,10,12,15,17,20,22,24,27,29,32,34,36,39,41,44,46,48,51,53,56,58,60,63,65,68},
          {0,2,5,7,9,12,14,17,19,21,24,26,29,31,33,36,38,41,43,45,48,50,53,55,57,60,62,65,67},
          {0,1,3,6,7,8,11,12,13,15,18,19,20,23,24,25,27,30,31,32,35,36,37,39,42,43,44,47,48},
          {0,1,4,6,7,8,11,12,13,16,18,19,20,23,24,25,28,30,31,32,35,36,37,40,42,43,44,47,48},
          {0,1,4,6,7,9,11,12,13,16,18,19,21,23,24,25,28,30,31,33,35,36,37,40,42,43,45,47,48},
          {0,1,4,5,7,8,11,12,13,16,17,19,20,23,24,25,28,29,31,32,35,36,37,40,41,43,44,47,48},
          {0,1,4,5,7,9,10,12,13,16,17,19,21,22,24,25,28,29,31,33,35,36,37,40,41,43,45,47,48},
          -- {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28}
}

names = {
  "ionian",
  "aeolian",
  "dorian",
  "phrygian",
  "lydian",
  "mixolydian",
  "major_pent",
  "minor_pent",
  "shang",
  "jiao",
  "zhi",
  "todi",
  "purvi",
  "marva",
  "bhairav",
  "ahirbhairav",
  -- "chromatic"
}
