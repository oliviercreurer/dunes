--
--  DUNES (v1.1.2)
--  Function sequencer
--  @olivier
--  //llllllll.co/t/dunes/24790
--
--  w/ contributions from
--  @justmat
--  @JaggedNZ
--  @sonocircuit
--
--  PAGE 1:
--  E1: navigate pages
--  K1 (hold) + E1: change note
--  E2: navigate to step
--  E3: select command
--  K1 (hold): ignore command
--  K1 (hold) + K2: reset position
--  K2: stop/start
--  K3: randomize all commands
--  K3 (longpress): reset all
--
--  PAGE 2 & 3:
--  E1: navigate pages
--  E2: change left parameter
--  E3: change right parameter
--  K2: toggle row
--
--  PAGE 4:
--  E1: navigate pages
--  E2: navigate list

engine.name = "Passersby"
Passersby = include "passersby/lib/passersby_engine"

hs = include("lib/dunes_hs")

-- The following core libs are used to implement save and load features.
local textentry = require "textentry"
local fileselect = require "fileselect"
local listselect = require "listselect"

local m = midi.connect()
local midi_channel = 1

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local DUNES_DATA_PATH = _path.data.."dunes/"

local pages = {"SEQUENCE", "DELAY PARAMETERS", "ENGINE PARAMETERS", "COMMAND REFERENCE"}
local output_options = {"off", "midi", "crow 1+2", "crow ii JF"}
local active_notes = {}

local baseFreq = 440
local position = 1
local pageNum = 1
local lineNum = 0
local edit = 1
local STEPS = 16
local cmd_sequence = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
local scaleGroup = 1
local noteSel = 1
local metronome = 1 -- 1 is off, 0 is on
local transport_tog = 0
local rate = 1
local ratchet = 2
local direction = 0
local env = 0.01

local KEYDOWN1 = 0
local viewinfo = 0

local note_pattern = {}
local rests = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local octave = 0
local offset = 20

local wave = 0.0
local decay = 1
local folds = 0.0
local verb = 0.05

local pan = 0
local delayRate = 1

local function all_notes_off()
  if params:get("out_opt") == 1 then
    for _, a in pairs(active_notes) do
      m:note_off(a, nil, midi_channel)
    end
  end
  active_notes = {}
end

