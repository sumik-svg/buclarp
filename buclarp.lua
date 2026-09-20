-- buclarp.lua
-- Organic 16th-note Buchla-style generative arpeggiator for Monome Norns
--
-- Performance Controls:
--   [Performance Mode]
--     E1: CHAOS (0-100%)
--     E2: OCTAVE (1-4)
--     E3: LENGTH (1-16)
--     K2: START / STOP
--     K3: Toggle to SETUP MODE
--
--   [Setup Mode (Press K3)]
--     E1: ROOT NOTE (C1 to C4)
--     E2: SCALE (40+ scales)
--     E3: TEMPO (30-300 BPM)
--     K3: Return to PERFORMANCE MODE

local musicutil = require("musicutil")

local midi_out
local is_running = false
local arp_clock

-- Performance parameters
local step_count = 8
local current_step = 1
local step_dir = 1
local chaos_amount = 20
local oct_range = 2

-- Step traversal internal state
local sub_step_idx = 0

-- Musical configuration (Base: C2 = 36)
local root_note = 36
local scale_names = {}
local current_scale_idx = 1
local current_scale_notes = {}

-- Modulation & state variables
local lfo_phase = 0
local lfo_sh_val = 0
local current_lfo_val = 0
local pan_is_left = false
local current_pan_val = 64

-- Active note tracker
local active_note = nil
local active_ch = 1

-- UI states
local is_settings_mode = false
local history = {}

-- Target synthesizer MIDI CC profiles
local SYNTH_PROFILES = {
  {name = "Ambient 0",    cutoff = 38, release = 41,  reso = 39, pan = 53,  has_pan = true},
  {name = "microKORG 2",  cutoff = 74, release = 72,  reso = 71, pan = 10,  has_pan = true},
  {name = "Nymphes",      cutoff = 74, release = 72,  reso = 71, pan = nil, has_pan = false},
  {name = "MicroFreak",   cutoff = 23, release = 106, reso = 83, pan = nil, has_pan = false},
  {name = "General MIDI", cutoff = 74, release = 72,  reso = 71, pan = 10,  has_pan = true},
  {name = "Custom",       cutoff = 74, release = 72,  reso = 71, pan = 10,  has_pan = true}
}

local LFO_WAVES = {"Sine", "Triangle", "Saw Down", "Saw Up", "Square", "S&H (Random)"}
local LFO_DESTS = {"Release / Decay", "Cutoff", "Resonance", "Pan", "Custom CC", "Off"}
local PAN_MODES = {"Ping-Pong Auto", "Step Pattern", "Random", "Off / Center"}
local DIR_MODES = {"Forward", "Reverse", "Ping-Pong", "2 Fwd / 1 Back", "2 Fwd / 3 Back", "Brownian", "Random"}

