-- TODO: perhaps inter-node collisions?
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

local nodes, beams, triangles = {}, {}, {}

local function nnode(x, y, z, mass)
  -- pos[0], pos[1], pos[2]
  -- velocity[0], velocity[1], velocity[2]
  -- force[0], force[1], force[2]
  -- mass
  -- {beams}
  return {x, y, z, 0, 0, 0, 0, 0, 0, mass, {}}
end

local function nbeam(na, nb, stiffness, damping, maxDeform)
  -- first node, second node, rest length
  -- stiffness, damping
  -- maximum deformation before break
  local restLength = distance(na[1], na[2], na[3], nb[1], nb[2], nb[3])
  local beam = {na, nb, restLength, stiffness, damping, maxDeform}
  na[11][beam] = true
  nb[11][beam] = true
  return beam
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
  for i=1, #nodes do
    local node = nodes[i]
    -- position / velocity / force / mass of that node
    local px, py, pz, vx, vy, vz, fx, fy, fz, mass = table.unpack(node)
    -- add gravitational force
    -- force applied by beams has already been calculated, see loop above
    fy = fy + (gravity * mass)

    -- add forces to node velocity
    vx = vx + (fx * delta) / mass
    vy = vy + (fy * delta) / mass
    vz = vz + (fz * delta) / mass

    -- add velocity * deltatime to node position, and store new velocity
    node[1], node[2], node[3],
    node[4], node[5], node[6] =
      px + vx * delta, py + vy * delta, pz + vz * delta,
      vx, vy, vz
  end

  for i=1, #solids do
  end
end
