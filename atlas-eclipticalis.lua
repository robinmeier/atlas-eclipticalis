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
  mode       = "auto",
  playing    = false,
  playhead_x = 0.0,
  density    = 0.45,
  blink      = false,
  debug      = true,
  year = 2000, month = 1, day = 1,
  flash_times = {},
}

local dbg = {
  fps = 0, dt = 0,
  sky_n = 0, active_n = 0, visible_n = 0,
  trig_count = 0, last_note = 0, last_freq = 0,
  eng_ok = true,  eng_err  = "",
  midi_name = "none", midi_ok = true, midi_err = "",
  frame_err = "",
}
state.dbg = dbg

local sky              = {}
local triggered        = {}
local k_held           = {false, false, false}
local k1_mod_used      = false
local k2_mod_used      = false
local midi_out
local update_clock_id
local note_off_metro
local note_off_queue   = {}
local last_time        = 0
local blink_acc        = 0

-- -------------------------------------------------------------------------
-- Error helper: extract readable message from a Lua traceback string

local function short_err(e)
  local s = tostring(e)
  -- "file.lua:NN: message" -> grab just "message"
  return (s:match(":%d+: (.+)$") or s:sub(-36)):sub(1, 36)
end

-- -------------------------------------------------------------------------
-- Safe wrappers

local function safe_engine_note(freq, amp, pan, sus, rel)
  if not engine.note then
    dbg.eng_ok = false; dbg.eng_err = "cmd nil"
    return
  end
  local ok, err = pcall(function() engine.note(freq, amp, pan, sus, rel) end)
  dbg.eng_ok = ok
  if not ok then dbg.eng_err = short_err(err) end
end

local function safe_note_on(note, vel, ch)
  if not midi_out then
    dbg.midi_ok = false; dbg.midi_err = "no device"; return
  end
  local ok, err = pcall(function() midi_out:note_on(note, vel, ch) end)
  dbg.midi_ok = ok
  if not ok then dbg.midi_err = short_err(err) end
end

local function safe_note_off(note, ch)
  if not midi_out then return end
  pcall(function() midi_out:note_off(note, 0, ch) end)
end

local function connect_midi(n)
  local ok, dev = pcall(midi.connect, n)
  if ok and dev then
    midi_out = dev
    local nm = (dev.name and dev.name ~= "" and dev.name) or "?"
    dbg.midi_name = string.format("p%d:%s", n, nm)
    dbg.midi_ok = true; dbg.midi_err = ""
  else
    midi_out = nil; dbg.midi_ok = false
    dbg.midi_err = short_err(dev)
  end
end

-- -------------------------------------------------------------------------
-- Note-off metro: drains a timestamp queue every 50ms

local function init_note_off_metro()
  note_off_metro = metro.init(function()
    local now  = util.time()
    local keep = {}
    for _, ev in ipairs(note_off_queue) do
      if now >= ev.when then
        safe_note_off(ev.note, ev.ch)
      else
        table.insert(keep, ev)
      end
    end
    note_off_queue = keep
  end, 0.05, -1)
  note_off_metro:start()
end

local function schedule_note_off(note, ch, delay)
  table.insert(note_off_queue, {note=note, ch=ch, when=util.time()+delay})
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
  sky = Stars.compute()
  state.year  = params:get("year")
  state.month = params:get("month")
  state.day   = params:get("day")
  triggered   = {}
  dbg.sky_n   = #sky
  local a = 0
  for _, s in ipairs(sky) do
    if s.dice <= state.density then a = a + 1 end
  end
  dbg.active_n = a
end

-- -------------------------------------------------------------------------
-- Note triggering