function init()
  for i, s in ipairs(musicutil.SCALES) do
    scale_names[i] = s.name
    if s.name == "Dorian" then
      current_scale_idx = i
    end
  end

  params:add_separator("SYNTH PROFILE & MIDI")
  local profile_names = {}
  for i, p in ipairs(SYNTH_PROFILES) do profile_names[i] = p.name end

  -- Default Target Synth set to General MIDI (index 5)
  params:add{type = "option", id = "synth_target", name = "Target Synth",
    options = profile_names, default = 5}
  params:add{type = "number", id = "midi_dev", name = "MIDI Device", min = 1, max = 16, default = 1,
    action = function(v) midi_out = midi.connect(v) end}
  params:add{type = "number", id = "midi_ch", name = "MIDI Channel", min = 1, max = 16, default = 1,
    action = function(v) active_ch = v end}

  params:add_separator("PLAYBACK CONFIG")
  params:add{type = "option", id = "step_direction", name = "Direction Mode",
    options = DIR_MODES, default = 3}

  params:add_separator("CUSTOM SYNTH CC CONFIG")
  params:add{type = "number", id = "cust_cutoff", name = "Custom Cutoff CC", min = 1, max = 127, default = 74}
  params:add{type = "number", id = "cust_release", name = "Custom Release CC", min = 1, max = 127, default = 72}
  params:add{type = "number", id = "cust_reso", name = "Custom Reso CC", min = 1, max = 127, default = 71}
  params:add{type = "option", id = "cust_has_pan", name = "Custom Pan Enable", options = {"OFF", "ON"}, default = 2}
  params:add{type = "number", id = "cust_pan", name = "Custom Pan CC", min = 1, max = 127, default = 10}

  params:add_separator("TIMING & DYNAMICS")
  params:add{type = "number", id = "gate_len", name = "Gate Length %", min = 10, max = 95, default = 60}
  params:add{type = "number", id = "default_cutoff", name = "Base Cutoff (OCT 1-3)", min = 10, max = 110, default = 60}

  params:add_separator("PAN SETTINGS")
  params:add{type = "option", id = "pan_mode", name = "Pan Mode", options = PAN_MODES, default = 1}
  params:add{type = "control", id = "pan_width", name = "Pan Width %",
    controlspec = controlspec.new(0, 100, "lin", 1, 80, "%")}

  params:add_group("STEP PAN CONFIG (1-16)", 16)
  for i = 1, 16 do
    local default_pan = (i % 2 == 1) and 32 or 96
    params:add{type = "number", id = "step_pan_" .. i, name = "Step " .. i .. " Pan",
      min = 0, max = 127, default = default_pan}
  end

  params:add_separator("LFO MODULATION")
  params:add{type = "option", id = "lfo_dest", name = "Destination", options = LFO_DESTS, default = 1}
  params:add{type = "number", id = "lfo_custom_cc", name = "Custom Target CC", min = 1, max = 127, default = 21}
  params:add{type = "option", id = "lfo_wave", name = "Waveform", options = LFO_WAVES, default = 1}
  params:add{type = "control", id = "lfo_rate", name = "Rate",
    controlspec = controlspec.new(0.02, 10.0, "exp", 0.01, 0.0625, "Hz")}
  -- Default Base / Center Value set to 0
  params:add{type = "number", id = "lfo_base", name = "Base / Center Value", min = 0, max = 127, default = 0}
  params:add{type = "control", id = "lfo_depth", name = "Depth %",
    controlspec = controlspec.new(0, 100, "lin", 1, 50, "%")}

  midi_out = midi.connect(params:get("midi_dev"))
  active_ch = params:get("midi_ch")

  kill_all_notes()
  update_scale()

  for i = 1, 16 do history[i] = root_note end

  clock.run(function()
    while true do
      clock.sleep(1/30)
      redraw()
    end
  end)
end

function get_current_cc()
  local prof_idx = params:get("synth_target")
  if prof_idx == #SYNTH_PROFILES then
    return {
      cutoff = params:get("cust_cutoff"),
      release = params:get("cust_release"),
      reso = params:get("cust_reso"),
      pan = params:get("cust_pan"),
      has_pan = (params:get("cust_has_pan") == 2)
    }
  else
    return SYNTH_PROFILES[prof_idx]
  end
end

function compute_lfo(wave_idx, phase)
  local t = phase / (2 * math.pi)
  if wave_idx == 1 then return math.sin(phase)
  elseif wave_idx == 2 then
    if t < 0.25 then return t * 4.0
    elseif t < 0.75 then return 1.0 - (t - 0.25) * 4.0
    else return -1.0 + (t - 0.75) * 4.0 end
  elseif wave_idx == 3 then return 1.0 - 2.0 * t
  elseif wave_idx == 4 then return -1.0 + 2.0 * t
  elseif wave_idx == 5 then return (t < 0.5) and 1.0 or -1.0
  elseif wave_idx == 6 then return lfo_sh_val end
  return 0.0
end

function compute_pan(step_idx)
  local mode = params:get("pan_mode")
  local width_pct = params:get("pan_width") / 100.0
  local max_swing = 63.5 * width_pct

  if mode == 1 then
    if pan_is_left then
      local min_r = math.floor(64 + (max_swing * 0.2))
      local max_r = math.floor(64 + max_swing)
      current_pan_val = math.random(min_r, math.max(min_r, max_r))
      pan_is_left = false
    else
      local min_l = math.floor(64 - max_swing)
      local max_l = math.floor(64 - (max_swing * 0.2))
      current_pan_val = math.random(math.min(min_l, max_l), max_l)
      pan_is_left = true
    end
  elseif mode == 2 then
    current_pan_val = params:get("step_pan_" .. step_idx)
  elseif mode == 3 then
    local min_p = math.floor(64 - max_swing)
    local max_p = math.floor(64 + max_swing)
    current_pan_val = math.random(min_p, max_p)
  elseif mode == 4 then
    current_pan_val = 64
  end
  return util.clamp(current_pan_val, 0, 127)
end

function wrap_step(val, max_len)
  if max_len <= 1 then return 1 end
  return ((val - 1) % max_len) + 1
end

