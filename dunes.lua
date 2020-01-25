--
--
--  DUNES (v1.1.1)
--  Function sequencer
--  @olivier
--  https://llllllll.co/t/dunes/24790 
--
--  
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

-- The following core libs are used to implement save and load features.
local textentry = require 'textentry'
local fileselect = require 'fileselect'
local listselect = require 'listselect'

local midi = midi.connect()
local midi_output_channel = 1

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local DUNES_DATA_PATH = _path.data..'dunes/'

local pages = {"EDIT", "COMMANDS/SEQUENCE", "COMMANDS/ENGINE", "COMMANDS/SOFTCUT"}
local output_options = {"audio", "audio + midi", "midi"}
local active_notes = {}

local baseFreq = 440
local position = 1
local pageNum = 1
local edit = 1
local STEPS = 16
local cmd_sequence = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
local scaleGroup = 1
local noteSel = 1
local metronome = 1
local direction = 0

local KEYDOWN1 = 0
local KEYDOWN2 = 0

local note_pattern = {}
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

local function all_notes_off()
  if (params:get("output") == 2 or params:get("output") == 3) then
    for _, a in pairs(active_notes) do
      midi:note_off(a, nil, midi_out_channel)
    end
  end
  active_notes = {}
end

-- COMMANDS

-- SEQUENCE COMMANDS
function octdec() octave = util.clamp(octave - 12, -12, 12) end
function octinc() octave = util.clamp(octave + 12, -12, 12) end
function metrodec() counter.time = util.clamp(counter.time * 2, 0.125, 1) end
function metroinc() counter.time = util.clamp(counter.time / 2, 0.125, 1) end
function nPattern() newPattern() end
function nNote() note_pattern[position] = scaleNotes[scaleGroup][math.random(#scaleNotes[scaleGroup])] + offset end
function posRand() position = math.random(STEPS) end
function dirForward() direction = 0 end
function dirReverse() direction = 1 end
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
function rateMforward() delayRate = util.clamp(delayRate * 2,0.5,2) end
function rateMreverse() delayRate = util.clamp(delayRate * 2,-0.5,-2) end
function rateDforward() delayRate = util.clamp(delayRate / 2,0.5,2) end
function rateDreverse() delayRate = util.clamp(delayRate / 2,-0.5,-2) end

local actions = {octdec,octinc,metrodec,metroinc,nPattern,nNote,posRand,dirForward,dirReverse,rest,decaydec,decayinc,wShapedec,wShapeinc,wFolddec,wFoldinc,verbdec,verbinc,panrnd,rateMforward,rateMreverse,rateDforward,rateDreverse} -- metrodec,metroinc,nPattern,cutinc,cutdec,posrand,release,newNote,addRest,removeRest,ampinc,ampdec,pw}
local COMMANDS = #actions
local REST_ACTION = 10
local NOT_FOUND_ACTION = 7 -- "?" Random note
-- Labels for display
local label = {"<", ">", "-", "+", "P", "N", "?", "}", "{", "M", "d", "D", "s", "S", "f", "F", "v", "V", "1", "2", "3", "4", "5"}
-- Labels for filename generation. Must be file safe chars!
local fn_label = {"o", "O", "-", "+", "P", "N", "Q", "E", "W", "M", "d", "D", "s", "S", "f", "F", "v", "V", "1", "2", "3", "4", "5"}
local description = {"Oct -", "Oct +", "Metro -", "Metro +", "New patt.", "New note", "Rnd step", "Forward", "Reverse", "Rest", "Decay -", "Decay +", "Shape -", "Shape +", "Folds -", "Folds +", "Reverb -", "Reverb +", "Pan (rnd)", "Rate * (+)", "Rate * (-)", "Rate / (+)", "Rate / (-)"}

function init()
  params:add_option("output", "output", output_options, 1)
  params:set_action("output", function() all_notes_off() end)
  
  params:add_separator()
  
  print('adding triggers')
  params:add_trigger('save_seq','< Save Sequence')
  params:set_action('save_seq', function(x)  listselect.enter({'Save Command Sequence','Save Note Pattern','Save Both'},function(save_mode) textentry.enter( function(new_fn) seq_save(new_fn,save_mode) end, gen_seq_filename(),'Save sequence as ...') end) end)
  
  params:add_trigger('load_seq','> Load Sequence')
  params:set_action('load_seq', function(x) fileselect.enter(norns.state.data, seq_load) end)
  
  --params:add_trigger('save_pattern','< Save pattern')
  --params:add_trigger('load_pattern','> Load pattern')
  
  hs.init()
  
  params:add_separator()
  
  params:add_option("scale", "scale", scaleNames, 1)
  params:set_action("scale", function(x) scaleGroup = x end)
 
  params:add_separator()
  
  Passersby.add_params()
  counter = metro.init(count, 0.25, -1)
  counter:start()
  newPattern()
  engineReset()
end

function count()
  all_notes_off()
  if direction == 0 then
    position = (position % STEPS) + 1
  else 
    position = ((position + 14) % STEPS) + 1
  end
  actions[cmd_sequence[position]]()
  if actions[cmd_sequence[position]] ~= actions[REST_ACTION] then
    local note_num = note_pattern[position] + offset + octave
    -- engine output
    if params:get("output") == 1 or params:get("output") == 2 then
      engine.noteOn(1,(midi_to_hz(note_num)),1)
    end
    -- midi output
    if params:get("output") == 2 or params:get("output") == 3 then
      midi:note_on(note_num, 100, 1)
      table.insert(active_notes, note_num)
    end
  else
    -- this is a rest, do nothing
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
  -- softcut.position(1,1)
  redraw()
end

function gen_seq_filename()
  -- more vowel combos increases name variety
  vowels = {'a','e','i','o','u','y','hi','ae','ou'}
  fn = ''
  while fn=='' or util.file_exists(norns.state.data..fn..'.seq') do
    for i=1,4 do fn = fn .. string.sub(description[cmd_sequence[math.random(16)]],0,1) .. vowels[math.random(#vowels)] end
    -- TODO eventually someone could use all possible combos and go into a permenant loop...
  end
  return fn
end

function seq_save(fn,mode)
  local file, err = io.open(norns.state.data..fn..'.seq', "w+")
  if err then print('io err:'..err) return err end
  -- Write Command Sequnce
  if mode == 'Save Command Sequence' or mode == 'Save Both' then
    seq = ''
    for k,v in pairs(cmd_sequence) do seq = seq .. label[v] end
    file:write('CMD:'..seq .. '\n')
  end
  -- Write Command Sequnce
  if mode == 'Save Note Pattern' or mode == 'Save Both' then
    -- First save the notes
    pattern = ''
    file:write('NOTES:')
    file:write(tostring(note_pattern[1]-offset))
    for i=2,#note_pattern do file:write(','..tostring(note_pattern[i]-offset)) end
    file:write('\n')
    -- Save the Scale
    file:write('SCALE:' .. scaleGroup)
  end
  file:close()
end

function seq_load(fn)
  print("Loading sequnce file"..fn)
  
  local file, err = io.open(fn, "r")
  if err then print('io err:'..err) return err end
  for line in file:lines() do
    -- split into header and sequence and check header
    seq_header, loading_string = line:match("([A-Z]*):(.*)")
    
    if seq_header == 'CMD' then 
      load_cmd_seq(loading_string)
    elseif seq_header == 'NOTES' then 
      load_note_pattern(loading_string)
    elseif seq_header == 'SCALE' then 
      --Set scale
      scaleGroup = tonumber(loading_string)
    else
      print("Error: Invalid sequence header "..(seq_header or 'nil')) 
    end
  end
  file:close()
end

function load_cmd_seq(loading_seq)
  --make sure the Sequnce is not too long or short and pad with '<'
  loading_seq = string.sub(loading_seq,0,STEPS)
  loading_seq = loading_seq .. string.rep("<", STEPS-#loading_seq)
  
  -- and split into a table of Chars
  new_cmd_sequence = {}
  loading_seq:gsub(".",function(chr) 
    -- Find the index of each step of the cmd sequence and insert into the current seqence
    action = tab.key(label,chr) or NOT_FOUND_ACTION
    table.insert(new_cmd_sequence,action)
  end)

  -- replace current sequence with laoded sequence
  if #new_cmd_sequence == STEPS then
    cmd_sequence = new_cmd_sequence 
    updateRests()
  else
    print("Error: Sequence was not the correct length after parsing.")
  end
end

function load_note_pattern(note_string)
  print("Read NOTE string:" .. note_string)
  new_note_pattern = {}
  note_string:gsub("([^,]+)",function(read_note) 
    print("Read NOTE:" .. read_note)
    table.insert(new_note_pattern,tonumber(read_note)+offset) 
  end)
  note_pattern = new_note_pattern
end

function newPattern()
  for i=1,16 do
    table.insert(note_pattern,i,(scaleNotes[scaleGroup][math.random(#scaleNotes[scaleGroup])] + offset)) -- (#notes[scaleGroup])
  end
end

function updateRests()
  for i=1,#cmd_sequence do
    if cmd_sequence[i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
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
  for i=1,#cmd_sequence do
    screen.level((i == edit) and 15 or 1)
    screen.move(i*8-8+1,60)
    screen.text(label[cmd_sequence[i]])
  end
  drawNotePattern()
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
      for i=19,23 do
        screen.move(1,(i-18)*9+15)
        screen.text(label[i])
      end
      screen.move(10,20)
      screen.level(4)
      for i=19,23 do
        screen.move(10,(i-18)*9+15)
        screen.text(description[i])
      end
    end
end

function drawNotePattern()
  for i=1,#cmd_sequence do
    --update rests 
    if cmd_sequence[i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
      
    -- Draw note levels
    screen.move(i*8-8+1,45-((note_pattern[i])/3)+5)
    if i == position then
      screen.level(15)
      screen.line_rel(0,0)
    else
      -- screen.level(1)
      if rests[i] == 1 then
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
      noteSel = util.clamp(noteSel + d,1,#scaleNotes[scaleGroup])
      note_pattern[edit] = scaleNotes[scaleGroup][noteSel] + offset
    end
  elseif n == 2 then
    if KEYDOWN2 == 0 then
      edit = util.clamp(edit + d, 1, STEPS)
    end
  elseif n == 3 then
    cmd_sequence[edit] = util.clamp(cmd_sequence[edit]+d, 1, COMMANDS)
    if cmd_sequence[edit] == REST_ACTION then rests[edit] = 1 else rests[edit] = 0 end
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
        for i=1,#cmd_sequence do
          cmd_sequence[i] = 1
        end
      else
        metronome = 1 - metronome
        count()
      end
    end
  elseif n == 3 and d == 1 then
    randomize_cmd_sequence()
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
  softcut.rec(1,1)
  softcut.buffer_clear_channel(1)
end

function noteSelect()

end

function randomize_cmd_sequence()
  for i=1,16 do
    cmd_sequence[i] = math.random(COMMANDS)
  end
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

scaleNotes = {  
  {0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31,33,35,36,38,40,41,43,45,47,48},
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

scaleNames = {
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
