-- atlas eclipticalis
-- norns script inspired by john cage's atlas eclipticalis

engine.name = 'Atlas'

local Stars = include 'lib/stars'
local UI    = include 'lib/ui'
local midi  = require 'midi'

-- -------------------------------------------------------------------------
-- State

local state = {
  pan_x      = 0,
  pan_y      = 200,
  zoom       = 2.0,
  mode       = "auto",    -- "auto" | "cursor"
  playing    = false,
  playhead_x = 0.0,
  density    = 0.45,
  blink      = false,
  debug      = true,      -- on by default while we diagnose
  year = 2000, month = 1, day = 1,
  flash_times = {},
}

-- Debug / instrumentation, surfaced on screen
local dbg = {
  fps        = 0,
  trig_count = 0,
  last_note  = 0,
  last_freq  = 0,
  eng_ok     = true,
  eng_err    = "",
  midi_name  = "?",
  midi_ok    = true,
  midi_err   = "",
  visible    = 0,
}
state.dbg = dbg

local sky              = {}
local triggered        = {}
local k_held           = {false, false, false}
local k1_modifier_used = false
local k2_modifier_used = false
local midi_out
local update_clock_id
local note_off_clocks  = {}
local last_time        = 0
local blink_acc        = 0

-- -------------------------------------------------------------------------
-- Safe wrappers — these MUST NEVER throw, so the update loop can't die

local function safe_engine_note(freq, amp, pan, sus, rel)
  local ok, err = pcall(engine.note, freq, amp, pan, sus, rel)
  dbg.eng_ok = ok
  if not ok then dbg.eng_err = tostring(err) end
end

local function safe_note_on(note, vel, ch)
  if not midi_out then
    dbg.midi_ok = false; dbg.midi_err = "no device"; return
  end
  local ok, err = pcall(midi_out.note_on, midi_out, note, vel, ch)
  dbg.midi_ok = ok
  if not ok then dbg.midi_err = tostring(err) end
end

local function safe_note_off(note, ch)
  if not midi_out then return end
  pcall(midi_out.note_off, midi_out, note, 0, ch)
end

local function connect_midi(n)
  local ok, dev = pcall(midi.connect, n)
  if ok and dev then
    midi_out      = dev
    dbg.midi_name = dev.name or ("vport " .. n)
    dbg.midi_ok   = true
    dbg.midi_err  = ""
  else
    midi_out      = nil
    dbg.midi_ok   = false
    dbg.midi_err  = tostring(dev)
  end
end

-- -------------------------------------------------------------------------
-- Helpers

local function screen_x(star)
  local dvx = star.vx - state.pan_x
  dvx = ((dvx % Stars.FIELD_W) + Stars.FIELD_W) % Stars.FIELD_W
  if dvx > Stars.FIELD_W / 2 then dvx = dvx - Stars.FIELD_W end
  return dvx * state.zoom
end

local function rebuild()
  sky       = Stars.compute()
  state.year  = params:get("year")
  state.month = params:get("month")
  state.day   = params:get("day")
  triggered   = {}
end

local function pitch_from_sy(sy)
  local t    = 1 - util.clamp(sy / 63, 0, 1)
  local note = math.floor(params:get("pitch_base") + t * params:get("pitch_range"))
  return util.midi_to_hz(note), note
end

-- -------------------------------------------------------------------------
-- Note triggering

local function trigger_star(star)
  state.flash_times[star.id] = util.time()

  local sx       = screen_x(star)
  local sy       = (star.vy - state.pan_y) * state.zoom
  local freq, note = pitch_from_sy(sy)
  local amp      = util.clamp(0.2 + star.brightness * 0.65, 0.05, 0.9)
  local pan      = util.clamp((sx / 64) - 1, -1, 1)

  safe_engine_note(freq, amp * params:get("volume"), pan, 1.5, 2.0)

  dbg.trig_count = dbg.trig_count + 1
  dbg.last_note  = note
  dbg.last_freq  = freq

  local vel = math.floor(util.clamp(amp * 115 + 12, 1, 127))
  local ch  = params:get("midi_channel")
  safe_note_on(note, vel, ch)
  local cid = clock.run(function()
    clock.sleep(1.5)
    safe_note_off(note, ch)
  end)
  table.insert(note_off_clocks, cid)
end

local function trigger_range(lo, hi)
  for _, star in ipairs(sky) do
    if star.dice <= state.density and not triggered[star.id] then
      local sx = screen_x(star)
      if sx >= lo and sx <= hi then
        trigger_star(star)
        triggered[star.id] = true
      end
    end
  end
end

-- -------------------------------------------------------------------------
-- Update loop — ~33 fps, delta-time based

