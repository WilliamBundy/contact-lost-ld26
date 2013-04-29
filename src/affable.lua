--[[ 
Copyright 2013 William Bundy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--]]

module(..., package.seeall)

require "middleclass"
Stateful = require "stateful"

null = {}

version = "0-0-2"

Vector = class("Vector", Object)

function Vector:initialize()
  self.x = 0
  self.y = 0
  self.z = 0
end
function newVector(x,y,z)
  local v = Vector:new()
  v.x = x or 0
  v.y = y or 0
  v.z = z or 0
  return v
end

function Vector:__add(other)
  return newVector(self.x+other.x, self.y+other.y, self.z+other.z)
end

function Vector:__sub(other)
  return newVector(self.x-other.x, self.y-other.y, self.z-other.z)
end

function Vector:__mul(scalar)
  return newVector(self.x*scalar, self.y*scalar, self.x*scalar)
end

function Vector:__div(scalar)
  return newVector(self.x/scalar, self.y/scalar, self.z/scalar)
end

function Vector:__tostring()
  return "<"..tostring(self.x).." "..tostring(self.y).." "..tostring(self.z)..">"
end

function Vector:__unm()
  return newVector(self.x*-1, self.y*-1, self.z*-1)
end

function Vector:__mod(other)
  return newVector(
    self.y*other.z-self.z*other.y, 
    -1*(self.x*other.z-self.z*other.x),
    self.x*other.y-self.y*other.x)
end

function Vector:__concat(other)
  return self.x*other.x+self.y*other.y+self.z*other.z
end

function Vector:add(other)
  self.x = self.x + other.x
  self.y = self.y + other.y
  self.z = self.z + other.z
  return self
end

function Vector:addScaled(other, scalar)
  local scalar = scalar or 1
  self.x = self.x + (other.x * scalar)
  self.y = self.y + (other.y * scalar)
  self.z = self.z + (other.z * scalar)
  return self
end

function Vector:addXYZ(x, y, z)
  self.x = self.x + (x or 0)
  self.y = self.y + (y or 0)
  self.z = self.z + (z or 0)
  return self
end

function Vector:addXYZScaled(x,y,z,scalar)
  local scalar = scalar or 1
  print(tostring(self))
  self.x = self.x + ((x or 0) * scalar)
  self.y = self.y + ((y or 0) * scalar)
  self.z = self.z + ((z or 0) * scalar)
  return self
end

function Vector:setXYZ(x, y, z)
  self.x = x or 0
  self.y = y or 0
  self.z = z or 0
  return self
end

function Vector:subtract(other)
  self.x = self.x - other.x
  self.y = self.y - other.y
  self.z = self.z - other.z
  return self
end

function Vector:scale(scalar)
  scalar = scalar or 1
  self.x = self.x * scalar
  self.y = self.y * scalar
  self.z = self.z * scalar 
  return self
end

function Vector:negate()
  self:scale(-1)
  return self
end

function Vector:dotProduct(other)
  return self.x*other.x + self.y*other.y + self.z*other.z
end

function Vector:crossProduct(other)
  return self.y*other.z-self.z*other.y, 
    -1*(self.x*other.z-self.z*other.x),
    self.x*other.y-self.y*other.x
end

function Vector:__eq(other)
  return (self.x==other.x) and (self.y==other.y) and (self.z==other.z)
end

function Vector:rotateOrigin(dtheta)
  self.x = math.cos(dtheta) * self.x - math.sin(dtheta) * self.y
  self.y = math.cos(dtheta) * self.y + math.sin(dtheta) * self.x
end

function Vector:rotate(dtheta, center)
  local x = center.x - self.x
  local y = center.y - self.y
  self.x = math.cos(dtheta) * x - math.sin(dtheta) * y
  self.y = math.cos(dtheta) * y + math.sin(dtheta) * x
end

function Vector:magnitude()
  return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z)
end

function Vector:magnitude2()
  return self.x*self.x+self.y*self.y+self.z*self.z
end

function Vector:getNormalized()
  return self / self:magnitude()
end

function Vector:get2DNormal()
  local mag = self:magnitude()
  local nx = self.x * self.x / mag
  local ny = self.y * self.y / mag
  return newVector(-ny, nx, self.z)
end

function Vector:get2DAngle()
  return math.atan2(-self.y, self.x)
end

function Vector:getAngleBetween(other)
  local dot = self:dotProduct(other)
  local mag = self:magnitude() * other:magnitude()
  return math.acos(dot/mag)
end 

function Vector:getAngleBetweenXY(x,y)
  local dx = x - self.x
  local dy = y - self.y 

  return math.atan2(dy, dx)
