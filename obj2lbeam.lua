-- convert .obj files to LBeam structures

local opts = {}
for i=1, #arg do
  if arg[i]:sub(1,1) == "-" then
    local k,v = arg[i]:match("%-([^=]+)=(.+)")
    opts[k]=tonumber(v) or v
  end
end

if opts.help then
  print("usage: obj2lbeam OBJFILE [opts]")
  print("converts a .obj file to an LBeam structure.\n")
  print("options:")
  print(" -mass=N     set node mass")
  print(" -stiff=N    set beam stiffness")
  print(" -damp=N     set beam damping")
  print(" -color=C    set triangle color")
  print(" -bounce=N   set triangle bounciness")
end

if #arg == 0 then
  error("expected a .obj file", 0)
end

local nodes, beams, tris =
  {{mass=tonumber(opts.mass)or 15}},
  {{stiffness=tonumber(opts.stiff)or 5000,damping=tonumber(opts.damp)or 10}},
  {{color=opts.color or "red",collide=true,
    draw=true,bounce=tonumber(opts.bounce)or 0.5}}

local function addBeam(na, nb)
  for i=1, #beams do
    if (beams[i][1] == na and beams[i][2] == nb) or
       (beams[i][2] == na and beams[i][1] == nb) then
      return
    end
  end
  beams[#beams+1] = {na, nb}
end

for line in io.lines(arg[1]) do
  local cmd = line:match("^[^ ]+")
  if cmd == "v" then
    local x, y, z = line:match("v (%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)")
    nodes[#nodes+1] = {tonumber(x),tonumber(y),tonumber(z),tostring(#nodes)}
  elseif cmd == "f" then
    local a, b, c, e = line:match("f (%d+)/%d+/%d+ (%d+)/%d+/%d+ (%d+)/%d+/%d+(.*)")
    if e and #e > 0 then
      error("only triangular faces are supported!")
    end
    addBeam(a,b)
    addBeam(b,c)
    addBeam(c,a)
    -- TODO; might need extra logic here?
    tris[#tris+1] = {a,b,c}
  elseif cmd == "l" then
    local a, b = line:match("l (%d+) (%d+)")
    addBeam(a, b)
  end
end

local function serialize(t)
  local ret = ""

  if type(t) == "table" then
    ret = "{"
    for k, v in pairs(t) do
      if type(k) == "number" then
        ret = ret .. string.format("%s,", serialize(v))
      else
        ret = ret .. string.format("%s = %s,", k,
          serialize(v))
      end
    end
    ret = ret .. "}\n"
  elseif type(t) == "function" or type(t) == "thread" or
      type(t) == "userdata" then
    error("cannot serialize type " .. type(t), 2)
  else
    return string.format("%q", t)
  end

  return ret
end

local outname = arg[1]:match("([^/]+)$"):gsub("%.obj$", ".lbeam")
local out = io.open(outname, "w")
out:write(serialize({nodes=nodes,beams=beams,triangles=tris}, {}))
out:close()
