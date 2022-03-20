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
--  ~~~~ DUNES ~~~~~
--
--  E1: navigate pages
--
--  PAGE 1:
--  E2: navigate to step
--  E3: select command
--  K1 [hold]: ignore command
--  K1 [hold] + E1: change note
--  K1 [hold] + K2: reset position
--  K2: stop/start
--  K3: randomize commands
--  K3 [longpress]: reset all
--  K1 + K3: reset commands
--
--  PAGE 2 & 3:
--  E2: change left parameter
--  E3: change right parameter
--  K2: toggle row
--
--  PAGE 4:
--  E2: navigate list
--

engine.name = "Passersby"
Passersby = include "passersby/lib/passersby_engine"

hs = include("lib/dunes_hs")

-- The following core libs are used to implement save and load features.
local textentry = require "textentry"
local fileselect = require "fileselect"
local listselect = require "listselect"

local mu = require "musicutil"

local m = midi.connect()
local midi_channel = 1

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local DUNES_DATA_PATH = _path.data.."dunes/"

local pages = {"SEQUENCE", "DELAY PARAMETERS", "ENGINE PARAMETERS", "COMMAND REFERENCE"}
local output_options = {"off", "midi", "crow 1+2", "crow ii JF"}
local active_notes = {}

local position = 1
local pageNum = 1
local lineNum = 0
local edit = 1
local STEPS = 16
local cmd_sequence = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
local scaleGroup = 1
local noteSel = 1
local velo_u = 100
local velo_l = 20
local metronome = 1 -- 1 is off, 0 is on
local transport_tog = 0
local rate = 1
local direction = 0
local env1_attack = 0
local env1_decay = 0.05
local env2_attack = 0
local env2_decay = 0.05

local KEYDOWN1 = 0
local viewinfo = 0

local note_pattern = {}
local rests = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local octave = 0
local offset = 20
local root = 0

local verb = 0.05

local pan = 0
local delayRate = 1

------------------------ commands and actions -------------------------

-- SEQUENCE COMMANDS
function octdec() octave = util.clamp(octave - 12, -12, 12) end
function octinc() octave = util.clamp(octave + 12, -12, 12) end
function octrnd() local oct_options = {-12, 0, 12} octave = oct_options[math.random(1, 3)] end

function tempodec() rate = util.clamp(rate * 2, 0.125, 4) end
function tempoinc() rate = util.clamp(rate / 2, 0.125, 4) end
function temporeset() rate = 1 end

