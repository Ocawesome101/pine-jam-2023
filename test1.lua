local pine = require("Pine3D")

local frame = pine.newFrame()

frame:setCamera(-3, 3, 0, 0, 0, -10)

local ground = pine.models:plane {size=10, y=0, color=colors.green}
local sphere = pine.models:sphere {res=6, color=colors.red}

local objects = {
  frame:newObject(ground, 0, 0, 0),
  frame:newObject(sphere, 0, 2, 0)
}

frame:drawObjects(objects)
frame:drawBuffer()
sleep(1)