function advance_step()
  local dir_mode = params:get("step_direction")
  if step_count <= 1 then
    current_step = 1
    return
  end

  if dir_mode == 1 then
    current_step = wrap_step(current_step + 1, step_count)
  elseif dir_mode == 2 then
    current_step = wrap_step(current_step - 1, step_count)
  elseif dir_mode == 3 then
    current_step = current_step + step_dir
    if current_step >= step_count then
      current_step = step_count
      step_dir = -1
    elseif current_step <= 1 then
      current_step = 1
      step_dir = 1
    end
  elseif dir_mode == 4 then
    sub_step_idx = (sub_step_idx % 3) + 1
    local delta = (sub_step_idx == 3) and -1 or 1
    current_step = wrap_step(current_step + delta, step_count)
  elseif dir_mode == 5 then
    sub_step_idx = (sub_step_idx % 5) + 1
    local delta = (sub_step_idx <= 2) and 1 or -1
    current_step = wrap_step(current_step + delta, step_count)
  elseif dir_mode == 6 then
    local r = math.random(1, 10)
    if r <= 5 then
      current_step = wrap_step(current_step + 1, step_count)
    elseif r <= 8 then
      current_step = wrap_step(current_step - 1, step_count)
    end
  elseif dir_mode == 7 then
    current_step = math.random(1, step_count)
  end
end

function kill_all_notes()
  if not midi_out then return end
  local ch = params:get("midi_ch") or active_ch or 1
  if active_note then
    midi_out:note_off(active_note, 0, ch)
    active_note = nil
  end
  for note = 24, 108 do
    midi_out:note_off(note, 0, ch)
  end
end

function update_scale()
  current_scale_notes = musicutil.generate_scale(root_note, scale_names[current_scale_idx], oct_range + 1)
end