function rest() end
function nNote() note_pattern[position] = scaleNotes[scaleGroup][math.random(#scaleNotes[scaleGroup])] + offset end
function nPattern() newPattern() end

function posRand() end -- keep function as placeholder
function posstart() end -- keep function as placeholder

function dirForward() direction = 0 end
function dirReverse() direction = 1 end

-- ENGINE COMMANDS
function glidenote() glide = math.random() engine.glide(glide) end

function decaydec() params:delta("decay", -1) end
function decayinc() params:delta("decay", 1) end

function wShapedec() params:delta("wave_shape", -2) end
function wShapeinc() params:delta("wave_shape", 2) end

function wFolddec() params:delta("wave_folds", -10/3) end
function wFoldinc() params:delta("wave_folds", 10/3) end

function verbdec() verb = util.clamp(verb - 0.05, 0.05, 0.5) engine.reverbMix(verb) end
function verbinc() verb = util.clamp(verb + 0.05, 0.05, 0.5) engine.reverbMix(verb) end

-- CROW COMMANDS
function rndvolt()
  local range = params:get("v_range")
  voltage = (math.random() * 2 - 1) * range
  crow.output[3].volts = voltage
end

function crowenv()
  crow.output[4].action = "{ to(0,0), to(8, "..env2_attack.."), to(0, "..env2_decay..") }"
  crow.output[4]()
end

-- SOFTCUT COMMANDS
function panrnd() pan = (math.random() * 20 - 10) / 10 softcut.pan(1, pan) end
function rateReset() delayRate = 1 end

function rateMforward() delayRate = util.clamp(delayRate * 2, 0.5, 2) end
function rateMreverse() delayRate = - util.clamp(delayRate * 2, 0.5, 2) end

function rateDforward() delayRate = util.clamp(delayRate / 2, 0.5, 2) end
function rateDreverse() delayRate = - util.clamp(delayRate / 2, 0.5, 2) end

function loop_on() softcut.rec_level(1, 0) softcut.pre_level(1, 1) end
function loop_off() local pre_l = params:get("delay_feedback") softcut.rec_level(1, 1) softcut.pre_level(1, pre_l) end

local actions =
{
  octdec, octinc, octrnd, tempodec, tempoinc, temporeset, rest, nNote,
  nPattern, posstart, posRand, dirForward, dirReverse, glidenote, decaydec, decayinc,
  wShapedec, wShapeinc, wFolddec, wFoldinc, verbdec, verbinc, rndvolt, crowenv,
  panrnd, rateReset, rateMforward, rateMreverse, rateDforward, rateDreverse, loop_on, loop_off
}

local COMMANDS = #actions
local REST_ACTION = 7
local NOT_FOUND_ACTION = 11 -- "?"
local RND_STEP = 11
local RESET_STEP = 10
local GLIDE = 14

-- Labels for display
local label =
{
  "<", ">", "O", "-", "+", "=", "M", "N", "P", "#", "?",
  "}", "{", "G", "d", "D", "s", "S", "f", "F", "v", "V",
  "R", "E", "±", "1", "2", "3", "4", "5", "Z", "z",
}

local description =
{
  "octave down", "octave up", "random octave", "half tempo", "double tempo", "reset tempo",
  "take a rest", "new random note", "new note pattern", "reset position", "random position",
  "forward direction", "reverse direction", "random glide", "decrease decay", "increase decay",
  "decrease waveshape", "increase waveshape", "decrease wavefold", "increase wavefold",
  "decrease reverb", "increase reverb", "crow random voltage", "crow trigger", "random delay pan",
  "reset delay rate", "double delay rate fwd", "double delay rate rev", "half delay rate fwd",
  "half delay rate rev", "freeze delay buffer", "unfreeze delay buffer"
}

------------------------ init -------------------------

function init()
  params:add_separator("DUNES")

  -- output settings
  params:add_option("audio_out", "audio output", {"off", "on"}, 2)

  params:add_option("ext_out", "external output", output_options, 1)
  params:set_action("ext_out",
  function(value)
    all_notes_off()
    if value == 4 then
      crow.ii.pullup(true)
      crow.ii.jf.mode(1)
    else crow.ii.jf.mode(0)
    end
  end)

  -- midi settings
  params:add_group("midi settings", 6)

  build_midi_device_list()

  params:add_option("midi_trnsp", "midi transport", {"off", "send", "receive"}, 1)

  params:add_option("set_midi_device", "midi out device", midi_devices, 1)
  params:set_action("set_midi_device", function(value) m = midi.connect(value) end)

  params:add_number("midi_out_channel", "midi channel", 1, 16, 1)
  params:set_action("midi_out_channel", function(value) all_notes_off() midi_channel = value end)

  params:add_option("vel_mode", "midi velocity", {"fixed", "random"}, 1)

  params:add_number("midi_vel_upper", "vel: max/fixed", 1, 127, 100)
  params:set_action("midi_vel_upper", function(value) velo_u = value end)

  params:add_number("midi_vel_lower", "vel: min", 1, 127, 20)
  params:set_action("midi_vel_lower", function(value) velo_l = value end)

  -- scale settings
  params:add_option("scale", "scale", scaleNames, 1)
  params:set_action("scale", function(x) scaleGroup = x end)

  params:add_number("root_note", "root note", 24, 84, 48, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", function(value) root = value - 40 end)

  params:add_option("view_note", "display notes", {"no", "yes"}, 1)

  -- save and load
  params:add_separator("save & load")

  params:add_trigger("save_seq", "< Save Sequence")
  params:set_action("save_seq", function() save_sequece() end)

  params:add_trigger("load_seq", "> Load Sequence")
  params:set_action("load_seq", function() fileselect.enter(norns.state.data, seq_load) end)

  params:add_separator("sound")
  -- delay params
  params:add_group("delay", 4)
  hs.init()
  -- passersby params
  params:add_group("passersby", 31)
  Passersby.add_params()

  -- crow params
  params:add_separator("crow")

  params:add_group("out 2: a-d envelope", 2)
  params:add_control("env1_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_attack = value end)

  params:add_control("env1_decay", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.05, "s"))
  params:set_action("env1_attack", function(value) env1_decay = value end)

  params:add_control("v_range", "out 3: rnd v-range", controlspec.new(1, 5, "lin", 0.1, 5, "v"))

  params:add_group("out 4: a-d envelope", 2)
  params:add_control("env2_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_attack = value end)

  params:add_control("env2_decay", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.05, "s"))
  params:set_action("env2_attack", function(value) env2_decay = value end)

  engineReset()

  step_clk = clock.run(count)
  transport()

  norns.enc.sens(1, 4) -- test different settings
  norns.enc.sens(3, 4)

end -- end of init

------------------------ sequencer -------------------------

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

function count()
  while true do
    clock.sync(rate)
    if running then
      if direction == 0 then
        position = position + 1
        if cmd_sequence[position] == RND_STEP then
          position = math.random(STEPS)
        elseif(position > STEPS or cmd_sequence[position] == RESET_STEP) then
          position = 1
        end
      else
        position = position - 1
        if cmd_sequence[position] == RND_STEP then
          position = math.random(STEPS)
        elseif (position < 1 or cmd_sequence[position] == RESET_STEP) then
          position = 16
        end
      end
      if params:get("midi_trnsp") == 2 and transport_tog == 0 then
        m:start()
        transport_tog = 1
      end
      trig_action()
      play_note()
      softcut.rate(1, delayRate)
      redraw()
    end
  end
end

function trig_action()
  if KEYDOWN1 == 1 and position == edit then
    -- ignore action
  else
    actions[cmd_sequence[position]]()
  end
  if actions[cmd_sequence[position]] ~= actions[GLIDE] then
    engine.glide(0)
  end
end

function play_note()
  all_notes_off()
  if actions[cmd_sequence[position]] ~= actions[REST_ACTION] then
    local note_num = note_pattern[position] + offset + octave + root
    note_name = mu.note_num_to_name(note_num, true)
    -- engine output
    if params:get("audio_out") == 2 then
      freq = mu.note_num_to_freq(note_num)
      engine.noteOn(1, freq, 1)
    end
    -- midi output
    if params:get("ext_out") == 2 then
      if params:get("vel_mode") == 2 then
        local velocity = math.random(velo_l, velo_u)
      else
        local velocity = velo_u
      end
      m:note_on(note_num, velocity, midi_channel)
      table.insert(active_notes, note_num)
    end
    -- crow output
    if params:get("ext_out") == 3 then
      crow.output[1].volts = ((note_num - 60) / 12)
      crow.output[2].action = "{ to(0,0), to(8, "..env1_attack.."), to(0, "..env1_decay..") }"
      crow.output[2]()
    end
    -- jf output
    if params:get("ext_out") == 4 then
      crow.ii.jf.play_note(((note_num - 60) / 12), 5)
    end
  end
end

function updateRests()
  for i = 1, #cmd_sequence do
    if cmd_sequence[i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
  end
end

function engineReset()
  rate = 1
  engine.amp(0.5)
  rests = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
  newPattern()
  verb = 0.05
  octave = 0
  delayRate = 1
  pan = 0
  loop_off()
end

function newPattern()
  for i = 1, 16 do
    table.insert(note_pattern, i, (scaleNotes[scaleGroup][math.random(#scaleNotes[scaleGroup])] + offset))
  end
end

function randomize_cmd_sequence()
  for i = 1, 16 do
    cmd_sequence[i] = math.random(COMMANDS)
  end
end

------------------------ midi -------------------------

function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function all_notes_off()
  for _, a in pairs(active_notes) do
    m:note_off(a, nil, midi_channel)
  end
  active_notes = {}
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

------------------------ user interface -------------------------

function enc(n, d)
  if n == 1 and KEYDOWN1 == 0 then
    pageNum = util.clamp(pageNum + d, 1, #pages)
  end
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
  elseif pageNum == 4 then
    if n == 2 then
      lineNum = util.clamp(lineNum + d, 0, COMMANDS - 5)
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
  end
end

function drawMenu()
  for i = 1, #pages do
    screen.move(i * 4 + 108, 8)
    screen.line_rel(1, 0)
    if i == pageNum then
      screen.level(15)
    else
      screen.level(2)
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
    screen.move(i * 8 - 8 + 1, 58 - ((note_pattern[i]) / 1.2) + 6)
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
  for i = 1, 5 do
    screen.move(4, i * 9 + 15)
    screen.text(label[i + ln])
  end
  screen.level(4)
  for i = 1, 5 do
    screen.move(14, i * 9 + 15)
    screen.text(description[i + ln])
  end
end

function redraw()
  screen.clear()
  drawMenu()
  if pageNum == 1 then
    drawEdit()
    screen.move(64, 10)
    screen.level(2)
    if running and params:get("view_note") == 2 then
      screen.text_center(note_name)
    end
  elseif (pageNum == 2 or pageNum == 3) then
    drawParams()
  else
    drawHelp()
  end
  screen.update()
end

------------------------ save and load files -------------------------

-- labels for filename generation. must be file safe chars!
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

function save_sequece()
  listselect.enter({"Save Command Sequence", "Save Note Pattern", "Save Both"},
  function(save_mode) textentry.enter(function(new_fn) seq_save(new_fn,save_mode) end,
  gen_seq_filename(), "Save sequence as ...") end)
end

function seq_save(fn, mode)
  local file, err = io.open(norns.state.data..fn..".seq", "w+")
  if err then print("io err:"..err) return err end
  -- write command sequnce
  if mode == "Save Command Sequence" or mode == "Save Both" then
    seq = ""
    for k, v in pairs(cmd_sequence) do seq = seq..label[v] end
    file:write("CMD:"..seq.."\n")
  end
  -- write command sequnce
  if mode == "Save Note Pattern" or mode == "Save Both" then
    -- first save the notes
    pattern = ""
    file:write("NOTES:")
    file:write(tostring(note_pattern[1] - offset))
    for i = 2, #note_pattern do file:write(","..tostring(note_pattern[i] - offset)) end
    file:write("\n")
    -- save the scale
    file:write("SCALE:"..scaleGroup)
    file:write("\n")
    -- save the root note
    file:write("ROOT:"..root)
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
      -- set scale
      scaleGroup = tonumber(loading_string)
    elseif seq_header == "ROOT" then
      -- set root note
      params:set("root_note", tonumber(loading_string) + 40)
    else
      print("Error: Invalid sequence header "..(seq_header or "nil"))
    end
  end
  file:close()
end

function load_cmd_seq(loading_seq)
  -- make sure the sequnce is not too long or short and pad with "<"
  loading_seq = string.sub(loading_seq, 0, STEPS)
  loading_seq = loading_seq .. string.rep("<", STEPS-#loading_seq)
  -- and split into a table of chars
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

------------------------ scale tables -------------------------

scaleNotes = {
  {0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31,33,35,36},
  {0,2,3,5,7,8,10,12,14,15,17,19,20,22,24,26,27,29,31,32,34,36},
  {0,2,3,5,7,9,10,12,14,15,17,19,21,22,24,26,27,29,31,33,34,36},
  {0,1,3,5,7,8,10,12,13,15,17,19,20,22,24,25,27,29,31,32,34,36},
  {0,2,4,6,7,9,11,12,14,16,18,19,21,23,24,26,28,30,31,33,35,36},
  {0,2,4,5,7,9,10,12,14,16,17,19,21,22,24,26,28,29,31,33,34,36},
  {0,3,5,7,10,12,15,17,19,22,24,27,29,31,34,36},
  {0,2,4,7,9,12,14,16,19,21,24,26,28,31,33,36},
  {0,2,5,7,10,12,14,17,19,22,24,26,29,31,34,36},
  {0,3,5,8,10,12,15,17,20,22,24,27,29,32,34,36},
  {0,2,5,7,9,12,14,17,19,21,24,26,29,31,33,36},
  {0,1,3,6,7,8,11,12,13,15,18,19,20,23,24,25,27,30,31,32,35,36},
  {0,1,4,6,7,8,11,12,13,16,18,19,20,23,24,25,28,30,31,32,35,36},
  {0,1,4,6,7,9,11,12,13,16,18,19,21,23,24,25,28,30,31,33,35,36},
  {0,1,4,5,7,8,11,12,13,16,17,19,20,23,24,25,28,29,31,32,35,36},
  {0,1,4,5,7,9,10,12,13,16,17,19,21,22,24,25,28,29,31,33,35,36},
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
