-- Soft-body physics sandbox
-- supporting library

-- vector functions
local function length(x, y, z)
  return math.sqrt(x*x + y*y + z*z)
end

local function distance(xa, ya, za, xb, yb, zb)
  local dx, dy, dz = xa - xb, ya - yb, za - zb
  return length(dx, dy, dz)
end

local function normalize(x, y, z)
  local L = length(x, y, z)
  return x / L, y / L, z / L
end

local function dot(ax, ay, az, bx, by, bz)
  return (ax * bx) + (ay * by) + (az * bz)
end

local function cross(ax, ay, az, bx, by, bz)
  return ay * bz - az * by,
        az * bx - ax * bz,
        ax * by - ay * bx
end

local function sign(n)
  if n == 0 then return 0 end
  return n/math.abs(n)
end

-- stv = signed tetra volume, used in collisions
-- sign(dot(cross(b-a, c-a), d-a) / 6)
local function stv(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)
  local Cx, Cy, Cz = cross(
    bx - ax, by - ay, bz - az, -- b-a
    cx - ax, cy - ay, cz - az)
  return sign(dot(Cx, Cy, Cz, -- c-a
    dx - ax, dy - ay, dz - az) / 6) -- d-a / 6
end

-- create basic primitives used in the simulation
local function nnode(instance, x, y, z, mass, locked)
  -- pos[0], pos[1], pos[2]
  -- velocity[0], velocity[1], velocity[2]
  -- force[0], force[1], force[2]
  -- mass, positionLocked
  local node = {x, y, z, 0, 0, 0, 0, 0, 0, mass, locked}
  instance.internal.nodes[#instance.internal.nodes+1] = node
  return #instance.internal.nodes
end

local function nbeam(instance, na, nb, stiffness, damping, maxDeform)
  -- first node, second node, rest length
  -- stiffness, damping
  -- maximum deformation before break
  na, nb =
    instance.internal.nodes[na] or na,
    instance.internal.nodes[nb] or nb
  local restLength = distance(na[1], na[2], na[3], nb[1], nb[2], nb[3])
  local beam = {na, nb, restLength, stiffness, damping, maxDeform}
  --na[11][beam] = true
  --nb[11][beam] = true
  instance.internal.beams[#instance.internal.beams+1] = beam
  return #instance.internal.beams
end

local function ntri(instance, na, nb, nc, bounce)
  -- first node, second node, third node, bounciness
  na, nb, nc =
    instance.internal.nodes[na] or na,
    instance.internal.nodes[nb] or nb,
    instance.internal.nodes[nc] or nc
  instance.internal.triangles[#instance.internal.triangles+1] =
    {na, nb, nc, bounce or 0.5}
  return #instance.internal.triangles
end

local function nsolid(instance, ax, ay, az, bx, by, bz, cx, cy, cz, bounce)
  local solid =
    -- vertices, bounciness...
    {{ax, ay, az}, {bx, by, bz}, {cx, cy, cz}, bounce or 0.5,
    -- ...bounding box
    {
      math.min(ax, bx, cx) - 0.01,
      math.min(ay, by, cy) - 0.01,
      math.min(az, bz, cz) - 0.01},
    {
      math.max(ax, bx, cx) + 0.01,
      math.max(ay, by, cy) + 0.01,
      math.max(az, bz, cz) + 0.01}}
  instance.internal.solids[#instance.internal.solids+1] = solid
  return #instance.internal.solids
end

local function avg(t)
  local n = 0
  for i=1, #t do n = n + t[i] end
  return n/#t
end

-- Takes a PineObject and converts it to an array of Solid triangles.
-- Moving the PineObject will ***NOT*** move the Solids.
-- Every polygon is converted to a Solid, so this isn't great for big complex
-- high-detail models.
local function loadPineObject(instance, object, bounciness)
  local x, y, z = object[1], object[2], object[3]
  for i=1, #object[7] do
    local poly = object[7][i]
    instance:addSolid(poly[1]+x, poly[2]+y, poly[3]+z,
      poly[4]+x, poly[5]+y, poly[6]+z,
      poly[7]+x, poly[8]+y, poly[9]+z,
      bounciness or 0.5)
  end
end

local function loadLuaBeam(instance, path, x, y, z, pine)
  x, y, z = x or 0, y or 0, z or 0
  local handle, err = io.open(path, "r")
  if not handle then
    return nil, err
  end

  local data = handle:read("a")
  handle:close()
  data, err = load("return " .. data, "="..path, "t", {})
  if not data then
    return nil, err
  end

  data = data()

  local nodeMass, beamStiff, beamDamp = 0, 0, 0
  local named, nodes = {}, {}
  for i=1, #data.nodes do
    local def = data.nodes[i]
    if not def[1] then
      nodeMass = def.mass or nodeMass
    else
      local name
      if type(def[1]) == "string" then name = table.remove(def, 1) end
      if def[4] then name = def[4] end
      if def.name then name = def.name end
      local id = instance:addNode(def[1] + x, def[2] + y, def[3] + z,
        def.mass or nodeMass)
      nodes[#nodes+1] = instance.internal.nodes[id]
      if name then named[name] = id end
    end
  end

  for i=1, #data.beams do
    local def = data.beams[i]
    if not def[1] then
      beamStiff, beamDamp = def.stiffness or beamStiff, def.damping or beamDamp
    else
      print(def[1],def[2])
      instance:addBeam(named[def[1]], named[def[2]],
        def.stiffness or beamStiff, def.damping or beamDamp)
    end
  end

  local model = {}

  local triDraw, triColl, triColor, triBounce = true, true, colors.white, 0.5
  local biggestDistance = 0
  local tris = {}
  for i=1, #data.triangles do
    local def = data.triangles[i]
    if not def[1] then
      triDraw, triColl, triColor, triBounce = not not def.draw,
        not not def.collide,
        colors[def.color or ""] or triColor, def.bounce or triBounce
    else
      if triColl then
        instance:addTriangle(named[def[1]], named[def[2]], named[def[3]],
          triBounce)
      end
      if triDraw then
        local _in = instance.internal.nodes
        local a, b, c = _in[named[def[1]]],_in[named[def[2]]],_in[named[def[3]]]
        model[#model+1] = {
          a[1],
          a[2],
          a[3],
          b[1],
          b[2],
          b[3],
          c[1],
          c[2],
          c[3],
          pine and false,
          pine and colors[def.color or ""] or triColor,
          pine and " ",
          pine and colors[def.color or ""] or triColor,
          pine and colors.orange
        }
        tris[#model] = {a, b, c}
        biggestDistance = math.max(biggestDistance,
          length(a[1], a[2], a[3]),
          length(b[1], b[2], b[3]),
          length(c[1], c[2], c[3]))
      end
    end
  end

  if not pine then
    local entity = {
      x = 0, y = 0, z = 0,
      updatePolygons = function(self)
        for i=1, #tris do
          local poly = model[i]
          local a, b, c = tris[i][1], tris[i][2], tris[i][3]
          poly[1], poly[2], poly[3],
          poly[4], poly[5], poly[6],
          poly[7], poly[8], poly[9] =
            a[1] - self[1], a[2] - self[2], a[3] - self[3],
            b[1] - self[1], b[2] - self[2], b[3] - self[3],
            c[1] - self[1], c[2] - self[2], c[3] - self[3]
        end
      end}
    instance.internal.entities[#instance.internal.entities+1] = entity
  end

  return model, tris, biggestDistance, named, nodes
end

-- Load a LuaBeam structure into an instance.  Returns a PineObject.
-- Yes, LuaBeam might be a rip-off of BeamNG's JBeam format.
local function loadLuaBeamAsPineObject(instance, frame, path, x, y, z)
  local model, tris, biggestDistance, named, nodes = instance:loadLuaBeam(path, x, y, z, true)

  local object = {
    0, 0, 0, 0, 0, 0, model, biggestDistance, frame = frame
  }
  function object:setPos(x, y, z)
    local dx = self[1] - (x or self[1])
    local dy = self[2] - (y or self[2])
    local dz = self[3] - (z or self[3])
    for _, id in pairs(named) do
      local n = instance.internal.nodes[id]
      n[1] = n[1] - dx
      n[2] = n[2] - dy
      n[3] = n[3] - dz
    end
    self:updatePolygons()
  end
  function object:setRot(rotX, rotY, rotZ)
    self[4] = rotX or self[4]
    self[5] = rotY or self[5]
    self[6] = rotZ or self[6]
  end
  -- eschew object:setModel
  function object:updatePolygons()
    -- object position: average position of the nodes
    local px, py, pz = {}, {}, {}
    for i=1, #nodes do
      px[i] = nodes[i][1]
      py[i] = nodes[i][2]
      pz[i] = nodes[i][3]
    end
    self[1], self[2], self[3] = avg(px), avg(py), avg(pz)
    for i=1, #tris do
      local poly = model[i]
      local a, b, c = tris[i][1], tris[i][2], tris[i][3]
      poly[1], poly[2], poly[3],
      poly[4], poly[5], poly[6],
      poly[7], poly[8], poly[9] =
        a[1] - self[1], a[2] - self[2], a[3] - self[3],
        b[1] - self[1], b[2] - self[2], b[3] - self[3],
        c[1] - self[1], c[2] - self[2], c[3] - self[3]
    end
  end

  instance.internal.entities[#instance.internal.entities+1] = object

  return object
end

local lib = {}

function lib.newSimulation()
  -- nodes: all nodes in the simulation. each node is a point with some mass.
  -- beams: all beams in the simulation. each beam connects two nodes.
  -- triangles: triangles between three nodes. stores bounciness and friction.
  -- solids: like triangles, but between fixed points in space. cannot move.
  --         grouped into chunks.
  -- nodes and triangles collide, beams do not.
  -- entities: all LuaBeam -> PineObject models
  local nodes, beams, triangles, solids, entities = {}, {}, {}, {}, {}

  local function checkIntersection(nnx, nny, nnz, vx, vy, vz, node, tmp, tri)
    local na, nb, nc = tri[1], tri[2], tri[3]
    local xna, yna, zna, xnb, ynb, znb, xnc, ync, znc =
      na[1], na[2], na[3], nb[1], nb[2], nb[3], nc[1], nc[2], nc[3]
    local Nx, Ny, Nz, Tx, Ty, Tz = node[1], node[2], node[3],
      tmp[1], tmp[2], tmp[3]
    local bba, bbb = tri[5], tri[6]
    -- check the triangle's bounding box first - much faster on non-luajit
    if bba and (not jit) and
        (Nx < bba[1] or Nx > bbb[1]) and
        (Ny < bba[2] or Ny > bbb[2]) and
        (Nz < bba[3] or Nz > bbb[3]) and
        (Tx < bba[1] or Tx > bbb[1]) and
        (Ty < bba[2] or Ty > bbb[2]) and
        (Tz < bba[3] or Tz > bbb[3]) then
      return nnx, nny, nnz, vx, vy, vz, false
    end
    -- Möller-Trumbore triangle intersection
    -- from https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d
    -- i don't fully understand this wizardry
    -- TODO: if this is too slow remove table usage
    local s1, s2 = stv(Nx, Ny, Nz, xna, yna, zna, xnb, ynb, znb, xnc, ync, znc),
      stv(Tx, Ty, Tz, xna, yna, zna, xnb, ynb, znb, xnc, ync, znc)
    if s1 ~= s2 then
      local s3, s4, s5 =
        stv(Nx, Ny, Nz, Tx, Ty, Tz, xna, yna, zna, xnb, ynb, znb),
        stv(Nx, Ny, Nz, Tx, Ty, Tz, xnb, ynb, znb, xnc, ync, znc),
        stv(Nx, Ny, Nz, Tx, Ty, Tz, xnc, ync, znc, xna, yna, zna)
      if s3 == s4 and s4 == s5 then
        local cx, cy, cz = cross(xnb-xna, ynb-yna, znb-zna,
          xnc-xna, ync-yna, znc-zna)
        local t =
          dot(xna-Nx, yna-Ny, zna-Nz, cx, cy, cz) /
          dot(Tx-Nx, Ty-Ny, Tz-Nz, cx, cy, cz)
        -- this is the point of intersection
        local ix, iy, iz =
          Nx + t * (Tx - Nx),
          Ny + t * (Ty - Ny),
          Nz + t * (Tz - Nz)
        -- compute normal of triangle surface: don't have to,
        -- done earlier as (cx, cy, cz)
        -- may have to invert it, possibly conditionally
        -- we have to normalize it, though, so do that
        local nox, noy, noz = normalize(cx, cy, cz)
        --[=[
        if sign(nox) ~= sign(vx) and sign(noy) ~= sign(vy) and
            sign(noz) ~= sign(vz) then
          nox, noy, noz = --[[nox, -noy, -noz -]]-nox + sign(nox), -noy + sign(noy), -noz + sign(noy)
        end]=]
        -- now set node position to point of intersection...
        nnx, nny, nnz =
          ix + 0.001 * sign(nox),
          iy + 0.001 * sign(noy),
          iz + 0.001 * sign(noz)
        -- and reflect velocity along surface, multiplying by
        -- surface bounciness (range 0 to 1)
        local bounce = tri[4] or 0.5
        local len = length(nox, noy, noz)^2
        local vdx, vdy, vdz =
          ((2*vx*nox)/len * nox) * bounce,
          ((2*vy*noy)/len * noy) * bounce,
          ((2*vz*noz)/len * noz) * bounce
        -- if the triangle is between nodes, do forces on that too
        if #na > 6 then
          na[4], na[5], na[6], nb[4], nb[5], nb[6], nc[4], nc[5], nc[6] =
            na[4] + vdx/2, na[5] + vdy/2, na[6] + vdz/2,
            nb[4] + vdx/2, nb[5] + vdy/2, nb[6] + vdz/2,
            nc[4] + vdx/2, nc[5] + vdy/2, nc[6] + vdz/2
        end
        vx, vy, vz = vx - vdx, vy - vdy, vz - vdz
          --(vx - (2*(vx * nox)*nox)) * (1 + bounce),
          --(vy - (2*(vy * noy)*noy)) * (1 + bounce),
          --(vz - (2*(vz * noz)*noz)) * (1 + bounce)
          --(vx - (2*vx*nox)/len * nox) * bounce,
          --(vy - (2*vy*noy)/len * noy) * bounce,
          --(vz - (2*vz*noz)/len * noz) * bounce
        -- now that we've collided and stuff, we're done
        return nnx, nny, nnz, vx, vy, vz, true
      end
    end
    return nnx, nny, nnz, vx, vy, vz, false
  end

  local gravity = -9.8
  local function tick(delta)
    -- reset node force to 0
    for i=1, #nodes do
      local node = nodes[i]
      node[7], node[8], node[9] = 0, 0, 0
    end

    -- do beam/spring forces
    for i=1, #beams do
      local beam = beams[i]
      local na, nb = beam[1], beam[2]
      -- position of the end nodes
      local ax, ay, az, bx, by, bz = na[1],na[2],na[3], nb[1],nb[2],nb[3]

      -- Hooke's Law: the force produced by a spring is equal to the difference between its current and resting lengths, multiplied by its stiffness
      -- sf = ((B - A) - rL) * stiffness
      local sf = (distance(ax, ay, az, bx, by, bz) - beam[3]) * beam[4]

      -- Damping:
      -- velocity of the end nodes
      local avx, avy, avz, bvx, bvy, bvz = na[4],na[5],na[6], nb[4],nb[5],nb[6]
      -- normalized direction from A to B
      local adx, ady, adz = normalize(bx - ax, by - ay, bz - az)
      -- normalized direction from B to A - we need this later
      local bdx, bdy, bdz = normalize(ax - bx, ay - by, az - bz)
      -- velocity difference between A and B = Vb - Va
      local vdx, vdy, vdz = bvx - avx, bvy - avy, bvz - avz
      -- dot product: damping force, almost
      local dp = dot(adx, ady, adz, vdx, vdy, vdz)
      -- force += dot product * damping value
      sf = sf + dp * beam[5]
      -- to convert this force to a directional force on each end node, multiply it by the normalized direction from that node to the other for each node
      na[7], na[8], na[9] = na[7] + sf * adx, na[8] + sf * ady, na[9] + sf * adz
      nb[7], nb[8], nb[9] = nb[7] + sf * bdx, nb[8] + sf * bdy, nb[9] + sf * bdz
    end

    -- move nodes based on Euler integration
    -- might need to tweak motion integration in the future if it gets unstable
    for i=1, #nodes do
      local node = nodes[i]
      -- position / velocity / force / mass of that node
      local px, py, pz, vx, vy, vz, fx, fy, fz, mass = node[1], node[2], node[3],
        node[4], node[5], node[6], node[7], node[8], node[9], node[10]
      -- add gravitational force
      -- force applied by beams has already been calculated, see loop above
      fy = fy + (gravity * mass)

      -- add forces to node velocity
      vx = vx + (fx * delta) / mass
      vy = vy + (fy * delta) / mass
      vz = vz + (fz * delta) / mass
      --vx = math.max(-10, math.min(vx, 10))
      --vy = math.max(-10, math.min(vy, 10))
      --vz = math.max(-10, math.min(vz, 10))

      if not node[11] then -- do not move node if locked in place
        -- new node position
        local nnx, nny, nnz = px + vx * delta, py + vy * delta, pz + vz * delta
        local tmp = {nnx, nny, nnz}

        -- now check collisions, kind of
        local collided
        for j=1, #solids do
          nnx, nny, nnz, vx, vy, vz, collided = checkIntersection(nnx, nny, nnz, vx, vy, vz, node, tmp, solids[j])
          if collided then break end
        end

        if not collided then
          for j=1, #triangles do
            local tri = triangles[j]
            -- if the triangle contains this node, skip it
            if not (tri[1] == node or tri[2] == node or tri[3] == node) then
              nnx, nny, nnz, vx, vy, vz, collided = checkIntersection(nnx, nny, nnz, vx, vy, vz, node, tmp, tri)
              if collided then break end
            end
          end
        end

        -- store new position and velocity
        node[1], node[2], node[3],
        node[4], node[5], node[6] =
          nnx, nny, nnz, vx, vy, vz
      end
    end
  end

  local function updateEntities()
    for i=1, #entities do
      entities[i]:updatePolygons()
    end
  end

  return {
    internal = {
      nodes = nodes, beams = beams, triangles = triangles, solids = solids,
      entities = entities
    },
    addNode = nnode,
    addBeam = nbeam,
    addTriangle = ntri,
    addSolid = nsolid,
    tick = function(_, delta)
      -- CCPC Accelerated is SO MUCH FASTER
      local ITER = jit and 150 or 2
      delta = delta / 1000 / ITER
      for _=1, ITER do tick(delta) end
    end,
    setGravity = function(_,v)
      gravity = v or -9.8
    end,
    loadLuaBeam = loadLuaBeam,
    loadLuaBeamAsPineObject = loadLuaBeamAsPineObject,
    updateEntities = updateEntities,
    loadPineObject = loadPineObject
  }
end

return lib
