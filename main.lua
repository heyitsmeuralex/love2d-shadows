function love.conf(t)
  t.window.title = "love2d-shadows"
  t.window.width = 800
  t.window.height = 600
  --t.window.msaa = 2
end

Terrain = {}

function Terrain.reset()
  for i = #Terrain.Stuff, 1, -1 do
    Terrain.Stuff[i].Fixture:destroy()
    Terrain.Stuff[i] = nil
  end
end

function Terrain.randomize()
  -- Generate some random shapes
  for i = 1, 30 do
    local p = {}

    p.x, p.y = math.random(0, 750), math.random(0, 550)

    -- Rectangle
    local w, h, r = math.random() * 20 + 40, math.random() * 20 + 40
    p.Shape = love.physics.newRectangleShape(p.x, p.y, w, h)

    p.Fixture = love.physics.newFixture(Terrain.Body, p.Shape)

    Terrain.Stuff[i] = p
  end
end

function Terrain.points()
  local points = {}

  --[
  -- This stuff loves to cause rendering artifiacts. TODO: work around
  for x = 1, 800, 20 do
    points[#points + 1] = { x, 1 }
  end

  for x = 1, 800, 20 do
    points[#points + 1] = { x, 600 }
  end

  for y = 1, 600, 20 do
    points[#points + 1] = { 1, y }
  end

  for y = 1, 600, 20 do
    points[#points + 1] = { 800, y }
  end
  --]]

  for i, v in ipairs(Terrain.Stuff) do
    local poly = { Terrain.Body:getWorldPoints(v.Shape:getPoints()) }

    local k = 1
    while k < #poly do
      points[#points + 1] = { poly[k], poly[k + 1] }

      k = k + 2
    end
  end

  return points
end

function love.load()
  World = love.physics.newWorld()

  Terrain.Body = love.physics.newBody(World, 0, 0, "static")
  Terrain.Stuff = {}
  Terrain.randomize()
end

function love.mousepressed()
  Terrain.reset()
  Terrain.randomize()
end

function love.update(dt)
  World:update(dt)

  local x, y = love.mouse.getPosition()
  local points = Terrain.points()

  x = math.max(x, 0.1)
  y = math.max(y, 0.1)

  -- This is a hack because sorting is not fun
  AngleOffset = 180
  local raysAngleDifferent = castRays(x, y, points)
  AngleOffset = 270

  Rays = {
    ox = x, oy = y,

    castRays(x, y, points), raysAngleDifferent,
    castRays(x + 5, y, points), castRays(x - 5, y, points),
    castRays(x, y + 5, points), castRays(x - 5, y, points),
  }
end

function castRays(x, y, points)
  local Rays = {}

  for r, p in ipairs(points) do
    ray = { x1 = x, y1 = y, x2 = p[1], y2 = p[2] }

    Rays[r] = ray

    World:rayCast(ray.x1, ray.y1, ray.x2, ray.y2, function(fixture, x, y, xn, yn, fraction)
      -- We want the closest collision.

      if distance(Rays[r].x1, Rays[r].y1, Rays[r].x2, Rays[r].y2) > distance(Rays[r].x1, Rays[r].y1, x, y) then
        Rays[r].x2 = x
        Rays[r].y2 = y
      end

      return 1
    end)

    Rays[r].angle = angleTo(Rays[r].x1, Rays[r].y1, Rays[r].x2, Rays[r].y2)
  end

  return Rays
end

function drawRaysPoly(x, y, rays)
  -- Make a polygon using the rays
  local rayPoly = { x, y }

  for i, p in spairs(rays, function(rays, ai, bi)
    local a = rays[ai]
    local b = rays[bi]

    return a.angle > b.angle
  end) do
    rayPoly[#rayPoly + 1] = p.x2
    rayPoly[#rayPoly + 1] = p.y2
  end

  rayPoly[#rayPoly + 1] = x
  rayPoly[#rayPoly + 1] = y

  -- Trianglulate and render it
  pcall(function()
    local tris = love.math.triangulate(rayPoly)

    for _, tri in ipairs(tris) do
      love.graphics.polygon("fill", tri)
    end
  end)
end

function love.draw()
  -- Use a circlular stencil (mask)
  love.graphics.stencil(function()
    love.graphics.circle("fill", love.mouse.getX(), love.mouse.getY(), 100)
  end, "replace", 1)
  --love.graphics.setStencilTest("equal", 1)

  love.graphics.setColor(20, 20, 20)
  drawRaysPoly(Rays.ox, Rays.oy, Rays[3])
  drawRaysPoly(Rays.ox, Rays.oy, Rays[4])
  drawRaysPoly(Rays.ox, Rays.oy, Rays[5])
  drawRaysPoly(Rays.ox, Rays.oy, Rays[6])

  love.graphics.setColor(30, 30, 30)
  drawRaysPoly(Rays.ox, Rays.oy, Rays[1])
  drawRaysPoly(Rays.ox, Rays.oy, Rays[2])

  love.graphics.setStencilTest() -- Stop using stencil

  -- Draw terrain
  love.graphics.setColor(255, 255, 255)
  for i, v in ipairs(Terrain.Stuff) do
    love.graphics.polygon("line", Terrain.Body:getWorldPoints(v.Shape:getPoints()))
  end
end

function distance(x1, y1, x2, y2)
  return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

AngleOffset = 270

function angleTo(x1, y1, x2, y2)
  local n = AngleOffset - math.atan2(y1 - y2, x1 - x2) * 180 / math.pi
  return n % 360
end

function spairs(t, order)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end

  -- if order function given, sort by it by passing the table and keys a, b,
  -- otherwise just sort the keys
  if order then
    table.sort(keys, function(a,b) return order(t, a, b) end)
  else
    table.sort(keys)
  end

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end
