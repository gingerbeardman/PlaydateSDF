-- DEMO: Draws some SDF defined shapes and bouncing a ball amongst them

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "Source/SDF2D.lua"

pd = playdate
gfx	= pd.graphics
vec2 = pd.geometry.vector2D.new
pd.display.setRefreshRate(40) -- only 40 for 2 balls
playdate.setMinimumGCTime(5)

local sw, sh = pd.display.getSize()

--[[
Calculate a normalized gradient from nearby points to find the direction of the
shortest path to the surface. We compute the gradient vector, and then normalize
the magnitude to remove local variations of the slope. This approach provides a 
directionally accurate vector for collision responses or for guiding movements.
--]]
function calcNormalizedGradient(p, f, o, params) -- p:point, o:offset, f:sdf, params:params to sdf
	local eps = 1e-4
	local ds = {f(vec2(p.x + eps, p.y)-o, table.unpack(params)),
				f(vec2(p.x - eps, p.y)-o, table.unpack(params)),
				f(vec2(p.x, p.y + eps)-o, table.unpack(params)),
				f(vec2(p.x, p.y - eps)-o, table.unpack(params))}
	return vec2((ds[1]-ds[2])/(2*eps), (ds[3]-ds[4])/(2*eps)):normalized()
end

-- We need a drawing function for each of our shape SDF functions
function drawDemoCircle(p,t) -- for sdCircle
	gfx.setColor(playdate.graphics.kColorBlack)
	gfx.fillCircleAtPoint(p.x, p.y, t[1])
end

function drawDemoBox(p,t) -- for sdBox
	gfx.setColor(playdate.graphics.kColorBlack)
	gfx.fillRect(p.x-t[1].x, p.y-t[1].y, t[1].x*2, t[1].y*2)
end

function drawOrientedBox(p,q) -- for sdOrientedBox
	local s, e, t = table.unpack(q)
	local d = (e-s) / (e-s):magnitude()
	local P = vec2(-d.y, d.x)
	local c1,c2,c3,c4 = s+(P*t), s-(P*t), e-(P*t), e+(P*t)
	gfx.setColor(playdate.graphics.kColorBlack)
	gfx.fillPolygon(c1.x, c1.y, c2.x, c2.y, c3.x, c3.y, c4.x, c4.y, c1.x, c1.y )
end

function noDraw() end

-- Demo: We can invent a new shape from primitives. Distance is the min 
-- of the primitives. Here we combine two rounded boxes into a "DPad" shape. 
-- Demo: if we don't always need true distance when far away, we can first 
-- run a cheaper check like sdCircle that encloses the shape.
function sdDPad(p, b)
	if sdCircle(p, b.x+b.y) > 0 then return math.huge end -- shortcut
	local br = vec2(b.y, b.x)
	return math.min(sdRoundedBox(p, b, {b.y, b.y, b.y, b.y}),
					sdRoundedBox(p, br, {b.y, b.y, b.y, b.y}))
end

function drawDemoDPad(p,t) -- for sdDPad()
	local a,b = t[1]:unpack()
	gfx.setColor(playdate.graphics.kColorBlack)
	gfx.fillRect(p.x-a+b, p.y-b, (a-b)*2, b*2)
	gfx.fillCircleAtPoint(p.x-a+b, p.y, b)
	gfx.fillCircleAtPoint(p.x+a-b, p.y, b)
	gfx.fillRect(p.x-b, p.y-a+b, b*2, (a-b)*2)
	gfx.fillCircleAtPoint(p.x, p.y-a+b, b)
	gfx.fillCircleAtPoint(p.x, p.y+a-b, b)
end


local abs = math.abs
local function opOnion(p, f, params, r) return abs(f(p, table.unpack(params))) - r end

-- Demo: We can also "hollow out" a new shape from any primitive.
function sdScreen(p, b)
-- function opOnion(p, f, params, r) return math.abs(f(p, table.unpack(params))) - r end
	return opOnion(p, sdBox, {b}, 7)
end
	
