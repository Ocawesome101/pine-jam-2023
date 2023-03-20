local Pine3D = require("Pine3D")
local softbody = require("softbody")

-- movement and turn speed of the camera
local speed = 2 -- units per second
local turnSpeed = 180 -- degrees per second

-- create a new frame
local ThreeDFrame = Pine3D.newFrame()

-- initialize our own camera and update the frame camera
local camera = {
  x = -3,
  y = 5,
  z = 0,
  rotX = 0,
  rotY = 0,
  rotZ = 90,
}
ThreeDFrame:setCamera(camera)

local simulation = softbody.newSimulation()

-- define the objects to be rendered
local objects = {}-- generateWorld(ThreeDFrame, genOptions)
-- (-i,j)-------(i,j)
--    |       ___/  |
--    |   ___/      |
--    |  /          |
-- (-i,-j)-----(i,-j)
local function newChunk(d, i, j)
  return {
    -- floor
    {x1=d+i,y1=0,z1=d+j,x2=d+i,y2=0,z2=d-j,x3=d-i,y3=0,z3=d-j,c=colors.lightGray},
    {x1=d-i,y1=0,z1=d-j,x2=d-i,y2=0,z2=d+j,x3=d+i,y3=0,z3=d+j,c=colors.gray},
    -- red wall
    {x1=d+i,y1=0,z1=d-j,x2=d+i,y2=5,z2=d+j,x3=d+i,y3=5,z3=d-j,c=colors.lightGray,},
    {x3=d+i,y3=5,z3=d+j,x2=d+i,y2=0,z2=d+j,x1=d+i,y1=0,z1=d-j,c=colors.red,},
    -- green wall
    {x1=d-i,y1=0,z1=d-j,x2=d-i,y2=5,z2=d-j,x3=d-i,y3=5,z3=d+j,c=colors.lightGray,},
    {x1=d-i,y1=0,z1=d+j,x2=d-i,y2=0,z2=d-j,x3=d-i,y3=5,z3=d+j,c=colors.green,},
    -- blue wall
    {x1=d-i,y1=0,z1=d+j,x2=d-i,y2=5,z2=d+j,x3=d+i,y3=5,z3=d+j,c=colors.lightGray,},
    {x1=d+i,y1=0,z1=d+j,x2=d-i,y2=0,z2=d+j,x3=d+i,y3=5,z3=d+j,c=colors.blue,},
    -- orange wall
    {x1=d-i,y1=0,z1=d-j,x2=d+i,y2=5,z2=d-j,x3=d-i,y3=5,z3=d-j,c=colors.lightGray,},
    {x1=d-i,y1=0,z1=d-j,x2=d+i,y2=0,z2=d-j,x3=d+i,y3=5,z3=d-j,c=colors.orange,},
  }
end
local arena = {ThreeDFrame:newObject(newChunk(30, 10, 10), -30, 0, -30)}

