# Soft-Body Physics Playground

A simple soft-body physics engine designed for [ComputerCraft](https://tweaked.cc) and [Pine3D](https://pine3d.cc).  I wrote it in a week and a half for [PineJam 2023](https://jam.pine3d.cc/jam/2023).

Run `playground.lua` from this repository to launch a simple demo.

### How does it work?

Physics bodies are represented internally as sets of nodes and beams.  A node is an infinitely small point in space that has some amount of mass.  A beam is basically a torsion spring connecting nodes.  I also allow defining triangles between nodes so individual physics bodies should collide with each other.

Motion is done with Euler integration.  This is incredibly simple, though not entirely physically accurate, and can result in instability with too much damping.

Structures are defined in a file format I've chosen to call LuaBeam, which is really just a specially formatted Lua table.  See `cube.lbeam` in this repository for details on the format.

### How do I use this?

The entire physics engine is contained within `softbody.lua` and is not confined to ComputerCraft - though it contains some utility functions intended exclusively for Pine3D.

Create a new simulation instance (manages everything nicely-ish for you) with `softbody.newSimulation()`.  A simulation instance has the following methods:

  - `Simulation:addNode(x, y, z, mass[, locked]): nodeID` adds a node at the given coordinates with the given mass and returns its ID.  If `locked` is `true`, then the node will be locked in place and cannot be moved.  Returns the numerical ID of the new node.
  - `Simulation:addBeam(na, nb, stiffness, damping): beamID` creates a beam (spring) between two nodes `na` and `nb`.  `stiffness` and `damping` control the properties of the spring.  **Setting a damping value higher than about 4x node mass may result in instability.**  Returns the numerical ID of the new beam.
  - `Simulation:addTriangle(na, nb, nc[, bounce]): triangleID` creates a new triangle between three nodes `na`, `nb`, and `nc`.  `bounce`, if provided, should be a number between `0` and `1`, and controls how much velocity will be reflected when a node bounces off this triangle.  Its default value is `0.5`.  Returns the numerical ID of the new triangle.
  - `Simulation:addSolid(ax, ay, az, bx, by, bz, cx, cy, cz[, bounce]): solidID` creates a new "solid" triangle between three points in space.  This is effectively a triangle that is fixed in space and not dependent on nodes.
  - `Simulation:setGravity(gravity)` sets the simulation's gravity.  This defaults to `-9.8` - Earth gravity - but can be set to any number.
  - `Simulation:loadLuaBeam(path[, x, y, z]): model` loads a `.lbeam` file, converts it into a node/beam structure, and returns a table of the triangles that should be drawn.  This model is updated by `simulation:updateEntities()` and should not be modified.
  - `Simulation:tick(delta)` advances the simulation by `delta` time (should be in milliseconds).  This does not necessarily equate to only one simulation tick.
  - `Simulation:updateEntities()` updates the positions of all polygons in all entities registered by `loadLuaBeam` or `loadLuaBeamAsPineObject`.

  - **Pine3D Only** `Simulation:loadLuaBeamAsPineObject(frame, path[, x, y, z])` loads a `.lbeam` file, converts it into a structure, and returns a `PineObject` that may be given to Pine3D.  This `PineObject` is also stored internally.  `frame` is the `ThreeDFrame` object used for Pine3D rendering.  `path` is the path to an LuaBeam file.  `x, y, z`, if given, is the object's position offset.
  - **Pine3D Only** `Simulation:loadPineObject(object[, bounciness])` takes a `PineObject` and adds each of its polygons to the simulation as a solid.  Does not respect rotation.  If `bounciness` is given, it sets the `bounce` value for all created solids.  **Solids CANNOT be moved once they have been created.**

### Things to keep in mind
  - Collision detection happens `nodecount*(trianglecount + solidcount)` times per tick. On my machine I can run 8 nodes with 2048 polygons at about 35tps (≈573440/sec) in Cobalt (ComputerCraft's Lua runtime), 40tps (≈655360/sec) in [CraftOS-PC](https://craftos-pc.cc)'s modified PUC Lua runtime, and some 6000tps (≈49,152,000/sec) in CraftOS-PC _Accelerated_'s LuaJIT runtime.  The simulation will automatically adjust tick rates accordingly.
  - Damping (and to a much lesser extent stiffness) values that are too high will result in the entire simulation exploding.
  - Triangles with their vertices in the wrong order will not collide correctly.  The side that Pine3D renders is the side that will collide.
  - Nodes and model vertices are effectively the same thing.  This saves complex mesh deformation computations and generally makes my life much easier.

### Resources I found helpful

[Gonkee's soft-body physics video](https://www.youtube.com/watch?v=kyQP4t_wOGI) provides an excellent explanation of the physics involved (his examples are in 2D, but expanding to 3D is trivial).

Two [StackOverflow](https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d) and [StackExchange](https://math.stackexchange.com/questions/13261/how-to-get-a-reflection-vector) posts provided the basis for my collision implementation.
