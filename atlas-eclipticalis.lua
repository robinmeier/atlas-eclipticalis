engine.name = 'Atlas'

local Stars     = include 'lib/stars'
local UI        = include 'lib/ui'
local MusicUtil = require 'musicutil'

-- -------------------------------------------------------------------------
-- State

local state = {
  pan_x      = 0,
  pan_y      = 200,
  zoom       = 1.0,
  mode       = "cursor",   -- "cursor" | "scan"
  scan_speed = 0,          -- signed vx/s; E2 in scan mode; 0 = stopped
  density    = 0.80,
  year = 2000, month = 1, day = 1,
  disp_hour  = 0.0,
  flash_times = {},
  startup    = true,
}

local dbg = {
  fps = 0, dt = 0,
  sky_n = 0, active_n = 0,
  trig_count = 0, trig_stage = 0,
  last_note = 0, last_freq = 0,
  eng_ok = true, eng_err = "",
  midi_dev  = "none",
  frame_err = "",
}
state.dbg = dbg

local sky              = {}
local k_held           = {false, false, false}
local midi_device                -- norns midi vport object (like awake)
local midi_channel     = 1       -- active midi channel
local update_clock_id
local note_off_metro
local note_off_queue   = {}
local last_time        = 0

-- -------------------------------------------------------------------------
-- Error helper

local function short_err(e)
  local s = tostring(e)
  return (s:match(":%d+: (.+)$") or s:sub(-36)):sub(1, 36)
end

-- -------------------------------------------------------------------------
-- Audio engine wrapper (keep pcall here; engine loading is async)

local function safe_engine_note(freq, amp, pan, sus, rel)
  if not engine.note then
    dbg.eng_ok = false; dbg.eng_err = "cmd nil"; return
  end
  local ok, err = pcall(function() engine.note(freq, amp, pan, sus, rel) end)
  dbg.eng_ok = ok
  if not ok then dbg.eng_err = short_err(err) end
end

-- -------------------------------------------------------------------------
-- Note-off metro: drains a timestamp queue every 50ms