local function trigger_star(star)
  -- Increment first so it's visible even if something below throws
  dbg.trig_count = dbg.trig_count + 1

  state.flash_times[star.id] = util.time()

  local sx = screen_x(star)
  local sy = (star.vy - state.pan_y) * state.zoom

  -- Pitch — defensive param reads
  local pb = params:get("pitch_base")
  local pr = params:get("pitch_range")
  if type(pb) ~= "number" then pb = 48 end
  if type(pr) ~= "number" then pr = 24 end
  local t    = 1 - util.clamp(sy / 63, 0, 1)
  local note = math.max(0, math.min(127, math.floor(pb + t * pr)))
  local freq = 440 * (2 ^ ((note - 69) / 12))

  local amp = util.clamp(0.2 + star.brightness * 0.65, 0.05, 0.9)
  local pan = util.clamp((sx / 64) - 1, -1, 1)

  local vol = params:get("out_vol")
  if type(vol) ~= "number" then vol = 0.7 end
  safe_engine_note(freq, amp * vol, pan, 1.5, 2.0)

  dbg.last_note = note
  dbg.last_freq = math.floor(freq)

  local vel = math.floor(util.clamp(amp * 115 + 12, 1, 127))
  local ch  = params:get("midi_channel")
  if type(ch) ~= "number" then ch = 1 end
  safe_note_on(note, vel, ch)
  schedule_note_off(note, ch, 1.5)
end

-- Trigger stars within ±band px of playhead position px.
-- trigger_star is individually pcall-protected so one bad star can't
-- freeze the loop.
local function trigger_at(px, band)
  local lo, hi = px - band, px + band
  for _, star in ipairs(sky) do
    if star.dice <= state.density and not triggered[star.id] then
      local sx = screen_x(star)
      if sx >= lo and sx <= hi then
        local ok, err = pcall(trigger_star, star)
        if ok then
          triggered[star.id] = true
        else
          dbg.frame_err = short_err(err)
        end
      end
    end
  end
end

-- -------------------------------------------------------------------------
-- Update loop

local function update_frame()
  local now = util.time()
  local dt  = math.min(now - last_time, 0.1)
  last_time = now
  dbg.dt = math.floor(dt * 1000)
  if dt > 0 then dbg.fps = math.floor(1/dt + 0.5) end

  blink_acc = blink_acc + dt
  if blink_acc >= 0.5 then
    blink_acc = blink_acc - 0.5
    state.blink = not state.blink
    -- Prune stale flashes
    for id, t in pairs(state.flash_times) do
      if now - t > 1.0 then state.flash_times[id] = nil end
    end
    -- Update visible star count
    local v = 0
    for _, s in ipairs(sky) do
      if s.dice <= state.density then
        local sx = screen_x(s)
        if sx >= 0 and sx <= 127 then v = v + 1 end
      end
    end
    dbg.visible_n = v
  end

  if state.mode == "auto" and state.playing then
    local speed = params:get("scan_speed")
    if type(speed) ~= "number" then speed = 24 end

    trigger_at(state.playhead_x, 1.5)
    state.playhead_x = state.playhead_x + speed * dt

    if state.playhead_x > 127 then
      state.pan_x = (state.pan_x + 128.0 / state.zoom) % Stars.FIELD_W
      state.playhead_x = 0
      triggered = {}
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
  params:add_control("out_vol",     "Volume",      controlspec.new(0,   1, 'lin', 0.01, 0.7))
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
  init_note_off_metro()

  last_time = util.time()
  update_clock_id = clock.run(function()
    while true do
      clock.sleep(1/33)
      local ok, err = pcall(update_frame)
      if not ok then
        dbg.frame_err = short_err(err)
        dbg.eng_ok = false
      end
    end
  end)
end

function enc(n, d)
  if n == 1 then
    if k_held[1] then
      k1_mod_used = true
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
            local lo = math.min(dvx_old * state.zoom, screen_x(star))
            local hi = math.max(dvx_old * state.zoom, screen_x(star))
            if lo <= 64 and hi >= 64 then
              pcall(trigger_star, star)
            end
          end
        end
      end
    end

  elseif n == 2 then
    if k_held[2] then
      k2_mod_used = true
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
      k1_mod_used = false
    elseif not k1_mod_used then
      state.debug = not state.debug
    end

  elseif n == 2 then
    if z == 1 then
      k2_mod_used = false
    elseif not k2_mod_used then
      if state.mode == "auto" then
        state.mode = "cursor"; state.playing = false
      else
        state.mode = "auto"
      end
    end

  elseif n == 3 and z == 1 then
    if state.mode == "auto" then
      state.playing = not state.playing
      if state.playing then triggered = {}; last_time = util.time() end
    end
  end
end

function cleanup()
  if update_clock_id then clock.cancel(update_clock_id) end
  if note_off_metro  then note_off_metro:stop() end
  note_off_queue = {}
end