function drawScreen(p,t) -- for sdScreen
	gfx.setColor(playdate.graphics.kColorBlack)
	gfx.fillRect(p.x-t[1].x-t[2], p.y-t[1].y-t[2], (t[1].x+t[2])*2, (t[1].y+t[2])*2)
	gfx.setColor(playdate.graphics.kColorClear)
	gfx.fillRect(p.x-t[1].x+t[2], p.y-t[1].y+t[2], (t[1].x-t[2])*2, (t[1].y-t[2])*2)
end

function drawNGonByApothem(p, q)
	local apothem, n = table.unpack(q)
	local poly = pd.geometry.polygon.new(n)
	for i = 0, n-1 do
		local x = p.x + apothem / math.cos(math.pi / n) * math.cos((2 * math.pi) / n * i + math.pi/2)
		local y = p.y + apothem / math.cos(math.pi / n) * math.sin((2 * math.pi) / n * i + math.pi/2)
		poly:setPointAt(i+1,x,y)
	end
	poly:close()
	gfx.setColor(playdate.graphics.kColorBlack)
	gfx.fillPolygon(poly)
end

-- A table to hold the scene of objects.
-- It's better/easier to use Sprites with the management helpers they inherit, though.
terrain = {
	{sdScreen, vec2(200,90), {vec2(110,60), 3}, drawScreen},
	{sdCircle, vec2(230,180), {15}, drawDemoCircle},
	{sdCircle, vec2(280,180), {15}, drawDemoCircle},
	{sdPentagon, vec2(200,65), {35, 5}, drawNGonByApothem},
	{sdOrientedBox, vec2(0,0), {vec2(120,100), vec2(200,130), 8}, drawOrientedBox},
	{sdDPad, vec2(130,200), {vec2(32,8)}, drawDemoDPad},
	{sdBox, vec2(0,sh/2), {vec2(sw/6,sh/2+5)}, drawDemoBox}, -- left border
	{sdBox, vec2(sw,sh/2), {vec2(sw/6,sh/2+5)}, drawDemoBox}, -- right border
	{sdBox, vec2(sw/2,-5), {vec2(sw/2+5,5)}, noDraw}, -- top border
	{sdBox, vec2(sw/2,sh+5), {vec2(sw/2+5,5)}, noDraw}, -- bottom border
}

function drawShapes(terrain) -- draw the scene
	local backgroundImage = gfx.image.new(sw,sh)
	gfx.pushContext(backgroundImage)
	for _, o in ipairs(terrain) do 
		o[4](o[2],o[3])
	end
	gfx.popContext()
	return backgroundImage
end

-- Model the ball as a sprite with radius, position, and velocity.

class("Ball").extends(gfx.sprite)
function Ball:init(x, y)
	Ball.super.init(self)
	self.position = vec2(x, y)
	self.velocity = vec2(0.5, 0.5)
	self.radius = 3
	self:setImage(self:draw())
	self:setCollideRect( 0, 0, self:getSize() )	
	self:moveTo(self.position:unpack())
end

function Ball:draw(radius)
	local im = gfx.image.new(2 * self.radius, 2 * self.radius)
	gfx.pushContext(im)
	gfx.fillCircleAtPoint(self.radius, self.radius, self.radius)
	gfx.popContext()
	return im	
end

function Ball:update()
	self:manageCollisions()
	self:moveTo(self.position:unpack())
end

function Ball:manageCollisions()

	for i=1, #terrain do
		local o = terrain[i]
		local f = o[1]
		local dist = f(self.position-o[2], table.unpack(o[3]))
		if dist < self.radius then
			self:resolveCollision(dist, f, o[2], o[3])
		end
		self.position = self.position + self.velocity
	end

end

function Ball:resolveCollision(dist, f, offset, params)
	local normal = calcNormalizedGradient(self.position,f,offset,params)
	self.position = self.position + normal * (self.radius - dist) -- push penetration out
	self.velocity = (self.velocity - self.velocity:projectedAlong(normal) * 2)
end

-- Override sprite response handling for multiple collisions by allowing overlap
function Ball:collisionResponse(other) return "overlap" end

-- Render the terrain as an image
backgroundImage = drawShapes(terrain)

-- add Ball sprites
Ball(270, 60):add()
Ball(270, 190):add()

function playdate.update()

	gfx.sprite.update()
	backgroundImage:draw(0, 0)
	playdate.drawFPS(100, 40)
	
end