local function update_frame()
  local now = util.time()
  local dt  = math.min(now - last_time, 0.1)
  last_time = now
  if dt > 0 then dbg.fps = math.floor(1 / dt + 0.5) end

  blink_acc = blink_acc + dt
  if blink_acc >= 0.5 then
    blink_acc = blink_acc - 0.5
    state.blink = not state.blink
    for id, t in pairs(state.flash_times) do
      if now - t > 1.0 then state.flash_times[id] = nil end
    end
  end

  if state.mode == "auto" and state.playing then
    local prev_x = state.playhead_x
    state.playhead_x = state.playhead_x + params:get("scan_speed") * dt

    if state.playhead_x > 127 then
      trigger_range(prev_x, 127)
      state.pan_x = (state.pan_x + 128.0 / state.zoom) % Stars.FIELD_W
      state.playhead_x = state.playhead_x - 128
      triggered = {}
      trigger_range(0, state.playhead_x)
    else
      trigger_range(prev_x, state.playhead_x)
    end
  end

  redraw()
end

function redraw()
  UI.draw(sky, state)
end

-- -------------------------------------------------------------------------
-- Norns callbacks

function init()
  local t = os.date("*t")

  params:add_separator("ATLAS ECLIPTICALIS")
  params:add_number("year",  "Year",      2000, 2100, t.year)
  params:add_number("month", "Month",     1,    12,   t.month)
  params:add_number("day",   "Day",       1,    31,   t.day)
  params:add_number("hour",  "Hour",      0,    23,   t.hour)
  params:add_number("lat",   "Latitude",  -90,  90,   48)
  params:add_number("lon",   "Longitude", -180, 180,  2)

  params:add_separator("SOUND")
  params:add_control("scan_speed",  "Scan Speed",  controlspec.new(1,  60, 'lin', 0.5, 24,  "px/s"))
  params:add_control("pitch_base",  "Pitch Base",  controlspec.new(24, 84, 'lin', 1,   48,  "midi"))
  params:add_control("pitch_range", "Pitch Range", controlspec.new(1,  48, 'lin', 1,   24,  "semi"))
  params:add_control("volume",      "Volume",      controlspec.new(0,   1, 'lin', 0.01, 0.7, ""))
  params:add_number("midi_channel", "MIDI Channel", 1, 16, 1)
  params:add_number("midi_device",  "MIDI Device",  1, 16, 1)

  local function sky_action() rebuild() end
  for _, p in ipairs({"year","month","day","hour","lat","lon"}) do
    params:set_action(p, sky_action)
  end

  Stars.load()

  params:read()
  params:bang()

  connect_midi(params:get("midi_device"))
  params:set_action("midi_device", function(v) connect_midi(v) end)

  local px, py = Stars.default_pan(
    params:get("year"), params:get("month"), params:get("day"), params:get("hour"),
    params:get("lat"), params:get("lon")
  )
  state.pan_x = px
  state.pan_y = py

  rebuild()

  last_time = util.time()
  update_clock_id = clock.run(function()
    while true do
      clock.sleep(1/33)
      update_frame()
    end
  end)
end

function enc(n, d)
  if n == 1 then
    if k_held[1] then
      k1_modifier_used = true
      state.pan_y = util.clamp(state.pan_y + d * (3.0 / state.zoom),
                               0, Stars.FIELD_H - 64)
    else
      local old_pan_x = state.pan_x
      state.pan_x = ((state.pan_x + d * (3.0 / state.zoom)) % Stars.FIELD_W
                     + Stars.FIELD_W) % Stars.FIELD_W

      if state.mode == "cursor" then
        for _, star in ipairs(sky) do
          if star.dice <= state.density then
            local dvx_old = star.vx - old_pan_x
            dvx_old = ((dvx_old % Stars.FIELD_W) + Stars.FIELD_W) % Stars.FIELD_W
            if dvx_old > Stars.FIELD_W / 2 then dvx_old = dvx_old - Stars.FIELD_W end
            local sx_old = dvx_old * state.zoom
            local sx_new = screen_x(star)
            local lo = math.min(sx_old, sx_new)
            local hi = math.max(sx_old, sx_new)
            if lo <= 64 and hi >= 64 then trigger_star(star) end
          end
        end
      end
    end

  elseif n == 2 then
    if k_held[2] then
      k2_modifier_used = true
      state.density = util.clamp(state.density + d * 0.04, 0.04, 1.0)
    else
      local factor = d > 0 and 1.06 or (1 / 1.06)
      for _ = 1, math.abs(d) do
        state.zoom = util.clamp(state.zoom * factor, 0.3, 8.0)
      end
    end

  elseif n == 3 then
    params:set("pitch_range", util.clamp(params:get("pitch_range") + d, 1, 48))
  end
end

function key(n, z)
  k_held[n] = (z == 1)

  if n == 1 then
    if z == 1 then
      k1_modifier_used = false
    elseif not k1_modifier_used then
      state.debug = not state.debug
    end

  elseif n == 2 then
    if z == 1 then
      k2_modifier_used = false
    elseif not k2_modifier_used then
      if state.mode == "auto" then
        state.mode    = "cursor"
        state.playing = false
      else
        state.mode = "auto"
      end
    end

  elseif n == 3 and z == 1 then
    if state.mode == "auto" then
      state.playing = not state.playing
      if state.playing then
        triggered = {}
        last_time = util.time()
      end
    end
  end
end

function cleanup()
  if update_clock_id then clock.cancel(update_clock_id) end
  for _, cid in ipairs(note_off_clocks) do
    clock.cancel(cid)
  end
  note_off_clocks = {}
end