local function addPhysicsObject(x, y, z)
  objects[#objects+1]=assert(simulation:loadLuaBeamAsPineObject(ThreeDFrame, "cube.lbeam", x, y, z))
end

addPhysicsObject(0, 10, 0)

simulation:loadPineObject(arena[1], 0.2)

--simulation:setGravity(-0.1)

local paused, help = false, true

-- handle all keypresses and store in a lookup table
-- to check later if a key is being pressed
local keysDown = {}
local function keyInput()
  while true do
    -- wait for an event
    local event, key, x, y = os.pullEvent()

    if event == "key" then -- if a key is pressed, mark it as being pressed down
      keysDown[key] = true
    elseif event == "key_up" then -- if a key is released, reset its value
      keysDown[key] = nil
    elseif event == "char" then
      if key == "p" then paused = not paused end
      if key == "q" then break end
      if key == "n" then addPhysicsObject(camera.x, camera.y, camera.z) end
      if key == "j" then simulation:setSpeed(simulation:getSpeed() + 1) end
      if key == "l" then simulation:setSpeed(simulation:getSpeed() - 1) end
      if key == "g" then simulation:setGravity(-simulation:getGravity()) end
      if key == "i" then simulation:setGravity(simulation:getGravity() + 1) end
      if key == "k" then simulation:setGravity(simulation:getGravity() - 1) end
      if key == "r" then simulation:setGravity() end
      if key == "z" then simulation:setGravity(0) end
      if key == "h" then help = not help end
    end
  end
end

-- update the camera position based on the keys being pressed
-- and the time passed since the last step
local function handleCameraMovement(dt)
  local dx, dy, dz = 0, 0, 0 -- will represent the movement per second

  -- handle arrow keys for camera rotation
  if keysDown[keys.left] then
    camera.rotY = (camera.rotY - turnSpeed * dt) % 360
  end
  if keysDown[keys.right] then
    camera.rotY = (camera.rotY + turnSpeed * dt) % 360
  end
  if keysDown[keys.down] then
    camera.rotZ = math.max(-80, camera.rotZ - turnSpeed * dt)
  end
  if keysDown[keys.up] then
    camera.rotZ = math.min(80, camera.rotZ + turnSpeed * dt)
  end

  -- handle wasd keys for camera movement
  if keysDown[keys.w] then
    dx = speed * math.cos(math.rad(camera.rotY)) + dx
    dz = speed * math.sin(math.rad(camera.rotY)) + dz
  end
  if keysDown[keys.s] then
    dx = -speed * math.cos(math.rad(camera.rotY)) + dx
    dz = -speed * math.sin(math.rad(camera.rotY)) + dz
  end
  if keysDown[keys.a] then
    dx = speed * math.cos(math.rad(camera.rotY - 90)) + dx
    dz = speed * math.sin(math.rad(camera.rotY - 90)) + dz
  end
  if keysDown[keys.d] then
    dx = speed * math.cos(math.rad(camera.rotY + 90)) + dx
    dz = speed * math.sin(math.rad(camera.rotY + 90)) + dz
  end

  -- space and left shift key for moving the camera up and down
  if keysDown[keys.space] then
    dy = speed + dy
  end
  if keysDown[keys.leftShift] then
    dy = -speed + dy
  end

  -- update the camera position by adding the offset
  camera.x = camera.x + dx * dt
  camera.y = camera.y + dy * dt
  camera.z = camera.z + dz * dt

  ThreeDFrame:setCamera(camera)
end

-- handle game logic
local epoch = rawget(os, "epoch")
local lastTick = epoch("utc")
local function handleGameLogic()
  local delta = epoch("utc") - lastTick
  lastTick = delta + lastTick
  if not paused then
    simulation:tick(delta)
    simulation:updateEntities()
  end
end

-- handle the game logic and camera movement in steps
local function gameLoop()
  local lastTime = os.clock()

  while true do
    -- compute the time passed since last step
    local currentTime = os.clock()
    local dt = currentTime - lastTime
    lastTime = currentTime

    -- run all functions that need to be run
    handleGameLogic()
    handleCameraMovement(dt)

    -- use a fake event to yield the coroutine
    os.queueEvent("gameLoop")
    os.pullEventRaw("gameLoop")
  end
end

local function at(x,y)
  term.setCursorPos(x,y)
  return term
end

local helpText = {
  "Soft-Body Physics Playground",
  "Written by Ocawesome101 for PineJam 2023",
  "Keybinds:",
  "P - pause/unpause simulation",
  "Q - quit",
  "W/A/S/D - move around",
  "Space/Shift - move up/down",
  "Arrow Keys - look around",
  "N - create a new object at the camera position",
  "G - invert gravity",
  "R - reset gravity",
  "Z = zero-gravity",
  "J/L - decrease/increase simulation speed",
  "I/K - increase/decrease gravity",
  "H - toggle showing this help screen",
}

local function drawOverlay(minimal)
  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.orange)
  if minimal or not help then
    local _, h = term.getSize()
    at(1,1).write("P = pause, N = new object")
    at(1,h).write("speed = 1/"..simulation:getSpeed()..", gravity = "..simulation:getGravity())
    return
  end
  for i=1, #helpText do
    at(2,i+1).write(helpText[i])
  end
end

local win = window.create(term.current(), 1, 1, term.getSize())

-- render the objects
local function rendering()
  while true do
    -- load all objects onto the buffer and draw the buffer
    ThreeDFrame:drawObjects(arena)
    ThreeDFrame:drawObjects(objects)

    local c = term.redirect(win)
    ThreeDFrame:drawBuffer()
    drawOverlay(not paused)
    term.redirect(c)
    win.setVisible(true)
    win.setVisible(false)

    -- use a fake event to yield the coroutine
    os.queueEvent("rendering")
    os.pullEventRaw("rendering")
  end
end

-- start the functions to run in parallel
parallel.waitForAny(keyInput, gameLoop, rendering)

term.clear()
local wb = window.create(term.current(), 1, 1, 31, 11)
local w = window.create(wb, 1, 1, 30, 10)
wb.setBackgroundColor(colors.gray)
wb.clear()
wb.setBackgroundColor(colors.black)
wb.setCursorPos(31,1)
wb.write(" ")
wb.setCursorPos(1,11)
wb.write(" ")
w.setBackgroundColor(colors.purple)
w.clear()
w.setCursorPos(5,1)
w.setTextColor(colors.orange)
w.write("Thank you for playing!")
local text = [[
 This soft-body physics play-
 ground was written by
 Ocawesome101 for PineJam
 2023. Check out its source
 code repository at
B ocawesome101/pine-jam-2023
 on GitHub.
]]
local y = 0
for line in text:gmatch("[^\n]+") do
  w.setCursorPos(1, 3+y)
  w.setTextColor(colors.white)
  if line:sub(1,1) == "B" then
    line = line:sub(2)
    w.setTextColor(colors.lightBlue)
  end
  w.write(line)
  y=y+1
end
term.setCursorPos(1,12)