local function init_note_off_metro()
  note_off_metro = metro.init(function()
    local now  = util.time()
    local keep = {}
    for _, ev in ipairs(note_off_queue) do
      if now >= ev.when then
        if midi_device then midi_device:note_off(ev.note, 0, ev.ch) end
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
  local dvx = star.vx - state.pan_x * (star.par or 1.0)
  dvx = ((dvx % Stars.FIELD_W) + Stars.FIELD_W) % Stars.FIELD_W
  if dvx > Stars.FIELD_W / 2 then dvx = dvx - Stars.FIELD_W end
  return dvx * state.zoom
end

-- Calendar helpers for date-aware hour wrapping
local _DIM = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local function leap(y) return (y%4==0 and y%100~=0) or y%400==0 end
local function dim(m, y) return (m==2 and leap(y)) and 29 or _DIM[m] end

local function advance_date(days)
  local d, m, y = state.day + days, state.month, state.year
  while d > dim(m, y) do d = d - dim(m, y); m = m + 1; if m > 12 then m=1; y=y+1 end end
  while d < 1     do m = m - 1; if m < 1 then m=12; y=y-1 end; d = d + dim(m, y) end
  state.day, state.month, state.year = d, m, y
end

local function advance_hours(delta)
  local h = state.disp_hour + delta
  local days = math.floor(h / 24)
  state.disp_hour = h - days * 24
  if days ~= 0 then advance_date(days) end
end

local function rebuild()
  sky = Stars.compute()
  state.year      = params:get("year")
  state.month     = params:get("month")
  state.day       = params:get("day")
  state.disp_hour = params:get("hour")
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
  dbg.trig_count = dbg.trig_count + 1
  dbg.trig_stage = 1

  state.flash_times[star.id] = util.time()
  dbg.trig_stage = 2

  local sx = screen_x(star)
  local sy = (star.vy - state.pan_y) * state.zoom
  dbg.trig_stage = 3

  local pb = params:get("pitch_base")
  local pr = params:get("pitch_range")
  if type(pb) ~= "number" then pb = 48 end
  if type(pr) ~= "number" then pr = 24 end
  local t    = 1 - util.clamp(sy / 63, 0, 1)
  local note = math.max(0, math.min(127, math.floor(pb + t * pr)))
  local freq = MusicUtil.note_num_to_freq(note)
  dbg.trig_stage = 4

  local amp = util.clamp(0.2 + star.brightness * 0.65, 0.05, 0.9)
  local pan = util.clamp((sx / 64) - 1, -1, 1)
  local vol = params:get("out_vol")
  if type(vol) ~= "number" then vol = 0.7 end
  dbg.trig_stage = 5

  local out = params:get("out")

  -- Audio
  if out == 1 or out == 3 then
    safe_engine_note(freq, amp * vol, pan, 1.5, 2.0)
  end
  dbg.trig_stage = 6

  dbg.last_note = note
  dbg.last_freq = math.floor(freq)
  dbg.trig_stage = 7

  -- MIDI (exactly like awake)
  if (out == 2 or out == 3) and midi_device then
    local vel = math.floor(util.clamp(amp * 115 + 12, 1, 127))
    midi_device:note_on(note, vel, midi_channel)
    schedule_note_off(note, midi_channel, 1.5)
  end
  dbg.trig_stage = 8
end

-- -------------------------------------------------------------------------
-- Update loop

local function update_frame()
  local now = util.time()
  local dt  = math.min(now - last_time, 0.1)
  last_time = now
  dbg.dt = math.floor(dt * 1000)
  if dt > 0 then dbg.fps = math.floor(1/dt + 0.5) end

  if state.startup then
    UI.draw_startup()
    return
  end

  -- Clean up expired flash times
  for id, t in pairs(state.flash_times) do
    if now - t > 1.0 then state.flash_times[id] = nil end
  end

  -- Scan mode: advance pan_x and detect star crossings at x=64
  if state.mode == "scan" and state.scan_speed ~= 0 then
    local dx        = state.scan_speed * dt
    local old_pan_x = state.pan_x
    state.pan_x     = ((state.pan_x + dx) % Stars.FIELD_W + Stars.FIELD_W) % Stars.FIELD_W
    advance_hours(dx / 100)

    for _, star in ipairs(sky) do
      if star.dice <= state.density then
        local par     = star.par or 1.0
        local dvx_old = star.vx - old_pan_x * par
        dvx_old = ((dvx_old % Stars.FIELD_W) + Stars.FIELD_W) % Stars.FIELD_W
        if dvx_old > Stars.FIELD_W / 2 then dvx_old = dvx_old - Stars.FIELD_W end
        local sx_old  = dvx_old * state.zoom
        local sx_new  = screen_x(star)
        if sx_new >= -2 and sx_new <= 129 then
          local lo = math.min(sx_old, sx_new)
          local hi = math.max(sx_old, sx_new)
          if lo <= 64 and hi >= 64 then
            -- cooldown gate: don't re-trigger within 0.4s of last flash
            local ft = state.flash_times[star.id]
            if not ft or now - ft > 0.4 then
              local sy = (star.vy - state.pan_y) * state.zoom
              if sy >= 0 and sy <= 63 then
                local ok, err = pcall(trigger_star, star)
                if not ok then dbg.frame_err = short_err(err) end
              end
            end
          end
        end
      end
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

  -- Build MIDI device list from vports exactly like awake
  local midi_out_devices = {}
  for i = 1, #midi.vports do
    local name = midi.vports[i].name
    table.insert(midi_out_devices, i .. ": " .. name)
  end

  params:add_separator("ATLAS ECLIPTICALIS")
  params:add_number("year",  "Year",      2000, 2100, t.year)
  params:add_number("month", "Month",     1,    12,   t.month)
  params:add_number("day",   "Day",       1,    31,   t.day)
  params:add_number("hour",  "Hour",      0,    23,   t.hour)
  params:add_number("lat",   "Latitude",  -90,  90,   48)
  params:add_number("lon",   "Longitude", -180, 180,  2)

  params:add_separator("SOUND")
  params:add_control("pitch_base",  "Pitch Base",  controlspec.new(24, 84, 'lin', 1,   48,  "midi"))
  params:add_control("pitch_range", "Pitch Range", controlspec.new(1,  48, 'lin', 1,   24,  "semi"))
  params:add_control("out_vol",     "Volume",      controlspec.new(0,   1, 'lin', 0.01, 0.7))

  -- Output mode exactly like awake
  params:add{type="option", id="out", name="output",
    options={"audio", "midi", "audio+midi"}, default=3}

  -- MIDI device: option list from vports, action fires on params:bang (like awake)
  params:add{type="option", id="midi_device", name="midi device",
    options=midi_out_devices, default=1,
    action=function(v)
      midi_device = midi.connect(v)
      dbg.midi_dev = midi_device.name
    end}

  -- MIDI channel: action keeps local var in sync (like awake)
  params:add{type="number", id="midi_out_channel", name="midi channel",
    min=1, max=16, default=1,
    action=function(v) midi_channel = v end}

  local function sky_action() rebuild() end
  for _, p in ipairs({"year","month","day","hour","lat","lon"}) do
    params:set_action(p, sky_action)
  end

  Stars.load()
  state.const_lines = Stars.CONST_LINES
  params:read()
  params:bang()

  local px, py = Stars.default_pan(
    params:get("year"), params:get("month"), params:get("day"), params:get("hour"),
    params:get("lat"), params:get("lon")
  )
  state.pan_x      = px
  state.pan_y      = py
  state.disp_hour  = params:get("hour")

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
  if state.startup then return end

  if n == 1 then
    if k_held[1] then
      -- K1 held: adjust star density
      state.density = util.clamp(state.density + d * 0.02, 0.04, 1.0)
    else
      -- Zoom anchored to screen center
      local factor = d > 0 and 1.06 or (1 / 1.06)
      local vx_c = state.pan_x + 64 / state.zoom
      local vy_c = state.pan_y + 32 / state.zoom
      for _ = 1, math.abs(d) do
        state.zoom = util.clamp(state.zoom * factor, 0.3, 8.0)
      end
      state.pan_x = ((vx_c - 64 / state.zoom) % Stars.FIELD_W + Stars.FIELD_W) % Stars.FIELD_W
      state.pan_y = util.clamp(vy_c - 32 / state.zoom, 0, Stars.FIELD_H - 64)
    end

  elseif n == 2 then
    if state.mode == "scan" then
      -- Scan mode: adjust scan speed (±5 vx/s per tick; CW = forward, CCW = reverse)
      state.scan_speed = util.clamp(state.scan_speed + d * 5, -100, 100)
    else
      -- Cursor mode: pan horizontally, trigger stars that cross x=64
      local old_pan_x = state.pan_x
      state.pan_x = ((state.pan_x + d * (3.0 / state.zoom)) % Stars.FIELD_W
                     + Stars.FIELD_W) % Stars.FIELD_W
      advance_hours(d * 0.03 / state.zoom)

      for _, star in ipairs(sky) do
        if star.dice <= state.density then
          local sx_new = screen_x(star)
          if sx_new >= -2 and sx_new <= 129 then
            local dvx_old = star.vx - old_pan_x * (star.par or 1.0)
            dvx_old = ((dvx_old % Stars.FIELD_W) + Stars.FIELD_W) % Stars.FIELD_W
            if dvx_old > Stars.FIELD_W / 2 then dvx_old = dvx_old - Stars.FIELD_W end
            local lo = math.min(dvx_old * state.zoom, sx_new)
            local hi = math.max(dvx_old * state.zoom, sx_new)
            if lo <= 64 and hi >= 64 then
              local sy = (star.vy - state.pan_y) * state.zoom
              if sy >= 0 and sy <= 63 then
                pcall(trigger_star, star)
              end
            end
          end
        end
      end
    end

  elseif n == 3 then
    state.pan_y = util.clamp(state.pan_y + d * (3.0 / state.zoom),
                             0, Stars.FIELD_H - 64)
  end
end

function key(n, z)
  if state.startup and z == 1 then
    state.startup = false
    return
  end

  k_held[n] = (z == 1)

  if n == 2 and z == 1 then
    -- Toggle cursor/scan; entering cursor resets speed to 0
    if state.mode == "scan" then
      state.mode       = "cursor"
      state.scan_speed = 0
    else
      state.mode = "scan"
    end
  end
  -- K1 tap: nothing (hold tracked for E1 density modifier)
  -- K3: nothing
end

function cleanup()
  if update_clock_id then clock.cancel(update_clock_id) end
  if note_off_metro  then note_off_metro:stop() end
  note_off_queue = {}
end
