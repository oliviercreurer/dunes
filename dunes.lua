--
-- DUNES (v2.0.0)
-- function sequencer
--
-- @olivier & @sonocircuit
-- llllllll.co/t/dunes/24790
--
-- w/ contributions from
-- @justmat
-- @JaggedNZ
--
-- ~~~~~~~ QUICKSTART ~~~~~~~
--
-- E1: navigate pages
--
-- PAGE 1:
-- E2: navigate to step
-- E3: select command
-- K1 [hold]: ignore command
-- K1 [hold] + E2: change note
-- K2: stop/start
-- K1 [hold] + K2: reset position
-- K3: randomize commands
-- K1 [hold] + K3: reset commands
-- K3 [longpress]: reset all
--
-- PAGE 2 & 3:
-- E2: change left parameter
-- E3: change right parameter
-- K2: toggle row
--
-- PAGE 4:
-- E2: navigate list
--

engine.name = "Passersby"
synth = include "passersby/lib/passersby_engine"
delay = include("lib/dunes_delay")

local textentry = require "textentry"
local fileselect = require "fileselect"
local listselect = require "listselect"
local tab = require "tabutil"
local mu = require "musicutil"

local g = grid.connect()
local alt = false

local m = midi.connect()
local midi_channel = 1

local pages = {"SEQUENCE", "DELAY PARAMETERS", "SYNTH PARAMETERS", "COMMAND REFERENCE"}
local output_options = {"off", "midi", "crow 1+2", "crow ii JF"}
local active_notes = {}
local scale_names = {}
local scale_name = 1
local scale_notes = {}
local root = 1

local position = 1
local pageNum = 1
local lineNum = 0
local edit = 1
local STEPS = 16

local vel_val = 100
local velocity = 100
local velo_u = 100
local velo_l = 20

local metronome = 1 -- 1 is off, 0 is on
local transport_tog = 0
local rate = 1
local step_rate = 1
local mult = {0.5, 1, 2, 4}
local direction = 0

local v8_std = 12
local env1_a = 0
local env1_r = 0.05
local env2_a = 0
local env2_r = 0.05

local KEYDOWN1 = 0
local viewinfo = 0

local rests = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local octave = 0

local verb = 0.05
local pan = 0
local delayRate = 1

------------------------ commands and note tables -------------------------
-- command tables
local cmd_sequence = {}
for i = 1, 8 do
  cmd_sequence[i] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
end

local cmd_pset = 1
local cmd_pos = 1
local cmd_select = false

-- notes tables
local note_pattern = {}
for i = 1, 8 do
  note_pattern[i] = {}
  for j = 1, 16 do
    table.insert(note_pattern[i], j, math.random(18))
  end
end

local note_pset = 1

------------------------ commands and actions -------------------------

-- SEQUENCE COMMANDS
function octdec() octave = util.clamp(octave - 12, -12, 12) end
function octinc() octave = util.clamp(octave + 12, -12, 12) end
function octrnd() local oct_options = {-12, 0, 12} octave = oct_options[math.random(1, 3)] end

function tempodec() rate = util.clamp(rate * 2, 0.125, 4) end
function tempoinc() rate = util.clamp(rate / 2, 0.125, 4) end
function temporeset() rate = 1 end

function rest() end
function nNote() note_pattern[note_pset][position] = math.random(18) end
function nPattern() newPattern() end

function posRand() end -- keep function as placeholder
function posstart() end -- keep function as placeholder

function dirForward() direction = 0 end
function dirReverse() direction = 1 end

function rand_command() cmd_sequence[cmd_pset][math.random(16)] = math.random(33) end -- randomize command of random step

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
  crow.output[4].action = "{ to(0,0), to(8, "..env2_a.."), to(0, "..env2_r..") }"
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
  panrnd, rateReset, rateMforward, rateMreverse, rateDforward, rateDreverse,
  loop_on, loop_off, rand_command
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
  "R", "E", "X", "1", "2", "3", "4", "5", "Z", "z", "!",
}

