-- Screen rendering — atmospheric style (style 2 from mockup approval)

local UI = {}

local STAFF_Y   = {14, 21, 28, 35, 42}
local STAFF_TOP = 10   -- above which stars are "above staff"
local STAFF_BOT = 46   -- below which stars are "below staff"

-- Return norns brightness level (0-15) from magnitude
local function mag_level(mag, in_staff)
  local base = math.max(2, math.floor(15 - (mag + 1.5) * 1.8))
  return in_staff and math.min(15, base + 1) or base
end

-- True if screen y is within the staff band
local function on_staff(sy)
  return sy >= STAFF_TOP and sy <= STAFF_BOT
end

function UI.draw(sky_stars, state)
  screen.clear()

  -- Stars
  for _, star in ipairs(sky_stars) do
    if star.dice <= state.density then
      -- Screen position from virtual coordinates, with proper circular wrap
      local dvx = star.vx - state.pan_x
      dvx = ((dvx % 2400) + 2400) % 2400
      if dvx > 1200 then dvx = dvx - 2400 end
      local sx = math.floor(dvx * state.zoom + 0.5)
      local sy = math.floor((star.vy - state.pan_y) * state.zoom + 0.5)

      if sx >= -1 and sx <= 128 and sy >= -1 and sy <= 64 then
        local in_st = on_staff(sy)
        local lv    = mag_level(star.mag, in_st)

        -- Atmospheric halo for bright stars (mag < 2.2)
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
          -- 2×2 for very bright stars
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

  -- Playhead or cursor
  if state.mode == "auto" then
    local px = math.floor(state.playhead_x + 0.5)
    screen.level(15)
    screen.move(px, 0)
    screen.line(px, 63)
    screen.stroke()
  else
    -- Crosshair cursor at screen centre
    local cx, cy = 64, 32
    screen.level(10)
    screen.move(cx - 4, cy)
    screen.line(cx + 4, cy)
    screen.stroke()
    screen.move(cx, cy - 4)
    screen.line(cx, cy + 4)
    screen.stroke()
    screen.level(4)
    screen.circle(cx, cy, 6)
    screen.stroke()
  end

  -- HUD: date top-left, mode + density bottom-right
  screen.font_size(8)
  screen.level(4)
  screen.move(2, 7)
  screen.text(string.format("%04d-%02d-%02d", state.year, state.month, state.day))

  screen.move(80, 62)
  screen.text(string.format("%s  %d%%", state.mode == "auto" and "AUTO" or "CURS",
                             math.floor(state.density * 100)))

  -- Playing indicator (blinking dot)
  if state.mode == "auto" and state.playing then
    screen.level(state.blink and 12 or 3)
    screen.circle(127, 3, 2)
    screen.fill()
  end

  screen.update()
end

return UI
