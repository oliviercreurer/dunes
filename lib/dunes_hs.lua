--synced softcut delay based on halfsecond

local sc = {}

local div_options = {1/16, 1/12, 3/32, 1/8, 1/6, 3/16, 1/4, 1/3, 3/8, 1/2, 2/3, 3/4, 1}
local div_view = {"1/16", "1/12", "3/32", "1/8", "1/6", "3/16", "1/4","1/3", "3/8", "1/2", "2/3", "3/4", "1"}

function sc.init()
	audio.level_cut(1.0)
	audio.level_adc_cut(1)
	audio.level_eng_cut(1)
  softcut.level(1,1.0)
  softcut.level_slew_time(1,0.25)
	softcut.level_input_cut(1, 1, 1.0)
	softcut.level_input_cut(2, 1, 1.0)
	softcut.pan(1, 0)

  softcut.play(1, 1)
	softcut.rate(1, 1)
  softcut.rate_slew_time(1,0)
	softcut.loop_start(1, 1)
	softcut.loop_end(1, 1)
	softcut.loop(1, 1)
	softcut.fade_time(1, 0.1)
	softcut.rec(1, 1)
	softcut.rec_level(1, 1)
	softcut.pre_level(1, 0.75)
	softcut.position(1, 1)
	softcut.enable(1, 1)

	softcut.filter_dry(1, 0.125);
	softcut.filter_fc(1, 1200);
	softcut.filter_lp(1, 0);
	softcut.filter_bp(1, 1.0);
	softcut.filter_rq(1, 2.0);

  --params:add_separator()
  params:add_group("delay", 4)
  params:add_control("delay_level", "delay level", controlspec.new(0, 1, 'lin' , 0, 0, ""))
  params:set_action("delay_level", function(x) softcut.level(1, x) end)

  params:add_option("delay_length", "delay rate", div_view, 7)
  params:set_action("delay_length", function() set_del_rate() end)

  params:add_control("delay_length_ft", "adjust rate ", controlspec.new(-10.0, 10.0, 'lin', 0.1, 0, "%"))
  params:set_action("delay_length_ft", function() set_del_rate() end)

  params:add_control("delay_feedback", "delay feedback", controlspec.new(0, 1.0, 'lin', 0 , 0.30 ,""))
  params:set_action("delay_feedback", function(x) softcut.pre_level(1, x) end)

  dly_clk = clock.run(clock_update_rate)

end

local prev_tempo = params:get("clock_tempo")
function clock_update_rate()
 while true do
   clock.sync(1/24)
   local curr_tempo = params:get("clock_tempo")
   if prev_tempo ~= curr_tempo then
     prev_tempo = curr_tempo
     set_del_rate()
   end
 end
end

function set_del_rate()
	local tempo = params:get("clock_tempo")
	local idx = params:get("delay_length")
	local percent = params:get("delay_length_ft")
	local del_rate = ((60 / tempo) * div_options[idx] * 4) + 1
	local finetune = del_rate * (percent / 100)
	local set_rate = del_rate + finetune
	softcut.loop_end(1, set_rate)
end

return sc