local description =
{
  "octave down", "octave up", "random octave", "half tempo", "double tempo", "reset tempo",
  "take a rest", "new random note", "new note pattern", "reset position", "random position",
  "forward direction", "reverse direction", "random glide", "decrease decay", "increase decay",
  "decrease waveshape", "increase waveshape", "decrease wavefold", "increase wavefold",
  "decrease reverb", "increase reverb", "crow random voltage", "crow envelope", "random delay pan",
  "reset delay rate", "double delay rate fwd", "double delay rate rev", "half delay rate fwd",
  "half delay rate rev", "freeze delay buffer", "unfreeze delay buffer", "rnd cmd @ rnd pos"
}

------------------------ init -------------------------

function init()
  params:add_separator("DUNES")

  -- output settings
  params:add_group("output settings", 3)
  params:add_option("audio_out", "audio output", {"off", "on"}, 2)

  params:add_option("ext_out", "external output", output_options, 1)
  params:set_action("ext_out", function(value) all_notes_off() set_jfmode(value) end)

  params:add_option("clock_mult", "clock mult", {0.5, 1, 2, 4}, 2)
  params:set_action("clock_mult", function(idx) step_rate = mult[idx] end)
  params:hide("clock_mult")

  -- midi settings
  params:add_group("midi settings", 6)

  build_midi_device_list()

  params:add_option("set_midi_device", "midi device", midi_devices, 1)
  params:set_action("set_midi_device", function(value) m = midi.connect(value) end)

  params:add_number("midi_out_channel", "midi channel", 1, 16, 1)
  params:set_action("midi_out_channel", function(value) all_notes_off() midi_channel = value end)

  params:add_option("midi_trnsp", "midi transport", {"off", "send", "receive"}, 1)

  params:add_option("vel_mode", "velocity mode", {"fixed", "random"}, 1)

  params:add_number("midi_vel_val", "velocity value", 1, 127, 100)
  params:set_action("midi_vel_val", function(value) vel_val = value set_vel_range() end)

  params:add_number("midi_vel_range", "velocity range ±", 1, 127, 20)
  params:set_action("midi_vel_range", function() set_vel_range() end)

  -- scale settings
  params:add_group("scale settings", 3)

  -- populate scale_names table
  for i = 1, #mu.SCALES do
    table.insert(scale_names, string.lower(mu.SCALES[i].name))
  end

  params:add_option("scale", "scale", scale_names, 1)
  params:set_action("scale", function(val) build_scale() scale_name = val end)

  params:add_number("root_note", "root note", 24, 84, 48, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", function(val) build_scale() root = val end)

  params:add_option("view_note", "display notes", {"no", "yes"}, 1)

  -- save and load
  params:add_group("save & load", 2)
  params:add_trigger("save_seq", "< Save Sequence")
  params:set_action("save_seq", function() save_sequece() end)

  params:add_trigger("load_seq", "> Load Sequence")
  params:set_action("load_seq", function() fileselect.enter(norns.state.data.."sequences", seq_load) end) -- change directory: add subfolder
  -- sound params
  params:add_separator("sound")
  -- delay params
  params:add_group("delay", 4)
  delay.init()
  -- passersby params
  params:add_group("synth", 31)
  synth.add_params()

  -- crow params
  params:add_separator("crow")

  params:add_option("v8_type", "out 1: v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type", function(x) if x == 1 then v8_std = 12 else v8_std = 10 end end)

  params:add_group("out 2: envelope", 2)
  params:add_control("env1_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_a = value end)

  params:add_control("env1_release", "release", controlspec.new(0.01, 1, "lin", 0.01, 0.05, "s"))
  params:set_action("env1_release", function(value) env1_r = value end)

  params:add_control("v_range", "out 3: rnd v-range", controlspec.new(1, 5, "lin", 0.1, 5, "v"))

  params:add_group("out 4: envelope", 2)
  params:add_control("env2_attack", "attack", controlspec.new(0.00, 4, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_a = value end)

  params:add_control("env2_release", "release", controlspec.new(0.01, 4, "lin", 0.01, 0.05, "s"))
  params:set_action("env2_release", function(value) env2_r = value end)

  engineReset()

  params:bang()

  step_clk = clock.run(count)
  transport()

  grid.add = draw_grid_connected

  redrawtimer = metro.init(redraw_fun, 0.02, -1) -- refresh rate at 50hz
  redrawtimer:start()
  dirtygrid = true
  dirtyscreen = true

  norns.enc.sens(1, 5)
  norns.enc.sens(3, 4)
  norns.enc.sens(3, 4)

  -- pset callback
  params.action_write = function(filename, name)
    os.execute("mkdir -p "..norns.state.data.."presets/")
    local note_presets = {}
    local cmd_presets = {}
    for i = 1, 8 do
      note_presets[i] = {table.unpack(note_pattern[i])}
      cmd_presets[i] = {table.unpack(cmd_sequence[i])}
    end
    tab.save(note_presets, norns.state.data.."presets/"..name.."_note_presets.data")
    tab.save(cmd_presets, norns.state.data.."presets/"..name.."_cmd_presets.data")
    print("finished writing '"..filename.."' as '"..name.."'")
  end

  params.action_read = function(filename)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      -- load note patterns
      note_presets = tab.load(norns.state.data.."presets/"..pset_id.."_note_presets.data")
      note_pattern = {}
      for i = 1, 8 do
        note_pattern[i] = {table.unpack(note_presets[i])}
      end
      -- load cmd sequences
      cmd_presets = tab.load(norns.state.data.."presets/"..pset_id.."_cmd_presets.data")
      cmd_sequence = {}
      for i = 1, 8 do
        cmd_sequence[i] = {table.unpack(cmd_presets[i])}
      end
      print("finished reading '"..filename.."'")
    else
      print("ERROR pset callback")
    end
  end

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
    clock.sync(rate / step_rate)
    if running then
      if direction == 0 then
        position = position + 1
        if cmd_sequence[cmd_pset][position] == RND_STEP then
          position = math.random(STEPS)
        elseif(position > STEPS or cmd_sequence[cmd_pset][position] == RESET_STEP) then
          position = 1
        end
      else
        position = position - 1
        if cmd_sequence[cmd_pset][position] == RND_STEP then
          position = math.random(STEPS)
        elseif (position < 1 or cmd_sequence[cmd_pset][position] == RESET_STEP) then
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
      dirtyscreen = true
      dirtygrid = true
    end
  end
end

function trig_action()
  if KEYDOWN1 == 1 and position == edit then
    -- ignore action
  else
    actions[cmd_sequence[cmd_pset][position]]()
  end
  if actions[cmd_sequence[cmd_pset][position]] ~= actions[GLIDE] then
    engine.glide(0)
  end
end

function play_note()
  all_notes_off()
  if actions[cmd_sequence[cmd_pset][position]] ~= actions[REST_ACTION] then
    local note_num = scale_notes[note_pattern[note_pset][position]] + octave
    note_name = mu.note_num_to_name(note_num, true)
    -- engine output
    if params:get("audio_out") == 2 then
      freq = mu.note_num_to_freq(note_num)
      engine.noteOn(1, freq, 1)
    end
    -- midi output
    if params:get("ext_out") == 2 then
      if params:get("vel_mode") == 2 then
        velocity = math.random(velo_l, velo_u)
      else
        velocity = vel_val
      end
      m:note_on(note_num, velocity, midi_channel)
      table.insert(active_notes, note_num)
    end
    -- crow output
    if params:get("ext_out") == 3 then
      crow.output[1].volts = ((note_num - 60) / v8_std)
      crow.output[2].action = "{ to(0, 0), to(8, "..env1_a.."), to(0, "..env1_r..", 'exponential') }"
      crow.output[2]()
    end
    -- jf output
    if params:get("ext_out") == 4 then
      crow.ii.jf.play_note(((note_num - 60) / 12), 5)
    end
  end
end

function set_jfmode(mode)
  if mode == 4 then
    crow.ii.pullup(true)
    crow.ii.jf.mode(1)
  else crow.ii.jf.mode(0)
  end
end

function updateRests()
  for i = 1, #cmd_sequence[cmd_pset] do
    if cmd_sequence[cmd_pset][i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
  end
end

function engineReset()
  step_rate = 1
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
    table.insert(note_pattern[note_pset], i, math.random(18))
  end
end

function randomize_cmd_sequence()
  for i = 1, 16 do
    cmd_sequence[cmd_pset][i] = math.random(COMMANDS)
  end
end

function build_scale()
  scale_notes = mu.generate_scale_of_length(params:get("root_note"), params:get("scale"), 18)
  local num_to_add = 18 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[18 - num_to_add])
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

function midi.add() -- this gets called when a MIDI device is registered
  build_midi_device_list()
end

function midi.remove() -- this gets called when a MIDI device is removed
  clock.run(
    function()
      clock.sleep(0.2)
        build_midi_device_list()
    end
  )
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

function all_notes_off()
  for _, a in pairs(active_notes) do
    m:note_off(a, nil, midi_channel)
  end
  active_notes = {}
end

function set_vel_range()
  local range = params:get("midi_vel_range")
  velo_l = util.clamp(vel_val - range, 1, 127)
  velo_u = util.clamp(vel_val + range, 1, 127)
end

------------------------ norns interface -------------------------

function enc(n, d)
  if n == 1 and KEYDOWN1 == 0 then
    pageNum = util.clamp(pageNum + d, 1, #pages)
  end
  if pageNum == 1 then
    if n == 2 and KEYDOWN1 == 1 then
      note_pattern[note_pset][edit] = util.clamp(note_pattern[note_pset][edit] + d, 1, 18)
    elseif n == 2 and KEYDOWN1 == 0 then
      edit = util.clamp(edit + d, 1, STEPS)
    elseif n == 3 then
      cmd_sequence[cmd_pset][edit] = util.clamp(cmd_sequence[cmd_pset][edit] + d, 1, COMMANDS)
      if cmd_sequence[cmd_pset][edit] == REST_ACTION then
        rests[edit] = 1
      else
        rests[edit] = 0
      end
    end
    dirtygrid = true
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
  dirtyscreen = true
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
          for i = 1, #cmd_sequence[cmd_pset] do
            cmd_sequence[cmd_pset][i] = 1
          end
          engineReset()
        else
          if KEYDOWN1 == 0 then
            randomize_cmd_sequence()
          else
            for i = 1, #cmd_sequence[cmd_pset] do
              cmd_sequence[cmd_pset][i] = 1
            end
          end
        end
        dirtyscreen = true
        dirtygrid = true
      end
    end
elseif (pageNum == 2 or pageNum == 3) then
    if n == 2 then
      if z == 1 then
        viewinfo = 1 - viewinfo
        dirtyscreen = true
      end
    end
  end
end

function drawMenu()
  for i = 1, #pages do
    screen.move(i * 5 + 105, 8)
    screen.line_rel(3, 0)
    screen.line_width(3)
    if i == pageNum then
      screen.level(15)
    else
      screen.level(2)
    end
    screen.stroke()
  end
  screen.move(1, 10)
  screen.level(6)
  screen.text(pages[pageNum])
end

function drawEdit()
  for i = 1, #cmd_sequence[cmd_pset] do
    screen.level((i == edit) and 15 or 1)
    screen.line_width(2)
    screen.move(i * 8 - 8 + 1, 60)
    screen.text(label[cmd_sequence[cmd_pset][i]])
  end
  drawNotePattern()
end

function drawNotePattern()
  for i = 1, #cmd_sequence[cmd_pset] do
    --update rests
    if cmd_sequence[cmd_pset][i] == REST_ACTION then rests[i] = 1 else rests[i] = 0 end
    -- Draw note levels
    screen.move(i * 8 - 8 + 1, 52 - ((note_pattern[note_pset][i]) * 2))
    if i == position then
      screen.level(15)
      screen.line_width(2)
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

------------------------ grid interface -------------------------

function g.key(x, y, z)
  -- alt key
  if x == 16 and y == 8 then
    alt = z == 1 and true or false
  end
  -- press keys then do stuff
  if z == 1 then
    -- transport key
    if x == 1 and y == 8 then
      metronome = 1 - metronome
      transport()
    end
    -- set position
    if alt and y == 4 then
      position = x
    end
    -- set commands
    if y == 4 and cmd_select then
      cmd_sequence[cmd_pset][x] = cmd_pos
    end
    -- set cmd_pos
    if (y == 1 or y == 2) then
      local n = (y - 1) * 16
      cmd_select = true
      cmd_pos = x + n
    end
    -- note pattern preset
    if x > 2 and x < 7 then
      local i = (x - 2)
      if y == 6 then
        if alt == true then
          note_pattern[i] = {table.unpack(note_pattern[note_pset])}
        elseif alt == false then
          note_pset = i
        end
      elseif y == 7 then
        if alt == true then
          note_pattern[i + 4] = {table.unpack(note_pattern[note_pset])}
        elseif alt == false then
          note_pset = i + 4
        end
      end
    end
    -- cmd pattern preset
    if x > 10 and x < 15 then
      local i = (x - 10)
      if y == 6 then
        if alt == true then
          cmd_sequence[i] = {table.unpack(cmd_sequence[cmd_pset])}
          updateRests()
        elseif alt == false then
          cmd_pset = i
        end
      elseif y == 7 then
        if alt == true then
          cmd_sequence[i + 4] = {table.unpack(cmd_sequence[cmd_pset])}
          updateRests()
        elseif alt == false then
          cmd_pset = i + 4
        end
      end
    end
    if y == 6 then
      if x == 8 then direction = 1
      elseif x == 9 then direction = 0
      end
    end
  if x > 6 and x < 11 then
    if y == 8 then
      params:set("clock_mult", x - 6)
    end
  end
  else -- end z == 1
    if (y == 1 or y == 2) then
      cmd_select = false
    end
  end
  dirtygrid = true
end

function gridredraw()
  g:all(0)
  -- alt key
  g:led(16, 8, 4)
  if alt then g:led(16, 8, 15) end
  -- transport key
  g:led(1, 8, 4)
  if metronome == 0 then g:led(1, 8, 15) end
  -- cmd rows
  local cmd_pos = cmd_sequence[cmd_pset][position]
  for i = 1, 16 do
    for j = 1, 2 do
      g:led(i, j, 3)
    end
  end
  if cmd_pos <= 16 then
    g:led(cmd_pos, 1, 6)
  elseif cmd_pos > 16 and cmd_pos < 33 then
    g:led(cmd_pos - 16, 2, 6)
  end
  -- seq row
  for i = 1, 16 do
    g:led(i, 4, 2)
  end
  g:led(position, 4, 10)
  -- direction
  g:led(8, 6, direction == 1 and 10 or 4)
  g:led(9, 6, direction == 0 and 10 or 4)
  -- note pattern presets
  for i = 3, 6 do
    for j = 6, 7 do
      g:led(i, j, 2)
    end
  end
  if note_pset < 5 then
    g:led(note_pset + 2, 6, 6)
  else
    g:led(note_pset - 2, 7, 6)
  end
  -- cmd pattern presets
  for i = 11, 14 do
    for j = 6, 7 do
      g:led(i, j, 2)
    end
  end
  if cmd_pset < 5 then
    g:led(cmd_pset + 10, 6, 6)
  else
    g:led(cmd_pset - 10, 7, 6)
  end
  for i = 1, 4 do
    g:led(i + 6, 8, 2)
  end
  g:led(params:get("clock_mult") + 6, 8, 8)
  -- refresh
  g:refresh()
  redraw()
end

------------------------ save and load single patterns -------------------------

function gen_seq_filename()
  -- more vowel combos increases name variety
  vowels = {"a", "e", "i", "o", "u", "y", "hi", "ae", "ou"}
  fn = ""
  while fn == "" or util.file_exists(norns.state.data.."sequences/"..fn..".seq") do -- change directory: add subfolder
    for i = 1, 4 do fn = fn .. string.sub(description[cmd_sequence[cmd_pset][math.random(16)]], 0, 1)..vowels[math.random(#vowels)] end
    -- TODO eventually someone could use all possible combos and go into a permenant loop...
  end
  return fn
end

function save_sequece()
  listselect.enter({"Save Command Sequence", "Save Note Pattern", "Save Both"},
  function(save_mode) textentry.enter(function(new_fn) seq_save(new_fn, save_mode) end,
  gen_seq_filename(), "Save sequence as ...") end)
  os.execute("mkdir -p "..norns.state.data.."sequences/")
end

-- !!! cmd labels seq_save must be file safe characters !!! --

function seq_save(fn, mode)
  local file, err = io.open(norns.state.data.."sequences/"..fn..".seq", "w+") -- change directory: add subfolder
  if err then print("io err:"..err) return err end
  -- write command sequnce
  if mode == "Save Command Sequence" or mode == "Save Both" then
    seq = ""
    for k, v in pairs(cmd_sequence[cmd_pset]) do seq = seq..label[v] end
    file:write("CMD:"..seq.."\n")
  end
  -- write note sequnce
  if mode == "Save Note Pattern" or mode == "Save Both" then
    -- first save the notes
    pattern = ""
    file:write("NOTES:")
    file:write(tostring(note_pattern[note_pset][1]))
    for k = 2, #note_pattern[note_pset] do
      file:write(","..tostring(note_pattern[note_pset][k]))
    end
    file:write("\n")
    -- save the scale
    file:write("SCALE:"..scale_name)
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
      params:set("scale", tonumber(loading_string))
    elseif seq_header == "ROOT" then
      -- set root note
      params:set("root_note", tonumber(loading_string))
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
  loading_seq:gsub(".", function(chr)
    -- Find the index of each step of the cmd sequence and insert into the current seqence
    action = tab.key(label, chr) or NOT_FOUND_ACTION
    table.insert(new_cmd_sequence, action)
  end)
  -- replace current sequence with laoded sequence
  if #new_cmd_sequence == STEPS then
    cmd_sequence[cmd_pset] = {table.unpack(new_cmd_sequence)}
    updateRests()
    print("command sequence loaded to slot "..cmd_pset)
  else
    print("Error: Sequence was not the correct length after parsing.")
  end
end

function load_note_pattern(note_string)
  --print("Read NOTE string:"..note_string)
  new_note_pattern = {}
  note_string:gsub("([^,]+)", function(read_note)
    table.insert(new_note_pattern, tonumber(read_note))
  end)
  note_pattern[note_pset] = {table.unpack(new_note_pattern)}
  print("note pattern loaded to slot "..note_pset)
end

------------------------ redraw handlers and cleanup -------------------------

function redraw_fun()
 if dirtygrid == true then
   gridredraw()
   dirtygrid = false
 end
 if dirtyscreen == true then
   redraw()
   dirtyscreen = false
 end
end

function draw_grid_connected()
 dirtygrid = true
 gridredraw()
end

function cleanup()
  grid.add = function() end
end
