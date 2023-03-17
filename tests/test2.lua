-- Z axis is unused for now and should always be 0

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
local function stv(a, b, c, d)
  local cx, cy, cz = cross(
    b[1] - a[1], b[2] - a[2], b[3] - a[3], -- b-a
    c[1] - a[1], c[2] - a[2], c[3] - a[3])
  return sign(dot(cx, cy, cz, -- c-a
    d[1] - a[1], d[2] - a[2], d[3] - a[3]) / 6) -- d-a / 6
end


-- nodes: all nodes in the simulation. each node is a point with some mass.
-- beams: all beams in the simulation. each beam connects two nodes.
-- triangles: triangles between three nodes. stores bounciness and friction.
-- solids: like triangles, but between fixed points in space. cannot move.
-- nodes and triangles collide, beams do not.
local nodes, beams, triangles, solids = {}, {}, {}, {}

local function nnode(x, y, z, mass, locked)
  -- pos[0], pos[1], pos[2]
  -- velocity[0], velocity[1], velocity[2]
  -- force[0], force[1], force[2]
  -- mass, positionLocked
  return {x, y, z, 0, 0, 0, 0, 0, 0, mass, locked}
end

local function nbeam(na, nb, stiffness, damping, maxDeform)
  -- first node, second node, rest length
  -- stiffness, damping
  -- maximum deformation before break
  na, nb = nodes[na] or na, nodes[nb] or nb
  local restLength = distance(na[1], na[2], na[3], nb[1], nb[2], nb[3])
  local beam = {na, nb, restLength, stiffness, damping, maxDeform}
  --na[11][beam] = true
  --nb[11][beam] = true
  return beam
end

local function checkIntersection(nnx, nny, nnz, vx, vy, vz, node, tmp, tri)
  local na, nb, nc = tri[1], tri[2], tri[3]
  -- Möller-Trumbore triangle intersection
  -- from https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d
  -- i don't fully understand this wizardry
  -- TODO: if this is too slow remove table usage
  local s1, s2 = stv(node, na, nb, nc), stv(tmp, na, nb, nc)
  if s1 ~= s2 then
    local s3, s4, s5 =
      stv(node, tmp, na, nb),
      stv(node, tmp, nb, nc),
      stv(node, tmp, nc, na)
    if s3 == s4 and s4 == s5 then
      local cx, cy, cz = cross(nb[1]-na[1], nb[2]-na[2], nb[3]-na[3],
        nc[1]-na[1], nc[2]-na[2], nc[3]-na[3])
      local t =
        dot(na[1]-node[1], na[2]-node[2], na[3]-node[3], cx, cy, cz) /
        dot(tmp[1]-node[1], tmp[2]-node[2], tmp[3]-node[3], cx, cy, cz)
      -- this is the point of intersection
      local ix, iy, iz =
        node[1] + t * (tmp[1] - node[1]),
        node[2] + t * (tmp[2] - node[2]),
        node[3] + t * (tmp[3] - node[3])
      -- compute normal of triangle surface: don't have to,
      -- done earlier as (cx, cy, cz)
      -- may have to invert it, possibly conditionally
      -- we have to normalize it, though, so do that
      local nox, noy, noz = normalize(cx, cy, cz)
      -- now set node position to point of intersection...
      nnx, nny, nnz = ix+0.5*sign(nox), iy+0.5*sign(noy), iz+0.5*sign(noz)
      term.setTextColor(colors.black)
      print(ix,nox,sign(nox),nnx,nny,nnz)
      -- and reflect velocity along surface, multiplying by
      -- surface bounciness (range 0 to 1)
      local bounce = tri[4] or 0.5
      vx, vy, vz =
        (vx-2*(vx * nox)*nox) * bounce,
        (vy-2*(vy * noy)*noy) * bounce,
        (vz-2*(vz * noz)*noz) * bounce
      -- now that we've collided and stuff, we're done
      return nnx, nny, nnz, vx, vy, vz, true
    end
  end
  return nnx, nny, nnz, vx, vy, vz, false
end

