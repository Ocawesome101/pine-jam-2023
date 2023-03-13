-- colliding lines

local pA, pB, pC, pD = {x=10, y=3}, {x=4, y=9},
  {x=15, y=7}, {x=10, y=14}
local lA, lB = {a=pA, b=pB}, {a=pC, b=pD}

local function draw(l, c)
  paintutils.drawLine(l.a.x, l.a.y,
    l.b.x, l.b.y, c)
  term.setTextColor(colors.white)
  term.setCursorPos(l.a.x, l.a.y)
  term.write("A")
  term.setCursorPos(l.b.x, l.b.y)
  term.write("B")
end

local function orientation(a, b, c)
  local val = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y)
  return val > 0 and 1
      or val < 0 and 2
      or 0
end

local min, max = math.min, math.max
local function onSegment(a, b, c)
  if (b.x <= max(a.x, c.x)) and (b.x >= min(a.x, c.x)) and
     (b.y <= max(a.b, c.y)) and (b.y >= min(a.y, c.y)) then
    return true
  end
  return false
end

local function overlaps(a, b)
  -- top/bottom
  local o1, o2, o3, o4 =
    orientation(a.a, a.b, b.a),
    orientation(a.a, a.b, b.b),
    orientation(b.a, b.b, a.a),
    orientation(b.a, b.b, a.b)

  if o1 ~= o2 and o3 ~= o4 then
    return true
  end

  if o1 == 0 and onSegment(a.a, b.a, a.b) then
    return true
  end

  if o2 == 0 and onSegment(a.a, b.b, a.b) then
    return true
  end

  if o3 == 0 and onSegment(b.a, a.a, b.b) then
    return true
  end

  if o4 == 0 and onSegment(b.a, a.b, b.b) then
    return true
  end

  return false
end

local dragging = false

while true do
  term.setBackgroundColor(colors.black)
  term.clear()
  draw(lA, overlaps(lA, lB) and colors.red or colors.green)
  draw(lB, overlaps(lA, lB) and colors.red or colors.green)
  local sig = {os.pullEvent()}
  if sig[1] == "mouse_up" then
    dragging = false
  elseif sig[1] == "mouse_click" then
    dragging =
        sig[3] == pA.x and sig[4] == pA.y and pA
     or sig[3] == pB.x and sig[4] == pB.y and pB
     or sig[3] == pC.x and sig[4] == pC.y and pC
     or sig[3] == pD.x and sig[4] == pD.y and pD
     or false
  elseif sig[1] == "mouse_drag" and dragging then
    dragging.x = sig[3]
    dragging.y = sig[4]
  end
end
