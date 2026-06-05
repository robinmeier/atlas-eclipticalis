-- Screen rendering — atmospheric style (style 2)

local UI = {}

local STAFF_Y   = {14, 21, 28, 35, 42}
local STAFF_TOP = 10
local STAFF_BOT = 46

local FLASH_DUR = 0.35   -- seconds a flash lasts

-- Ring of 12 pixels at radius ~2 used for the trigger flash
local FLASH_RING = {{-2,0},{2,0},{0,-2},{0,2},
                    {-2,-1},{2,-1},{-2,1},{2,1},
                    {-1,-2},{1,-2},{-1,2},{1,2}}

local function mag_level(mag, in_staff)
  local base = math.max(2, math.floor(15 - (mag + 1.5) * 1.8))
  return in_staff and math.min(15, base + 1) or base
end

local function on_staff(sy)
  return sy >= STAFF_TOP and sy <= STAFF_BOT
end

function UI.draw(sky_stars, state)
  screen.clear()

  local now = util.time()

  -- Constellation lines (beneath stars, only when zoomed out)
  if state.zoom <= 1.5 and state.const_lines then
    local function clsx(vx)
      local dvx = vx - state.pan_x   -- named stars: par = 1.0
      dvx = ((dvx % 2400) + 2400) % 2400
      if dvx > 1200 then dvx = dvx - 2400 end
      return dvx * state.zoom
    end
    local function clsy(vy) return (vy - state.pan_y) * state.zoom end
    screen.level(3)
    for _, ln in ipairs(state.const_lines) do
      local x1, y1 = clsx(ln[1]), clsy(ln[2])
      local x2, y2 = clsx(ln[3]), clsy(ln[4])
      if (x1 >= -32 and x1 <= 159 and y1 >= -32 and y1 <= 95) or
         (x2 >= -32 and x2 <= 159 and y2 >= -32 and y2 <= 95) then
        screen.move(x1, y1); screen.line(x2, y2); screen.stroke()
      end
    end
  end

  -- Stars
  for _, star in ipairs(sky_stars) do
    if star.dice <= state.density then
      local dvx = star.vx - state.pan_x * (star.par or 1.0)
      dvx = ((dvx % 2400) + 2400) % 2400
      if dvx > 1200 then dvx = dvx - 2400 end
      local sx = math.floor(dvx * state.zoom + 0.5)
      local sy = math.floor((star.vy - state.pan_y) * state.zoom + 0.5)

      if sx >= -2 and sx <= 129 and sy >= -2 and sy <= 65 then
        local in_st = on_staff(sy)
        local lv    = mag_level(star.mag, in_st)

        -- Trigger flash: bright ring that fades out
        local ft = state.flash_times[star.id]
        if ft then
          local frac = 1 - (now - ft) / FLASH_DUR
          if frac > 0 then
            local fl = math.floor(frac * 13)
            screen.level(fl)
            for _, dd in ipairs(FLASH_RING) do
              local hx, hy = sx + dd[1], sy + dd[2]
              if hx >= 0 and hx <= 127 and hy >= 0 and hy <= 63 then
                screen.pixel(hx, hy)
                screen.fill()
              end
            end
            lv = 15   -- core at max brightness while flashing
          end
        end

        -- Atmospheric halo for named bright stars
        if star.mag < 2.2 and not star.is_bg then
          screen.level(math.max(1, lv - 9))
          for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local hx, hy = sx + d[1], sy + d[2]
            if hx >= 0 and hx <= 127 and hy >= 0 and hy <= 63 then
              screen.pixel(hx, hy)
              screen.fill()
            end
          end
        end

        -- Core pixel(s)
        screen.level(lv)
        if star.mag < 1.0 and not star.is_bg then
          screen.rect(sx, sy, 2, 2)
        else
          screen.pixel(sx, sy)
        end
        screen.fill()
      end
    end
  end

  -- Staff lines
  screen.level(4)
  for _, ly in ipairs(STAFF_Y) do
    screen.move(0, ly)
    screen.line(127, ly)
    screen.stroke()
  end

  -- Playhead (auto) — sweeping line
  -- Cursor (manual) — fixed line at x=64, slightly dimmer
  if state.mode == "auto" then
    local px = math.floor(state.playhead_x + 0.5)
    screen.level(15)
    screen.move(px, 0)
    screen.line(px, 63)
    screen.stroke()
  else
    screen.level(10)
    screen.move(64, 0)
    screen.line(64, 63)
    screen.stroke()
  end

  -- HUD
  screen.font_size(8)
  screen.level(4)
  screen.move(2, 7)
  screen.text(string.format("%04d-%02d-%02d", state.year, state.month, state.day))
  screen.move(80, 62)
  screen.text(string.format("%s  %d%%",
    state.mode == "auto" and "AUTO" or "CURS",
    math.floor(state.density * 100)))

  -- Blinking play dot (top-right)
  if state.mode == "auto" and state.playing then
    screen.level(state.blink and 12 or 3)
    screen.circle(127, 3, 2)
    screen.fill()
  end

  if state.debug and state.dbg then
    UI.draw_debug(state)
  end

  screen.update()
end

-- ── Startup screen (option A) ────────────────────────────────────────────
-- Orion constellation fills upper 2/3; separator; title + subtitle below.
-- Stars twinkle independently via per-star sine oscillators.