local gravity = -9.8
local epoch = rawget(os, "epoch")
local sleep = rawget(os, "sleep")
local lastTick = epoch("utc")
local function tick()
  local delta = epoch("utc") - lastTick
  lastTick = delta + lastTick
  delta = delta / 1000
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
    fy = fy - (gravity * mass)

    -- add forces to node velocity
    vx = vx + (fx * delta) / mass
    vy = vy + (fy * delta) / mass
    vz = vz + (fz * delta) / mass

    if not node[11] then -- do not move node if locked in place
      -- new node position
      local nnx, nny, nnz = px + vx * delta, py + vy * delta, pz + vz * delta
      local tmp = {nnx, nny, nnz}

      -- now check collisions, kind of
      local collided
      for j=1, #triangles do
        local tri = triangles[j]
        -- if the triangle contains this node, skip it
        if not (tri[1] == node or tri[2] == node or tri[3] == node) then
          nnx, nny, nnz, vx, vy, vz, collided = checkIntersection(nnx, nny, nnz, vx, vy, vz, node, tmp, tri)
          if collided then break end
        end
      end

      if not collided then
        for j=1, #solids do
          nnx, nny, nnz, vx, vy, vz, collided = checkIntersection(nnx, nny, nnz, vx, vy, vz, node, tmp, solids[j])
          if collided then break end
        end
      end

      -- store new position and velocity
      node[1], node[2], node[3],
      node[4], node[5], node[6] =
        nnx, nny, nnz, vx, vy, vz
    end

  end
end

-- simple structure like this:
--       1 (locked)
--      / \
--      2-3
--     /\ /\
--    4--5--6
--   /|><|><|\
--  7-8--9--A-B
-- /><|><|><|><\
-- C--D--E--F--G
-- char left/right = 10px, char up/down = 10px

local NMASS = 1

nodes[#nodes+1] = nnode(100,10, 0, NMASS) -- 1
nodes[#nodes+1] = nnode(90, 30, 0, NMASS) -- 2
nodes[#nodes+1] = nnode(110,30, 0, NMASS) -- 3
nodes[#nodes+1] = nnode(70, 50, 0, NMASS) -- 4
nodes[#nodes+1] = nnode(100,50, 0, NMASS) -- 5
nodes[#nodes+1] = nnode(130,50, 0, NMASS) -- 6
nodes[#nodes+1] = nnode(50, 70, 0, NMASS) -- 7
nodes[#nodes+1] = nnode(70, 70, 0, NMASS) -- 8
nodes[#nodes+1] = nnode(100,70, 0, NMASS) -- 9
nodes[#nodes+1] = nnode(130,70, 0, NMASS) -- A (10)
nodes[#nodes+1] = nnode(150,70, 0, NMASS) -- B (11)
nodes[#nodes+1] = nnode(30, 90, 0, NMASS) -- C (12)
nodes[#nodes+1] = nnode(70, 90, 0, NMASS) -- D (13)
nodes[#nodes+1] = nnode(100,90, 0, NMASS) -- E (14)
nodes[#nodes+1] = nnode(130,90, 0, NMASS) -- F (15)
nodes[#nodes+1] = nnode(180,90, 0, NMASS) -- G (16)

local BSTIFF, BDAMP = 50, 1

-- main structure
beams[#beams+1] = nbeam(1, 2, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(1, 3, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(2, 3, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(2, 4, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(2, 5, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(3, 5, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(3, 6, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(4, 5, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(5, 6, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(4, 7, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(4, 8, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(5, 9, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(6, 10,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(6, 11,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(7, 8, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(8, 9, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(9, 10,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(10,11,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(7, 12,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(8, 13,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(9, 14,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(10,15,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(11,16,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(12,13,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(13,14,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(14,15,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(15,16,BSTIFF, BDAMP, 0)
-- cross-bracing
beams[#beams+1] = nbeam(4, 9, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(8, 5, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(5, 10,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(6, 9, BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(7, 13,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(8, 12,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(8, 14,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(9, 13,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(9, 15,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(10,14,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(10,16,BSTIFF, BDAMP, 0)
beams[#beams+1] = nbeam(11,15,BSTIFF, BDAMP, 0)

-- add a triangle, for testing
solids[#solids+1] = {
  {-10, 150, 10},
  {-10, 150, -10},
  {316, 150, 0},
  0.9
}

local term = rawget(_G, "term")
local colors = rawget(_G, "colors")
local paintutils = rawget(_G, "paintutils")
local a, b, c = pcall(function()
  term.setGraphicsMode(true)
  while true do
    term.setFrozen(true)
    term.clear()
    for i=1, #beams do
      local B = beams[i]
      local a, b = B[1], B[2]
      paintutils.drawLine(a[1], a[2], b[1], b[2], colors.white)
    end

    for i=1, #nodes do
      if nodes[i][11] then
        term.drawPixels(nodes[i][1]-3, nodes[i][2]-3, colors.red, 6, 6)
      else
        term.drawPixels(nodes[i][1]-2, nodes[i][2]-2, colors.orange, 4, 4)
      end
    end
    term.setFrozen(false)
    sleep(0.05)
    tick()
  end
end, debug.traceback)
term.setFrozen(false)
term.setGraphicsMode(false)
term.setTextColor(colors.white)
term.setBackgroundColor(colors.black)
print(a, b, c)