function arp_loop()
  while is_running do
    local ch = params:get("midi_ch")
    local scale_len = #current_scale_notes
    local cc = get_current_cc()
    local dest_idx = params:get("lfo_dest")

    -- 1. Advance LFO
    local sec_16th = (60 / params:get("clock_tempo")) / 4
    local rate = params:get("lfo_rate")
    lfo_phase = lfo_phase + (2 * math.pi * rate * sec_16th)
    if lfo_phase >= (2 * math.pi) then
      lfo_phase = lfo_phase - (2 * math.pi)
      lfo_sh_val = (math.random() * 2.0) - 1.0
    end

    local raw_lfo = compute_lfo(params:get("lfo_wave"), lfo_phase)
    local base_val = params:get("lfo_base")
    local depth_pct = params:get("lfo_depth") / 100.0
    current_lfo_val = util.clamp(math.floor(base_val + (raw_lfo * 63.5 * depth_pct)), 0, 127)

    local target_cc = nil
    if dest_idx == 1 then target_cc = cc.release
    elseif dest_idx == 2 then target_cc = cc.cutoff
    elseif dest_idx == 3 then target_cc = cc.reso
    elseif dest_idx == 4 then if cc.has_pan then target_cc = cc.pan end
    elseif dest_idx == 5 then target_cc = params:get("lfo_custom_cc") end

    if target_cc and dest_idx ~= 6 then
      midi_out:cc(target_cc, current_lfo_val, ch)
    end

    -- 2. Step Pan Dispatch
    if dest_idx ~= 4 and cc.has_pan and cc.pan then
      local pan_val = compute_pan(current_step)
      midi_out:cc(cc.pan, pan_val, ch)
    end

    -- 3. Note determination
    local base_notes_count = (#musicutil.generate_scale(root_note, scale_names[current_scale_idx], oct_range))
    local base_idx = ((current_step - 1) % base_notes_count) + 1

    -- Buchla Chaos
    local target_idx = base_idx
    if math.random(1, 100) <= chaos_amount then
      local intervals = (chaos_amount < 40) and {2, 4} or {2, 4, 7, 9}
      local offset = intervals[math.random(1, #intervals)]
      target_idx = base_idx + offset
      if target_idx > scale_len then
        target_idx = target_idx - 7
      end
    end

    local final_note = current_scale_notes[target_idx] or current_scale_notes[base_idx]
    history[current_step] = final_note

    -- 4. Dynamic Cutoff Boost on OCT 4
    local is_oct4 = (final_note >= (root_note + 36))
    if dest_idx ~= 2 and cc.cutoff then
      if is_oct4 then
        midi_out:cc(cc.cutoff, 127, ch)
      else
        midi_out:cc(cc.cutoff, params:get("default_cutoff"), ch)
      end
    end

    -- 5. Trigger Note-On
    local vel = is_oct4 and 120 or math.random(85, 110)
    midi_out:note_on(final_note, vel, ch)
    active_note = final_note
    active_ch = ch

    -- 6. Gate duration & Note-Off
    local gate_sec = sec_16th * (params:get("gate_len") / 100)
    clock.sleep(gate_sec)

    midi_out:note_off(final_note, 0, ch)
    active_note = nil

    clock.sleep(math.max(0.01, sec_16th - gate_sec))

    -- 7. Step traversal
    advance_step()
  end
end

-- Encoder handling
function enc(n, d)
  if not is_settings_mode then
    -- === Performance Mode ===
    if n == 1 then
      chaos_amount = util.clamp(chaos_amount + d, 0, 100)
    elseif n == 2 then
      oct_range = util.clamp(oct_range + d, 1, 4)
      update_scale()
    elseif n == 3 then
      step_count = util.clamp(step_count + d, 1, 16)
    end
  else
    -- === Setup Mode (K3) ===
    if n == 1 then
      root_note = util.clamp(root_note + d, 24, 60)
      update_scale()
    elseif n == 2 then
      current_scale_idx = util.clamp(current_scale_idx + d, 1, #scale_names)
      update_scale()
    elseif n == 3 then
      local new_tempo = util.clamp(params:get("clock_tempo") + d, 30, 300)
      params:set("clock_tempo", new_tempo)
    end
  end
end

-- Key handling
function key(n, z)
  if n == 2 and z == 1 then
    is_running = not is_running
    if is_running then
      arp_clock = clock.run(arp_loop)
    else
      kill_all_notes()
    end
  elseif n == 3 and z == 1 then
    is_settings_mode = not is_settings_mode
  end
end

-- Screen rendering
function redraw()
  screen.clear()

  local cc = get_current_cc()
  local root_name = musicutil.note_num_to_name(root_note, true)
  local scale_title = root_name .. " " .. string.upper(scale_names[current_scale_idx])

  -- Header: Status & Scale only (Right side is blank)
  screen.level(is_running and 15 or 4)
  screen.move(4, 8)
  screen.text(is_running and "> RUN" or "|| STOP")

  screen.level(10)
  screen.move(45, 8)
  screen.text(string.sub(scale_title, 1, 14))

  if not is_settings_mode then
    -- === Performance View ===
    for i = 1, step_count do
      local x = (i - 1) * 7 + 8
      local n = history[i] or 36
      local h = util.linlin(24, 84, 2, 28, n)

      if i == current_step then
        screen.level(15)
        screen.rect(x, 44 - h, 5, h)
        screen.fill()

        if n >= (root_note + 36) then
          screen.move(x + 1, 41 - h)
          screen.text("*")
        end
      else
        screen.level(3)
        screen.rect(x, 44 - h, 5, h)
        screen.stroke()
      end
    end

    screen.level(12)
    screen.move(4, 55)
    screen.text("CHAOS:" .. chaos_amount .. "%")
    screen.move(56, 55)
    screen.text("OCT:" .. oct_range)
    screen.move(102, 55)
    screen.text("LEN:" .. step_count)

    -- Monitoring bar
    screen.level(6)
    screen.move(4, 63)
    local dest_name = LFO_DESTS[params:get("lfo_dest")]
    local dest_short = string.sub(dest_name, 1, 4)
    local pan_str = "PAN:OFF"
    if cc.has_pan and params:get("pan_mode") ~= 4 then
      pan_str = (current_pan_val < 64) and ("L(" .. current_pan_val .. ")") or ("R(" .. current_pan_val .. ")")
    end
    screen.text(pan_str .. " LFO[" .. dest_short .. "]:" .. current_lfo_val)

  else
    -- === Setup View (Press K3) ===
    screen.level(15)
    screen.move(4, 23)
    screen.text("[SETUP MODE]")

    screen.level(10)
    screen.move(4, 37)
    screen.text("E1 ROOT:  " .. root_name .. " (" .. root_note .. ")")
    screen.move(4, 49)
    screen.text("E2 SCALE: " .. scale_names[current_scale_idx])
    screen.move(4, 61)
    screen.text("E3 BPM:   " .. math.floor(params:get("clock_tempo")))
  end

  screen.update()
end

function cleanup()
  if arp_clock then
    clock.cancel(arp_clock)
  end
  kill_all_notes()
end