-- {screen_x, screen_y, mag, twinkle_hz, twinkle_phase, twinkle_amp}
local _ORI = {
  {48,  8, 0.4, 0.71, 0.00, 2.0},   -- Betelgeuse  (bright, top-left)
  {71, 10, 1.6, 0.53, 1.33, 1.0},   -- Bellatrix
  {54, 20, 2.2, 0.37, 2.09, 0.8},   -- Mintaka     (belt)
  {60, 22, 1.7, 0.61, 0.84, 1.0},   -- Alnilam     (belt)
  {67, 20, 1.8, 0.29, 3.01, 0.8},   -- Alnitak     (belt)
  {73, 33, 0.1, 0.89, 1.74, 2.5},   -- Rigel       (brightest, bottom-right)
  {50, 33, 2.0, 0.47, 2.51, 0.8},   -- Saiph
}
-- connecting lines (1-based index pairs)
local _ORI_L = {{1,2},{1,3},{2,5},{3,4},{4,5},{5,6},{3,7}}

-- background scatter: {x, y, mag, twinkle_hz, twinkle_phase}
local _BG = {
  {  8,  4,3.8,0.18,0.10},{ 22,  9,4.2,0.13,1.51},{102,  3,3.6,0.21,0.77},
  {121, 14,4.1,0.16,2.33},{  4, 29,4.5,0.11,1.22},{ 16, 47,3.9,0.19,3.01},
  {119, 41,4.2,0.14,0.55},{111, 57,3.6,0.22,2.10},{ 36, 56,4.5,0.10,1.80},
  { 91, 59,4.1,0.17,0.33},{101, 33,4.5,0.12,2.88},{ 21, 58,4.3,0.20,1.05},
  { 81, 53,4.5,0.15,3.14},{ 28, 37,4.8,0.11,0.72},{116, 51,4.1,0.18,1.95},
  { 41,  4,4.6,0.13,2.40},{ 96, 17,4.1,0.16,0.18},{  6, 59,4.5,0.12,3.00},
  { 77,  6,4.3,0.19,1.66},{ 31, 21,4.9,0.10,0.93},{126, 29,4.0,0.14,2.21},
  { 86, 39,4.7,0.17,0.45},{ 13, 36,4.6,0.11,1.38},{106, 23,4.3,0.15,2.75},
  { 60,  3,4.4,0.20,0.60},{ 14, 15,4.8,0.13,1.88},{122, 58,4.2,0.16,3.08},
  { 50, 57,4.6,0.12,0.27},
}

local function _twinkle_lv(base_lv, hz, phase, amp, now)
  local tw = math.sin(now * hz * math.pi * 2 + phase) * amp
  return math.max(1, math.min(15, math.floor(base_lv + tw + 0.5)))
end

local function _place_star(x, y, lv)
  screen.level(lv)
  screen.pixel(x, y)
  screen.fill()
end

function UI.draw_startup()
  screen.clear()
  local now = util.time()

  -- dim scatter with very gentle twinkle
  for _, s in ipairs(_BG) do
    local base = math.max(1, math.floor(15 - s[3] * 2.0))
    local lv   = _twinkle_lv(base, s[4], s[5], 0.5, now)
    _place_star(s[1], s[2], lv)
  end

  -- constellation lines (dim, drawn before stars so stars sit on top)
  screen.level(3)
  for _, ln in ipairs(_ORI_L) do
    local a, b = _ORI[ln[1]], _ORI[ln[2]]
    screen.move(a[1], a[2])
    screen.line(b[1], b[2])
    screen.stroke()
  end

  -- constellation stars with per-star twinkling
  for _, s in ipairs(_ORI) do
    local x, y, mag, hz, phase, amp = s[1], s[2], s[3], s[4], s[5], s[6]
    local base = math.max(2, math.floor(15 - mag * 2.0))
    local lv   = _twinkle_lv(base, hz, phase, amp, now)
    -- halo for bright stars
    if lv >= 9 then
      screen.level(math.max(1, lv - 9))
      for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
        screen.pixel(x+d[1], y+d[2]); screen.fill()
      end
    end
    -- 2×2 core for Rigel (mag < 0.5)
    screen.level(lv)
    if mag < 0.5 then
      screen.rect(x, y, 2, 2)
    else
      screen.pixel(x, y)
    end
    screen.fill()
  end

  -- separator
  screen.level(3)
  screen.move(18, 42); screen.line(110, 42); screen.stroke()

  -- title
  screen.font_size(8)
  screen.level(15)
  local tw = screen.text_extents("ATLAS ECLIPTICALIS")
  screen.move(math.floor((128 - tw) / 2), 50)
  screen.text("ATLAS ECLIPTICALIS")

  -- subtitle (font_size 8 but dim — larger than before for readability)
  screen.font_size(8)
  screen.level(5)
  tw = screen.text_extents("an astronomical music box")
  screen.move(math.floor((128 - tw) / 2), 61)
  screen.text("an astronomical music box")

  screen.update()
end

-- On-screen diagnostics overlay (toggle with a short K1 tap)
function UI.draw_debug(state)
  local d = state.dbg

  screen.level(0)
  screen.rect(0, 10, 128, 54)
  screen.fill()

  screen.font_size(8)
  local function row(y, s, lv)
    screen.level(lv or 15)
    screen.move(2, y)
    screen.text(s)
  end

  row(19, string.format("play:%s fps:%d dt:%dms",
        state.playing and "ON" or "off", d.fps, d.dt))
  row(27, string.format("tc:%d ts:%d  n:%d f:%d",
        d.trig_count, d.trig_stage, d.last_note, d.last_freq))
  row(35, d.eng_ok and "eng:OK" or ("eng ERR:"..d.eng_err),
        d.eng_ok and 10 or 15)
  row(43, string.format("midi:%s out:%s", d.midi_dev,
        ({"aud","mid","a+m"})[params:get("out") or 1] or "?"), 10)
  row(51, d.frame_err ~= "" and ("!!"..d.frame_err) or "ok",
        d.frame_err ~= "" and 15 or 5)
end

return UI
