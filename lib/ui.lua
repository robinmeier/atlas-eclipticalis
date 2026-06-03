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

  -- Stars
  for _, star in ipairs(sky_stars) do
    if star.dice <= state.density then
      local dvx = star.vx - state.pan_x
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

-- On-screen diagnostics overlay (toggle with a short K1 tap)
function UI.draw_debug(state)
  local d = state.dbg

  screen.level(0)
  screen.rect(0, 12, 128, 51)
  screen.fill()

  screen.font_size(8)
  local function row(y, s, lv)
    screen.level(lv or 15)
    screen.move(2, y)
    screen.text(s)
  end

  row(20, string.format("play:%s fps:%d dt:%dms",
        state.playing and "ON" or "off", d.fps, d.dt))
  row(28, string.format("ph:%.1f px:%.0f z:%.1f",
        state.playhead_x, state.pan_x, state.zoom))
  row(36, string.format("sky:%d act:%d vis:%d tc:%d",
        d.sky_n, d.active_n, d.visible_n, d.trig_count))
  row(44, string.format("n:%d f:%d  %s",
        d.last_note, d.last_freq, d.eng_ok and "eng:OK" or ("E:"..d.eng_err)),
        d.eng_ok and 15 or 15)
  if d.frame_err ~= "" then
    row(52, "!!" .. d.frame_err, 15)
  else
    row(52, "midi:" .. (d.midi_ok and d.midi_name or ("ERR "..d.midi_err)),
          d.midi_ok and 10 or 15)
  end
end

return UI