-- SEQUENCE COMMANDS
function octdec() octave = util.clamp(octave - 12, -12, 12) end
function octinc() octave = util.clamp(octave + 12, -12, 12) end
function octrnd() local oct_options = {-12, 0, 12} octave = oct_options[math.random(1, 3)] end
function tempodec() rate = util.clamp(rate * 2, 0.125, 4) end
function tempoinc() rate = util.clamp(rate / 2, 0.125, 4) end
function tempotrip() rate = util.clamp(rate * 2/3, 0.125, 4) end
function tempodot() rate = util.clamp(rate + rate / 2, 0.125, 4) end
function temporeset() rate = 1 end
function nNote() note_pattern[position] = scaleNotes[scaleGroup][math.random(#scaleNotes[scaleGroup])] + offset end
function posRand() --[[position = math.random(STEPS)]] end --keep function as placeholder
function posstart() --[[if direction == 0 then position = 1 else position = 16 end]] end --keep function as placeholder
function dirForward() direction = 0 end
function dirReverse() direction = 1 end
function rest() end
function nPattern() newPattern() end

-- ENGINE COMMANDS
--function glidenote() glide = math.random() engine.glide(glide) end
function decaydec() decay = util.clamp(decay - 0.1, 0.1, 1.5) engine.decay(decay) end
function decayinc() decay = util.clamp(decay + 0.1, 0.1, 1.5) engine.decay(decay) end
function wShapedec() wave = util.clamp(wave - 0.1, 0, 0.6) engine.waveShape(wave) end
function wShapeinc() wave = util.clamp(wave + 0.1, 0, 0.6) engine.waveShape(wave) end
function wFolddec() folds = util.clamp(folds - 0.10, 0, 1) engine.waveFolds(folds) end
function wFoldinc() folds = util.clamp(folds + 0.10, 0, 1) engine.waveFolds(folds) end
function verbdec() verb = util.clamp(verb - 0.05, 0.05, 0.5) engine.reverbMix(verb) end
function verbinc() verb = util.clamp(verb + 0.05, 0.05, 0.5) engine.reverbMix(verb) end

--CROW COMMANDS
function rndvolt()
  local range = params:get("v_range")
  voltage = (math.random() * 2 - 1) * range
  crow.output[3].volts = voltage
end

function crowtrig()
  local env = params:get("env_length")
  crow.output[4].action = "{to(5, 0), to(0, "..env..")}"
  crow.output[4]()
end

--SOFTCUT COMMANDS
function panrnd() pan = (math.random() * 20 - 10) / 10 end
function rateReset() delayRate = 1 end
function rateMforward() delayRate = util.clamp(delayRate * 2, 0.5, 2) end
function rateMreverse() delayRate = util.clamp(delayRate * 2, -0.5, -2) end
function rateDforward() delayRate = util.clamp(delayRate / 2, 0.5, 2) end
function rateDreverse() delayRate = util.clamp(delayRate / 2, -0.5, -2) end
function loop_on() softcut.rec_level(1, 0) softcut.pre_level(1, 1) end
function loop_off() local pre_l = params:get("delay_feedback") softcut.rec_level(1, 1) softcut.pre_level(1, pre_l) end

local actions =
{
  octdec, octinc, octrnd, tempodec, tempoinc, temporeset, tempotrip, tempodot, rest, nNote, posRand,
  posstart, dirForward, dirReverse, nPattern, decaydec, decayinc, wShapedec,
  wShapeinc, wFolddec, wFoldinc, verbdec, verbinc, rndvolt, crowtrig, panrnd, rateReset, rateMforward,
  rateMreverse, rateDforward, rateDreverse, loop_on, loop_off
}

local COMMANDS = #actions
local REST_ACTION = 9 -- "M"
local NOT_FOUND_ACTION = 11 -- "?"

-- Labels for display
local label =
{
  "<", ">", "O", "-", "+", "=", "*", ".", "M", "N", "?", "X",
  "}", "{", "P", "d", "D", "s", "S", "f", "F", "v",
  "V", "R", "E", "±", "1", "2", "3", "4", "5", "Z", "z"
}

local description =
{
  "octave down", "octave up", "random octave", "half tempo", "double tempo", "reset tempo",
  "triplett notes", "dotted notes", "take a rest", "new random note", "random position", "reset position",
  "play forward", "play reverse", "new note pattern", "decrease decay", "increase decay", "decrease waveshape",
  "increase waveshape", "decrease wavefold", "increase wavefold", "decrease reverb", "increase reverb", "crow random voltage",
   "crow trigger", "random delay pan", "reset delay rate", "double delay rate fwd", "double delay rate rev", "half delay rate fwd",
  "half delay rate rev", "freeze delay buffer", "unfreeze delay buffer"
}

function init()
  params:add_separator("DUNES")

  --output settings
  params:add_option("audio_out", "audio output", {"off", "on"}, 2)

  params:add_option("out_opt", "external output", output_options, 1)
  params:set_action("out_opt",
  function(value)
    all_notes_off()
    if value == 4 then
      crow.ii.pullup(true)
      crow.ii.jf.mode(1)
    else crow.ii.jf.mode(0)
    end
  end)

  --midi settings
  params:add_number("midi_out_channel", "midi channel", 1, 16, 1)
  params:set_action("midi_out_channel", function(value) all_notes_off() midi_channel = value end)

  params:add_option("midi_trnsp", "midi transport", {"off", "send", "receive"}, 1)

  --scale settings
  params:add_option("scale", "scale", scaleNames, 1)
  params:set_action("scale", function(x) scaleGroup = x end)

  --save and load
  params:add_separator("save & load")

  params:add_trigger("save_seq", "< Save Sequence")
  params:set_action("save_seq", function(x) listselect.enter({"Save Command Sequence", "Save Note Pattern", "Save Both"}, function(save_mode) textentry.enter( function(new_fn) seq_save(new_fn,save_mode) end, gen_seq_filename(), "Save sequence as ...") end) end)

  params:add_trigger("load_seq", "> Load Sequence")
  params:set_action("load_seq", function(x) fileselect.enter(norns.state.data, seq_load) end)

  params:add_separator("sound")
  --halfsecond params
  hs.init()
  --passersby params
  params:add_group("passersby", 31)
  Passersby.add_params()

  --crow params
  params:add_separator("crow out 3+4")
  params:add_control("v_range", "rnd voltage range", controlspec.new(1, 5, "lin", 0.1, 5, "v"))
  params:add_control("env_length", "env length", controlspec.new(0.01, 1, "lin", 0.01, 0.05, "s"))

  engineReset()

  step_clk = clock.run(count)
  transport()

  --norns.enc.sens(1, 5)

end

function count()
  while true do
    clock.sync(rate)
    if running then
      all_notes_off()
      if direction == 0 then
        position = position + 1
        if cmd_sequence[position] == 11 then
          position = math.random(STEPS)
        elseif(position > STEPS or cmd_sequence[position] == 12) then
          position = 1
        end
      else
        position = position - 1
        if cmd_sequence[position] == 11 then
          position = math.random(STEPS)
        elseif (position < 1 or cmd_sequence[position] == 12) then
          position = 16
        end
      end
      if KEYDOWN1 == 1 and position == edit then
        --ignore action
      else
        actions[cmd_sequence[position]]()
      end
      if actions[cmd_sequence[position]] ~= actions[REST_ACTION] then
        play_note()
      end
      softcut.pan(1, pan)
      softcut.rate(1, delayRate)
      --glide = 0
      if params:get("midi_trnsp") == 2 and transport_tog == 0 then m:start() transport_tog = 1 end
      redraw()
    end
  end
end

function play_note()
  local note_num = note_pattern[position] + offset + octave
  -- engine output
  if params:get("audio_out") == 2 then
    engine.noteOn(1, (midi_to_hz(note_num)), 1)
  end
  -- midi output
  if params:get("out_opt") == 2 then
    m:note_on(note_num, 100, midi_channel)
    table.insert(active_notes, note_num)
  end
  -- crow output
  if params:get("out_opt") == 3 then
    crow.output[1].volts = ((note_num - 60) / 12)
    crow.output[2].action = "{to(5, 0), to(0, 0.1)}"
    crow.output[2]()
  end
  -- jf output
  if params:get("out_opt") == 4 then
    crow.ii.jf.play_note(((note_num - 60) / 12), 5)
  end
end

function transport()
  if metronome == 0 then
    running = true
  else
    if params:get("midi_trnsp") == 2 then m:stop() transport_tog = 0 end
    running = false
    all_notes_off()
    loop_off()
  end
end

function clock.transport.start()
  if params:get("midi_trnsp") == 3 then
    running = true
  end
end

function clock.transport.stop()
  if params:get("midi_trnsp") == 3 then
    running = false
    position = 16
    all_notes_off()
    loop_off()
  end
end

-- Labels for filename generation. Must be file safe chars!
local fn_label = {"o", "O", "-", "+", "P", "N", "Q", "E", "W", "M", "d", "D", "s", "S", "f", "F", "v", "V", "1", "2", "3", "4", "5"}

function gen_seq_filename()
  -- more vowel combos increases name variety
  vowels = {"a", "e", "i", "o", "u", "y", "hi", "ae", "ou"}
  fn = ""
  while fn == "" or util.file_exists(norns.state.data..fn..".seq") do
    for i = 1, 4 do fn = fn .. string.sub(description[cmd_sequence[math.random(16)]], 0, 1)..vowels[math.random(#vowels)] end
    -- TODO eventually someone could use all possible combos and go into a permenant loop...
  end
  return fn
end

function seq_save(fn, mode)
  local file, err = io.open(norns.state.data..fn..".seq", "w+")
  if err then print("io err:"..err) return err end
  -- Write Command Sequnce
  if mode == "Save Command Sequence" or mode == "Save Both" then
    seq = ""
    for k, v in pairs(cmd_sequence) do seq = seq..label[v] end
    file:write("CMD:"..seq.."\n")
  end
  -- Write Command Sequnce
  if mode == "Save Note Pattern" or mode == "Save Both" then
    -- First save the notes
    pattern = ""
    file:write("NOTES:")
    file:write(tostring(note_pattern[1] - offset))
    for i = 2, #note_pattern do file:write(","..tostring(note_pattern[i]-offset)) end
    file:write("\n")
    -- Save the Scale
    file:write("SCALE:"..scaleGroup)
  end
  file:close()
end

function seq_load(fn)
  print("Loading sequnce file"..fn)

  local file, err = io.open(fn, "r")
  if err then print("io err:"..err) return err end
  for line in file:lines() do
    -- split into header and sequence and check header
    seq_header, loading_string = line:match("([A-Z]*):(.*)")

    if seq_header == "CMD" then
      load_cmd_seq(loading_string)
    elseif seq_header == "NOTES" then
      load_note_pattern(loading_string)
    elseif seq_header == "SCALE" then
      --Set scale
      scaleGroup = tonumber(loading_string)
    else
      print("Error: Invalid sequence header "..(seq_header or "nil"))
    end
  end
  file:close()
end

function load_cmd_seq(loading_seq)
  --make sure the Sequnce is not too long or short and pad with "<"
  loading_seq = string.sub(loading_seq, 0, STEPS)
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
  print("Read NOTE string:"..note_string)
  new_note_pattern = {}
  note_string:gsub("([^,]+)", function(read_note)
    print("Read NOTE:"..read_note)
    table.insert(new_note_pattern,tonumber(read_note) + offset)
  end)
  note_pattern = new_note_pattern
end

function newPattern()
  for i = 1, 16 do
    table.insert(note_pattern, i, (scaleNotes[scaleGroup][math.random(#scaleNotes[scaleGroup])] + offset))
  end
end

function updateRests()
  for i = 1, #cmd_sequence do
    if cmd_sequence[i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
  end
end

function drawMenu()
  for i = 1, #pages do
    screen.move(i * 4 + 108, 8)
    screen.line_rel(1, 0)
    if i == pageNum then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.stroke()
  end
  screen.move(4, 10)
  screen.level(6)
  screen.text(pages[pageNum])
end

function drawEdit()
  for i = 1, #cmd_sequence do
    screen.level((i == edit) and 15 or 1)
    screen.move(i * 8 - 8 + 1, 60)
    screen.text(label[cmd_sequence[i]])
  end
  drawNotePattern()
end

function drawNotePattern()
  for i = 1, #cmd_sequence do
    --update rests
    if cmd_sequence[i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
    -- Draw note levels
    screen.move(i * 8 - 8 + 1, 45 - ((note_pattern[i]) / 3) + 5)
    if i == position then
      screen.level(15)
      screen.line_rel(0, 0)
    else
      if rests[i] == 1 then
        screen.level(0)
      else
        screen.level(4)
      end
    end
    screen.line_rel(4, 0)
    screen.stroke()
  end
end

function drawParams()
  local sel = viewinfo == 0
  if pageNum == 2 then
    screen.level(sel and 15 or 4)
    screen.move(4, 28)
    screen.text(params:string("delay_level"))
    screen.move(64, 28)
    screen.text(params:string("delay_length"))
    screen.level(3)
    screen.move(4, 36)
    screen.text("level")
    screen.move(64, 36)
    screen.text("rate")

    screen.level(not sel and 15 or 4)
    screen.move(4, 50)
    screen.text(params:string("delay_feedback"))
    screen.move(64, 50)
    screen.text(params:string("delay_length_ft"))
    screen.level(3)
    screen.move(4, 58)
    screen.text("feedback")
    screen.move(64, 58)
    screen.text("adjust rate")

  elseif pageNum == 3 then
    screen.level(sel and 15 or 4)
    screen.move(4, 28)
    screen.text(params:string("wave_shape"))
    screen.move(64, 28)
    screen.text(params:string("wave_folds"))
    screen.level(3)
    screen.move(4, 36)
    screen.text("wave shape")
    screen.move(64, 36)
    screen.text("wave folds")

    screen.level(not sel and 15 or 4)
    screen.move(4, 50)
    screen.text(params:string("peak"))
    screen.move(64, 50)
    screen.text(params:string("decay"))
    screen.level(3)
    screen.move(4, 58)
    screen.text("cutoff freq")
    screen.move(64, 58)
    screen.text("decay")
  end
end

function drawHelp()
  local ln = lineNum
  screen.level(15)
  screen.move(4, 20)
  for i = 1, 5 do
    screen.move(1, i * 9 + 15)
    screen.text(label[i + ln])
  end
  screen.move(16, 20)
  screen.level(4)
  for i = 1, 5 do
    screen.move(10, i * 9 + 15)
    screen.text(description[i + ln])
  end
end

function redraw()
  screen.clear()
  drawMenu()
  if pageNum == 1 then
    drawEdit()
  elseif (pageNum == 2 or pageNum == 3) then
    drawParams()
  else
    drawHelp()
  end
  screen.update()
end

function enc(n, d)
  --change page
  if n == 1 and KEYDOWN1 == 0 then
    pageNum = util.clamp(pageNum + d, 1, #pages)
  end
  --enc page 1
  if pageNum == 1 then
    if n == 1 and KEYDOWN1 == 1 then
      noteSel = util.clamp(noteSel + d, 1, #scaleNotes[scaleGroup])
      note_pattern[edit] = scaleNotes[scaleGroup][noteSel] + offset
    elseif n == 2 then
      edit = util.clamp(edit + d, 1, STEPS)
    elseif n == 3 then
      cmd_sequence[edit] = util.clamp(cmd_sequence[edit] + d, 1, COMMANDS)
      if cmd_sequence[edit] == REST_ACTION then
        rests[edit] = 1
      else
        rests[edit] = 0
      end
    end
  -- enc page 2
  elseif pageNum == 2 then
    if viewinfo == 0 then
      if n == 2 then
        params:delta("delay_level", d)
      elseif n == 3 then
        params:delta("delay_length", d)
      end
    else
      if n == 2 then
        params:delta("delay_feedback", d)
      elseif n == 3 then
        params:delta("delay_length_ft", d)
      end
    end
  -- enc page 3
  elseif pageNum == 3 then
    if viewinfo == 0 then
      if n == 2 then
        params:delta("wave_shape", d)
      elseif n == 3 then
        params:delta("wave_folds", d)
      end
    else
      if n == 2 then
        params:delta("peak", d)
      elseif n == 3 then
        params:delta("decay", d)
      end
    end
  --enc page 4
  elseif pageNum == 4 then
    if n == 2 then
      lineNum = util.clamp(lineNum + d, 0, 28)
    elseif n == 3 then
      -- do nothing for the moment (scroll through command groups?)
    end
  end
  redraw()
end

down_time = 0

function key(n, z)
  if n == 1 then KEYDOWN1 = z end

  if pageNum == 1 then
    if n == 2 then
      if z == 1 then
        if KEYDOWN1 == 0 then
          metronome = 1 - metronome
          transport()
        elseif KEYDOWN1 == 1 then
          if direction == 0 then
            position = 16
          elseif direction == 1 then
            position = 1
          end
        end
      end
    elseif n == 3 then
      if z == 1 then
        down_time = util.time()
      else
        hold_time = util.time() - down_time
        if hold_time > 1 then
          for i = 1, #cmd_sequence do
            cmd_sequence[i] = 1
          end
          engineReset()
        else
          if KEYDOWN1 == 0 then
            randomize_cmd_sequence()
          else
            for i = 1, #cmd_sequence do
              cmd_sequence[i] = 1
            end
          end
        end
        redraw()
      end
    end
elseif (pageNum == 2 or pageNum == 3) then
    if n == 2 then
      if z == 1 then
        viewinfo = 1 - viewinfo
        redraw()
      end
    end
  elseif pageNum == 4 then
    --do nothing
  end
end

function engineReset()
  rate = 1
  engine.amp(0.5)
  rests = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
  newPattern()
  wave = 0.0
  decay = 1
  folds = 0.5
  verb = 0.05
  octave = 0
  delayRate = 1
  pan = 0
  loop_off()
end

function randomize_cmd_sequence()
  for i = 1, 16 do
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
}