end

Rectangle = class("Rectangle")

function Rectangle:initialize()
  self.position = newVector()
  self.width = 0
  self.height = 0
end
function newRectangle(w, h, x, y, z)
  local rect = Rectangle:new()
  rect.position.x = x or 0
  rect.position.y = y or 0
  rect.position.z = z or 0
  rect.width = w or 0
  rect.height = h or 0
  return rect
end

function Rectangle:top() return self.position.y end
function Rectangle:bottom() return self.position.y+self.height end
function Rectangle:left() return self.position.x end
function Rectangle:right() return self.position.x+self.width end

function Rectangle:centerX()
  return self.position.x - self.width/2
end

function Rectangle:centerY()
  return self.position.y - self.height/2
end

function Rectangle:containsPoint(pt)
  return (
    (pt.x>self.left())
    and (pt.x<self.right())
    and (pt.y>self.top())
    and (pt.y<self.bottom()))
end

function Rectangle.intersects(a,b)
  return  (
    (a:left() < b:right())
    and (a:right() > b:left())
    and (a:bottom() > b:top())
    and (a:top() < b:bottom())
    )
end

function getRectUnderPoint(rectangles, point)
  local highestRect = newRectangle(0, 0, 0, 0, -1000000)
  for i, rect in pairs(rectangles) do
    if (rect.position.z > highestRect.position.z
        and rect:containsPoint(point)) then
      highestRect = rect
    end
  end
end

function getIntersectingRectangles(testangle, rectangles)
  intersectors = {}
  for i,rect in ipairs(rectangles) do
    if testangle:intersects(rect) then
      table.insert(intersectors, rect)
    end
  end
  return intersectors
end
--TODO For rectangle: overlap and intersects


-- So the reactor-core-state pattern is derived from things
-- I've done in haXe and C#, so there might be modifications
-- that a lua guru would think of that I wouldn't.

-- okay, so we have things like stateful and beholder now
-- I'm not sure I need an event system any more.
-- 

Reactor = class("Reactor")
Reactor:include(Stateful)
function Reactor:initialize()
end
function newReactor()
  r = Reactor:new()
  return r
end
function Reactor:_start()
  self:start()
end
function Reactor:start()

end
function Reactor:_update(dt)
  self:update(dt)
end
function Reactor:_draw()
  self:draw()
end
function Reactor:draw()

end
function Reactor:update(dt)
end
function Reactor:stop()

end
function Reactor:_onKeyPressed(key, unicode) self:onKeyPressed(key, unicode) end
function Reactor:onKeyPressed(key, unicode) end

function Reactor.physicsBeginContact(f1,f2,c) end
function Reactor.physicsEndContact(f1,f2,c) end
function Reactor.physicsPreSolve(f1,f2,c) end
function Reactor.physicsPostSolve(f1,f2,c) end


Sprite = class("Sprite")

function Sprite:initialize()
  self.region = newRectangle(0, 0, 0, 0, 0)
  self.quad = null
  self.originOffset = newVector(0,0,0)
  self.scale = newVector(1,1,1)
  self.rotation = 0
  self.image = null
  self.dirty = 2
  self.batch = null
  self.position = self.region.position
  self.lastQuadID = -1
end
function newSprite(image, batch, quad)
  assert(image ~= nil, "Error: image must be non-null")
  local sprite = Sprite:new()
  sprite.image = image
  sprite.batch = batch
  sprite.quad = quad or love.graphics.newQuad(
    0,0, 
    image:getWidth(),image:getHeight(), 
    image:getWidth(),image:getHeight())
  local x,y,w,h = sprite.quad:getViewport()
  sprite.region.width = w
  sprite.region.height = h
  return sprite
end

function Sprite:updateQuad(x,y, width, height)
  self.quad = love.graphics.newQuad(x,y,width,height,self.image.getWidth(),self.image.getHeight())
  self.region.width = width
  self.region.height = height
end

function Sprite:onDrawBatch()
  --if dirty >= 1 then
    self.lastQuadID = self.batch:addq(
      self.quad,
      self.position.x,
      self.position.y,
      self.rotation,
      self.scale.x,
      self.scale.y,
      self.originOffset.x,
      self.originOffset.y,
      0,0)
  --  if dirty ~= 2 then dirty = 0 end
 -- end
end

function Sprite:onDraw()
  love.graphics.draw(
      self.image,
      self.position.x,
      self.position.y,
      self.rotation,
      self.scale.x,
      self.scale.y,
      self.originOffset.x,
      self.originOffset.y,
      0,0)
end