require "middleclass"
Stateful = require "stateful"
gamera = require "gamera"
local cron = require "cron"
require "beholder"
require "affable"

function round(x)
  if x - math.floor(x) < .5 then return math.floor(x)
  else return math.ceil(x) end
end

function newEnemy(x,y, attack, defense, maxHealth, speed, agression, nightModifier, enemyLevel)
  local enemy = {attack=attack, defense=defense, maxHealth=maxHealth, health=maxHealth, 
    speed=speed, agression=agression, nightModifier=nightModifier, enemyLevel=enemyLevel}
  enemy.body = love.physics.newBody(reactor.world, x,y, "dynamic")
  enemy.body:setAngle(rand(0,math.pi*2))
  enemy.body:setLinearDamping(10)
  enemy.body:setAngularDamping(4)
  enemy.shape = love.physics.newPolygonShape(0, -8*enemyLevel, -8*enemyLevel,8*enemyLevel, 8*enemyLevel,8*enemyLevel )
  enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape)
  local quad = love.graphics.newQuad(16*(enemyLevel-1), 0, 16,16, 256,256) --hardcoded image
  enemy.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, quad)
  enemy.sprite.originOffset:setXYZ(8,8)
  enemy.sprite.scale:setXYZ(enemyLevel, enemyLevel)
  enemy.isEnemy = true
  enemy.fixture:setUserData(enemy)
  return enemy
end

projectileQuad = love.graphics.newQuad(0, 16, 16,16, 256,256)
function newProjectile(vx, vy, x,y, damage)
  local p = {damage=damage}
  p.body = love.physics.newBody(reactor.world, x,y, "dynamic")
  p.shape = love.physics.newCircleShape(4)
  p.fixture = love.physics.newFixture(p.body, p.shape, 1)
  p.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, projectileQuad)
  p.sprite.originOffset:setXYZ(8,8)
  p.sprite.scale:setXYZ(.5,.5)
  p.isProjectile = true
  p.body:setLinearVelocity(vx, vy)
  p.body:setAngularVelocity(rand(0, math.pi/2))
  p.fixture:setUserData(p)
  p.fixture:setRestitution(0)
  return p
end

rockQuad = love.graphics.newQuad(64,0, 32,32, 256,256)
function newRock(x,y,s,a)
  local r = {}
  r.body = love.physics.newBody(reactor.world, x,y, "static")
  r.shape = love.physics.newRectangleShape(32*s,32*s)
  r.fixture = love.physics.newFixture(r.body, r.shape)
  r.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, rockQuad)
  r.sprite.originOffset:setXYZ(16,16)
  r.sprite.scale:setXYZ(s,s)
  r.sprite.rotation = a
  r.body:setAngle(a)
  r.sprite.position:setXYZ(x,y)
  r.isRock = true
  r.fixture:setUserData(r)
  return r
end

function newMachine(x,y,t)
  local m = {}
  local mx, my = round(x/16),round(y/16)
  reactor.machineGrid[getMachineIndex(mx, my)] = m
  m.inventory = {}
  for i=1,10 do table.insert(m.inventory, "nothing") end
  m.gridIndex = getMachineIndex(mx,my)
  m.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, t.quad)
  m.sprite.originOffset:setXYZ(8,8)
  m.sprite.position:setXYZ(mx*16, my*16)
  m.tx = mx
  m.ty = my
  m.isMachine = true
  m.machineType = t.machineType
  m.t = t
  if t.onCreate then t.onCreate(m) end
  return m
end

capsuleQuad = love.graphics.newQuad(16, 16, 16,16, 256,256)
function newCapsule(x,y,n,containsType)
  local c = {}
  c.body = love.physics.newBody(reactor.world, x,y, "dynamic")
  c.shape = love.physics.newCircleShape(8)
  c.fixture = love.physics.newFixture(c.body, c.shape, 2)
  c.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, capsuleQuad)
  c.sprite.originOffset:setXYZ(8,8)
  c.isCapsule = true
  c.containsType= containsType -- either "item" or "schema"
  c.name = n
  c.fixture:setUserData(c)
  c.body:setLinearDamping(10.0)
  c.body:setAngularDamping(5.0)
  c.body:setAngle(rand(0,math.pi*2))
  c.active = true
  return c
end

function rand(n, m)
  local r = math.random()
  return r * (m-n) + n 
end

function love.load()
  love.graphics.setDefaultImageFilter("nearest", "nearest")
--  math.randomseed(1337); math.random(); math.random(); math.random()
  reactor = affable.newReactor()
  reactor:_start()
  reactor.gamera = gamera.new(0,0,1024,2048*32)
  --reactor.gamera:setScale(2.0)
  reactor.uilines = {}

  reactor.gunSound = love.audio.newSource("gun.ogg", "static")
  reactor.gunSound:setVolume(.5)
  reactor.stepSound = love.audio.newSource("footstep.ogg", "static")
  reactor.bgmSound = love.audio.newSource("music.ogg")
  reactor.bgmSound:setLooping(true)
  reactor.bgmSound:setVolume(.5)
  reactor.bgmSound:play()
  reactor.playingSounds = true
  reactor.playingMusic = true


  reactor.terrainImages = {
    water = love.graphics.newImage("slice0.png"),
    grass = love.graphics.newImage("slice1.png"),
    desert = love.graphics.newImage("slice2.png"),
    temple = love.graphics.newImage("slice3.png")
  }
  reactor.terrainSequence = {
    "water", --1
    "grass","grass","grass","grass","grass","grass","grass","grass", --8
    "desert","desert","desert","desert","desert","desert","desert","desert", --16
    "desert","desert","desert","desert","desert","desert","desert","desert",
    "temple","temple","temple","temple", "temple","temple", --6 -- it's an open air temple.
    "water"
  }
  reactor.terrainRectangles = {}
  for i=1, #reactor.terrainSequence do
    reactor.terrainRectangles[i] = affable.newRectangle(1024,2048,0,2048*(i-1))
    reactor.terrainRectangles[i].index = i
  end

  reactor.entityImage = love.graphics.newImage("entitysheet.png")
  reactor.entityBatch = love.graphics.newSpriteBatch(reactor.entityImage, 4096)
 
  love.physics.setMeter(20) -- should work fine for now.
  reactor.world = love.physics.newWorld(0, 0, true)
  reactor.world:setCallbacks(
    function(f1,f2,c) reactor.physicsBeginContact(f1,f2,c) end,
    function(f1,f2,c) reactor.physicsEndContact(f1,f2,c) end,
    function(f1,f2,c) reactor.physicsPreSolve(f1,f2,c) end,
    function(f1,f2,c) reactor.physicsPostSolve(f1,f2,c) end
    )

  reactor.bounds = {}
  reactor.bounds.body = love.physics.newBody(reactor.world, 0,0, "static")
  reactor.bounds.shape = love.physics.newChainShape(true, 0,2048, 1024,2048, 1024,31*2048, 0, 31*2048, 0,2048)
  reactor.bounds.fixture = love.physics.newFixture(reactor.bounds.body, reactor.bounds.shape)
  reactor.bounds.fixture:setUserData("bounds")
  reactor.player = {}
  player = reactor.player
  reactor.player.sprite = affable.newSprite(love.graphics.newImage("playerfinal.png"))
  reactor.player.sprite.originOffset:setXYZ(32,34)
  reactor.player.body = love.physics.newBody(reactor.world, 512, 2048+32, "dynamic")
  reactor.player.shape = love.physics.newCircleShape(7)
  reactor.player.fixture = love.physics.newFixture(
    reactor.player.body, reactor.player.shape, 10)
  reactor.player.moveSpeed = 2000
  reactor.player.body:setLinearDamping(10)
  reactor.player.isPlayer = true
  reactor.player.fixture:setUserData(reactor.player)
  reactor.player.isAlive = true

  --Dvorak keys
  --reactor.keyconfig = {up=",",left="a",right="e",down="o"}
  reactor.keyconfig = {up="w",left="a",right="d",down="s"}

  reactor.player.maxHealth = 100
  reactor.player.health = 100
  reactor.player.hunger = 16
  reactor.player.maxHunger = 16
  reactor.projectiles = {}
  reactor.player.projectileDamage = 2
  reactor.player.projectileSpeed = 500
  reactor.player.defense = 0
  reactor.player.inventory = {"organicfibre", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing"}
  reactor.player.schemas = {"food"}
  reactor.player.currentSchemaID = 1
  reactor.itemTypes = {}
  function addItem(t)
    reactor.itemTypes[t.id] = t
    reactor.itemTypes[t.index] = t
  end
  addItem {id="nothing", name="Nothing", index=0}
  addItem {id="food", name="Potato", index=1, recipe={"organicfibre"}, mechFurnace="cookedfood"}
  addItem {id="metal", name="Metal Ingot", index=2}
  addItem {id="organicfibre", name="Organic Fibre", index=3}
  addItem {id="syntheticfibre", name="Synthetic Fibre", index=4, recipe={"organicfibre", "organicfibre", "crystal"}}
  addItem {id="crystal", name="Crystal", index=5}
  addItem {id="wiring", name="Wiring", index=6, recipe={"metal"}}
  addItem {id="electronics", name="Electronics", index=7, recipe={"wiring", "syntheticfibre"}}
  addItem {id="solenoid", name="Solenoid", index=8, recipe={"wiring", "wiring", "wiring", "metal"}}
  addItem {id="capacator", name="Capacator", index=9, recipe={"wiring", "plate"}}
  addItem {id="coil", name="Wire Coil", index=10, recipe={"wiring", "wiring"}}
  addItem {id="can", name="Liquid Can", index=11, recipe={"metal", "organicfibre"}}
  addItem {id="plate", name="Metal Plate", index=12, recipe={"metal", "metal"}}
  addItem {id="motor", name="Motor", index=14, recipe={"solenoid", "capacator", "coil"}}
  addItem {id="basicframe", name="Basic Frame", index=15, recipe={"organicfibre" , "organicfibre", "organicfibre"}}
  addItem {id="stdframe", name="Standard Frame", index=16, recipe={"basicframe","metal", "syntheticfibre", "electronics"}}
  addItem {id="advframe", name="Advanced Frame", index=17, recipe={"stdframe","plate", "syntheticfibre", "syntheticfibre", "sensorarray", "circuitboard"}}
  addItem {id="ucell", name="Radioactive Cell", index=18}
  addItem {id="sensor", name="Sensor", index=19, recipe={"electronics", "crystal", "crystal", "capacator"}}
  addItem {id="sensorarray", name="Sensor Array", index=20, recipe={"circuitboard", "sensor", "sensor", "sensor", "syntheticfibre"}}
  addItem {id="circuitboard", name="Circuit Board", index=21, recipe={"electronics", "electronics", "wiring", "syntheticfibre"}}
  addItem {id="metalore", name="Metal Ore", index=22, mechGrinder="metalchunks"}
  addItem {id="metalchunks", name="Ore Chunks", index=23, mechChemWasher="cleanchunks"}
  addItem {id="cleanchunks", name="Clean Ore Chunks", index=24, mechFurnace="metal"}
  addItem {id="crystalcapacator", name="Crystal Capacator", index=25, recipe={"circuitboard","wiring","syntheticfibre","syntheticfibre","crystal","crystal","crystal","crystal", "crystal"}}
  addItem {id="cookedfood", name="Roast Potato", index=26}
  q = function(x,y) return love.graphics.newQuad(x*16,32+(y or 0)*16,16,16,256,256) end
  addItem {id="mechStorageCell", name="Storage Cell", index=32, recipe={"basicframe"}, quad=q(0), onUI=function(mech)
    for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
    end
  end, onKeyPressed=function(mech, key)
    if tonumber(key) ~= nil then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      mech.inventory[n] = p
      player.inventory[n] = m
    end
  end}
  addItem {id="mechFabricator", name="Fabricator", index=33, recipe={"basicframe", "metal"}, quad=q(1), onUI=function(mech)
    for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
    end
    table.insert(reactor.uilines, "Press ENTER to start fabrication")
    table.insert(reactor.uilines, "Recipe must match schema exactly.")
  end, onKeyPressed= function(mech, key)
    if tonumber(key) ~= nil then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      mech.inventory[n] = p
      player.inventory[n] = m
    elseif key == "return" then
      local matchesSchema = true
      local s = reactor.itemTypes[player.schemas[player.currentSchemaID]]
      for i=1,#s.recipe do
        if mech.inventory[i] ~= s.recipe[i] then
          matchesSchema = false
          break
        end
      end
      if matchesSchema then
        for i=1,#s.recipe do
          mech.inventory[i] = "nothing"
        end
        mech.inventory[1] = s.id
      end
    end
  end}
  addItem {id="mechFurnace", name="Furnace", index=34, recipe={"capacator", "coil", "stdframe"},  quad=q(2), onCreate=function(mech)mech.isCooking=false end,
  onUI=function(mech)
    if not mech.isCooking then
      for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
      end
      table.insert(reactor.uilines, "Press ENTER to cook item in Slot 1")
    else
      table.insert(reactor.uilines, "Currently cooking...")
    end
  end, onKeyPressed=function(mech, key)
    if tonumber(key) ~= nil and mech.isCooking == false then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      --if p == "nothing" then
        mech.inventory[n] = p
        player.inventory[n] = m
      --end
    end
    if key == "return" and mech.isCooking == false then
      mech.isCooking = true
      cron.after(10, function(mm)
      if reactor.itemTypes[mech.inventory[1]].mechFurnace then
        mech.inventory[1] = reactor.itemTypes[mech.inventory[1]].mechFurnace
      end
      mech.isCooking = false
      end, mech)
    end
  end}
  reactor.minerGrid = {}
  for y=0,(32*2048/128) do
    for x=0,(1024/128) do
      if y >= 17*16 and y <= 25*16 then
        local t = {"metalore", "metalore", "metalore", "crystal"}
        reactor.minerGrid[x+16*y] = t[math.random(1,4)]
      elseif y >=25*16 and y <=31*16 then
        local t = {"ucell", "ucell", "ucell", "metalore", "crystal"}
        reactor.minerGrid[x+16*y] = t[math.random(1,5)]
      else
        reactor.minerGrid[x+16*y] = "organicfibre"
      end
    end
  end
  addItem {id="mechMiner", name="Miner", index=35, quad=q(3), recipe={"metal", "metal", "metal","sensor","stdframe"},onCreate=function(mech) mech.isMining=0 end, onUI=function(mech)
    local mgx, mgy = round(mech.sprite.position.x/128), round(mech.sprite.position.y/128)
    table.insert(reactor.uilines, "MinerX: "..mgx.." MinerY: "..mgy)
    if reactor.minerGrid[mgx+16*mgy] == "nothing" then
      table.insert(reactor.uilines, "This area has aready been mined.")
      for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
      end
    elseif mech.isMining == 1 then
      table.insert(reactor.uilines, "Currently mining...")
    elseif mech.isMining == 0 then
      table.insert(reactor.uilines, "Press ENTER to start mining procedure")
    end
  end, onKeyPressed=function(mech, key)
    local mgx, mgy = round(mech.sprite.position.x/128), round(mech.sprite.position.y/128)
    if tonumber(key) ~= nil and mech.isMining == 2 then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      if p == "nothing" then
        mech.inventory[n] = p
        player.inventory[n] = m
      end
    end
    if key == "return" and mech.isMining == 0 then
      cron.after(120, function(mm) mm.inventory[1] = reactor.minerGrid[mgx+16*mgy]; mm.isMining=2;reactor.minerGrid[mgx+16*mgy]="nothing"; end, mech)
      mech.isMining = 1
    end 
  end}
  addItem {id="mechPump", name="Pump", index=36, quad=q(4), recipe={"motor","can","basicframe"}}
  addItem {id="mechTurbine", name="Turbine Generator", index=37, quad=q(5), recipe={"solenoid","plate","coil","basicframe"}}
  addItem {id="mechBoiler", name="Boiler", index=38, quad=q(6), recipe={"can", "can", "metal", "basicframe"}}
  addItem {id="mechCapacator", name="Upgrade Station", index=39, quad=q(7), recipe={"capacator","capacator", "electronics", "wiring", "stdframe"},
  onUI=function(mech)
    table.insert(reactor.uilines, "Upgrade Schematics: Use schemas 1-4 to select")
    table.insert(reactor.uilines, "2 Metal Plates = +1 Defense")
    table.insert(reactor.uilines, "4 Roast Potatoes antd 1 Synthetic Fibre = +25 MaxHP")
    table.insert(reactor.uilines, "1 Crystal and 2 Capacator = +2 Damage")
    table.insert(reactor.uilines, "3 Synthetic Fibre and 1 Solenoid = +200 Speed")
    for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
    end
    ugds = {
    {id="def", name="Defense Upgrade",recipe={"plate","plate"}},
    {id="hp", name="Health Upgrade", recipe={"cookedfood","cookedfood","cookedfood","cookedfood","syntheticfibre"}},
    {id="dmg", name="Damage Upgrade", recipe={"crystal", "capacator", "capacator"}},
    {id="spd", name="Speed Upgrade", recipe={"syntheticfibre","syntheticfibre","syntheticfibre","solenoid"}}
    }
    if player.currentSchemaID >=1 and player.currentSchemaID <=4 then
      table.insert(reactor.uilines, "Currently selected: "..ugds[player.currentSchemaID].name)
    end

    table.insert(reactor.uilines, "Press ENTER to upgrade")
  end, onKeyPressed=function(mech, key)
    if tonumber(key) ~= nil and mech.isMining == 2 then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
        mech.inventory[n] = p
        player.inventory[n] = m
    
    end
    ugds = {
    {id="def", upgrade=function() player.defense = player.defense +1 end, recipe={"plate","plate"}},
    {id="hp", upgrade=function() player.maxHealth = player.maxHealth + 25 end, recipe={"cookedfood","cookedfood","cookedfood","cookedfood","syntheticfibre"}},
    {id="dmg", upgrade=function() player.projectileDamage = player.projectileDamae + 2 end, recipe={"crystal", "capacator", "capacator"}},
    {id="spd", upgrade=function() player.moveSpeed = player.moveSpeed + 200 end, recipe={"syntheticfibre","syntheticfibre","syntheticfibre","solenoid"}}

  }
    if key == "return" then
      if player.currentSchemaID >=1 and player.currentSchemaID <=4 then
        local matchesSchema = true
        local s = ugds[player.currentSchemaID]
        for i=1,#s.recipe do
          if mech.inventory[i] ~= s.recipe[i] then
            matchesSchema = false
            break
          end
        end
        if matchesSchema then
          for i=1,#s.recipe do
            mech.inventory[i] = "nothing"
          end
          s.upgrade()
        end
      end
    end 
  end
  }
  addItem {id="mechGrinder", name="Grinder", index=40, quad=q(8), recipe={"can", "motor", "metal", "crystal", "stdframe"}, onCreate=function(mech)
  mech.isGrinding = false
  end,
  onUI=function(mech)
    if not mech.isGrinding then
      for i=1,10 do
          table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
      end
      table.insert(reactor.uilines, "Press ENTER to start grinding.")
    else
      table.insert(reactor.uilines, "Currently grinding...")
    end
  end, onKeyPressed=function(mech,key)
    if tonumber(key) ~= nil and mech.isGrinding == false then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      mech.inventory[n] = p
      player.inventory[n] = m
    end
    if mech.isGrinding == false and key == "return" then
      mech.isGrinding = true
      cron.after(30, function(mm)
        for i,item in mm.inventory do
          if reactor.itemTypes[item].mechGrinder then
            mm.inventory[i] = reactor.itemTypes[item].mechGrinder
          end
        end
        mm.isGrinding=false
      end, mech)
    end
  end}
  addItem {id="mechChemWasher", name="Chemical Washer", index=41, quad=q(9), recipe={"can", "motor", "coil", "syntheticfibre", "basicframe"},onCreate=function(mech)
  mech.isWashing = false
  end,
  onUI=function(mech)
  if not mech.isWashing then
    for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
    end
    table.insert(reactor.uilines, "Press ENTER to start washing")
  else 
    table.insert(reactor.uilines, "Currently washing...")
  end
  end, onKeyPressed=function(mech,key)
    if tonumber(key) ~= nil and mech.isWashing == false then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      mech.inventory[n] = p
      player.inventory[n] = m
    end
    if mech.isWashing == false and key == "return" then
      mech.isWashing = true
      cron.after(30, function(mm)
        for i,item in mm.inventory do
          if reactor.itemTypes[item].mechChemWasher then
            mm.inventory[i] = reactor.itemTypes[item].mechChemWasher
          end
        end
        mm.isWashing=false
      end, mech)
    end
  end}
  addItem {id="mechSolarpanel", name="Solar Panel", index=42, quad=q(10), recipe={"circuitboard", "sensor", "crystal","stdframe"}}
  addItem {id="mechReactor", name="Nuclear Reactor", index=43, quad=q(11), recipe={"ucell","capacator", "syntheticfibre", "syntheticfibre","circuitboard","sensorarray","can","mechPump ","advframe","advframe"},
  onCreate=function(mech) mech.isCharged = false end, 
  onUI=function(mech)
    for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[player.inventory[i]].name.. "    "..reactor.itemTypes[mech.inventory[i]].name)
    end
    
    local cc = true
    for i,item in ipairs(mech.inventory) do
      cc = cc and (item=="ucell")
    end
    mech.isCharged = cc
    if mech.isCharged then table.insert(reactor.uilines, "The reactor is fully charged!")
    else table.insert(reactor.uilines, "The reactor requires more uranium cells before it will fully charge.")
    end
  end, 
  onKeyPressed=function(mech, key)
    if tonumber(key) ~= nil then
      local n = tonumber(key) 
      if n == 0 then n = 10 end
      local m = mech.inventory[n]
      local p = player.inventory[n]
      mech.inventory[n] = p
      player.inventory[n] = m
    end
  end
  }
  addItem {id="mechTeleporter", name="Teleporter", index=44,quad=q(12), recipe={"crystalcapacator", "crystalcapacator", "crystalcapacator", "sensorarray", "sensorarray", "circuitboard", "circuitboard","wiring","solenoid", "advframe"},
  onUI=function(mech)
    local x,y = mech.tx, mech.ty
    local ss = "mechSignalStabilizer"
    local tb = "mechTransmissionBooster"
    local gn = "mechGalacticNav"
    local nr = "mechReactor"
    local function m(dx,dy) if reactor.machineGrid[(x+dx)+64*(y+dy)] then return reactor.machineGrid[(x+dx)+64*(y+dy)].t.id end end
    local function mmm(dx,dy)if reactor.machineGrid[(x+dx)+64*(y+dy)] then return reactor.machineGrid[(x+dx)+64*(y+dy)] end end
    isSetup = (
      m(-2,-2) == tb and --quadrant II
      m(-1,-2) == tb and
      m(-2,-1) == tb and 
      m(-1,-1) == tb and
      m(1,1) == tb and --quadrant 4
      m(2,1) == tb and
      m(1,2) == tb and 
      m(2,2) == tb and 
      m(-1,1) == ss and --quadrant 3
      m(-1,2) == ss and
      m(-2,1) == ss and
      m(-2,2) == ss and
      m(1,-1) == ss and --quadrant 1
      m(1,-2) == ss and
      m(2,-1) == ss and
      m(2,-2) == ss and
      m(-2, 0) == gn and --navigators
      m(2,0) == gn and
      m(0,-2) == gn and
      m(0, 2) == gn and
      m(-1, 0) == nr and mmm(-1,0).isCharged and
      m(1, 0) == nr and mmm(1,0).isCharged and
      m(0, -1) == nr and mmm(0,-1).isCharged and
      m(0,1) == nr and mmm(0,1).isCharged 
      )--]]
    if not isSetup then
      table.insert(reactor.uilines, "Device: INACTIVE")
      table.insert(reactor.uilines, "Error: Incorrect Configuration")
      table.insert(reactor.uilines, "Please refer to accompianing diagrams for the correct configuration.")
      table.insert(reactor.uilines, "Share and Enjoy!")
    else
      table.insert(reactor.uilines, "Device: ACTIVE")
      table.insert(reactor.uilines, "Press ENTER to teleport to sector:")
      table.insert(reactor.uilines, "ZZ9:plural:Z-Alpha")
    end
  end,
  onKeyPressed = function(mech, key)
    if isSetup and key == "return" then
      reactor.endingSequence = true
      reactor.endingParticles:start()
      cron.after(10, function() reactor:gotoState("CreditsState") end)
    end
  end
  }
  addItem {id="mechGalacticNav", name="Galactic Navigator", index=45,quad=q(13), recipe={"crystalcapacator","circuitboard","circuitboard","circuitboard","circuitboard","wiring","wiring","capacator","advframe", "sensorarray"},

   }
  addItem {id="mechSignalStabilizer", name="Signal Stabilizer", index=46, quad=q(14), recipe={"circuitboard","sensorarray","crystalcapacator","advframe"},

  }
  addItem {id="mechTransmissionBooster", name="Transmission Booster", index=47, quad=q(14), recipe={"coil", "coil", "coil", "coil","circuitboard","sensorarray","advframe"},

  }
  addItem {id="mechTransporter", name="Transporter", index=48, quad=q(0,1), recipe={"motor", "basicframe"}}
  addItem {id="mechAqueduct", name="Aqueduct", index=49, quad=q(1,1), recipe={"can", "basicframe"}}
  addItem {id="mechTransformer", name="Transformer", index=50, quad=q(2,1), recipe={"wiring","basicframe"}}

  reactor.machineGrid = {}

  reactor.capsules = {}
  local function addCapsule(zone, n, contains)
    local function getZoneXY(zone) 
      local cx =  rand(4, 1020)
      local cy = rand(2048, 3000)
      if zone == 1 then cy = rand(2048, 2048*17)
      elseif zone == 2 then cy = rand(2048*17, 2048*20)
      elseif zone==3 then cy = rand(2048*20, 2048*23)
      elseif zone == 4 then cy = rand(2048*23, 2048*25)
      elseif zone == 5 then cy = rand(2048*25, 2048*31) end
      return cx,cy 
    end
    cx,cy = getZoneXY(zone) --Why 2? In case one is inaccessible.
    table.insert(reactor.capsules, newCapsule(cx,cy,reactor.itemTypes[n].id,contains))
    cx,cy = getZoneXY(zone)
    table.insert(reactor.capsules, newCapsule(cx,cy,reactor.itemTypes[n].id,contains))
  end
  addCapsule(-1, 32, "item")
  addCapsule(-1, 33, "item")
  for i=1,24 do
    if reactor.itemTypes[i] and reactor.itemTypes[i].recipe then
      addCapsule(1, i, "schema")
    end
  end
  for i=1,8 do
    addCapsule(1, "metal", "item")
    addCapsule(1, "crystal", "item")
  end
  for i=1,8 do
    addCapsule(2, "metal", "item")
    addCapsule(2, "crystal", "item")
  end
  for i=1,16 do
    addCapsule(1, "organicfibre", "item")
    addCapsule(1, "food", "item")
  end

  for i,n in pairs{5,4,2,1,16,17,18} do
    addCapsule(1, n+32, "schema")
  end
  for i,n in pairs{15,6,3,7} do
    addCapsule(2, n+32, "schema")
  end
  for i,n in pairs{9,8} do
    addCapsule(3,n+32,"schema")
  end
  for i,n in pairs{14,10} do
    addCapsule(4, n+32, "schema")
  end
  for i,n in pairs{13,12,11} do
    addCapsule(5,n+32,"schema")
  end

  reactor.enemies = {}
  for i=1,128 do
    table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(3000, 2048*9), 4,0,8,450,1,1,1))
  end
  for i=1,384 do
    table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(2048*9, 2048*25), 8,1,24,1500,1,1,2))
  end
  for i=1,128 do
    table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(2048*25, 2048*31), 12,2,32,2800,1,1,3))
  end
  for i=1,48 do
    table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(2048*29, 2048*31), 16,4,40,3200,1,1,4))
  end

  reactor.rocks = {}
  for i=1,256 do
    local nrock = math.random(6,12)
    local rX, rY = rand(0,1024), rand(2048, 2048*31)
    for i=1,nrock do
      table.insert(reactor.rocks, newRock(rX+rand(-96,96), rY+rand(-96,96), rand(.2, 2), rand(0, math.pi*2)))

    end
  end

  reactor.endingParticles = love.graphics.newParticleSystem(love.graphics.newImage("endingparticle.png"), 1024)
  e = reactor.endingParticles
  e:setEmissionRate(256)
  e:setSpeed(300)
  e:setParticleLife(3)
  e:setSizes(1.25,1.0,.5,.1,0)
  e:setSpin(.2,math.pi,1)
  e:setOffset(8,8)
  e:setSpread(math.pi*2)
  e:setTangentialAcceleration(100,100)
  e:stop()
  eaw = 0
  reactor.dtsum = 0

  local PlayState = affable.Reactor:addState("PlayState")
  function PlayState:update(dt)
    reactor.dtsum = reactor.dtsum + dt
    cron.update(dt)
    if not reactor.endingSequence then
      self.world:update(dt)
    end
    local mx, my = self.gamera:toWorld(love.mouse.getX(), love.mouse.getY())
    local px,py =self.player.body:getX(), self.player.body:getY()
    self.gamera:setPosition(px, py)
    self.player.sprite.position:setXYZ(px,py)
    if not reactor.endingSequence then
      local pa = self.player.sprite.position:getAngleBetweenXY(mx,my)
      self.player.sprite.rotation = pa  + math.pi/2
      self.player.body:setAngle(pa)
    end
    local v = affable.newVector()
    if player.isAlive then
      if love.keyboard.isDown(self.keyconfig.up) then
        v.y = v.y - self.player.moveSpeed
      end
      if love.keyboard.isDown(self.keyconfig.down) then
        v.y = v.y + self.player.moveSpeed
      end
      if love.keyboard.isDown(self.keyconfig.left) then
        v.x = v.x - self.player.moveSpeed
      end
      if love.keyboard.isDown(self.keyconfig.right) then
        v.x = v.x + self.player.moveSpeed
      end
      if not (v.x * v.y == 0) then
        v:scale(1/1.41421356)
      end
      --if love.keyboard.isDown(" ") then v:scale(200) end 
      local _pmx,_pmy,pmass, _pinertia = self.player.fixture:getMassData()
      self.player.body:applyForce(v.x*pmass,v.y*pmass)
    end
    if self.player.health <= 0 then
      self.player.health = 0
      if player.isAlive then
        for n=1,10 do
          if player.inventory[n] ~= "nothing" then
            local c = newCapsule(player.body:getX(), player.body:getY(),player.inventory[n],"item")
            c.active = false
            cron.after(4, function(v) v.active=true end, c)
            table.insert(reactor.capsules, c)
            c.body:applyLinearImpulse(rand(-500, 500), rand(-500,500))
            player.inventory[n] = "nothing"
          end
        end
         cron.after(5, function()
        player.isAlive = true
      player.body:setX(512)
      player.body:setY(2048 +64)
      player.health = player.maxHealth
      end)
      end
      player.isAlive = false
     
      
    end
    self.currentMachine = self.machineGrid[getPlayerMachineIndex()]


    for i,enemy in pairs(reactor.enemies) do
      if enemy.health <= 0 then 
        enemy.fixture:destroy()
        reactor.enemies[i] = nil
      end 
      local ex, ey = enemy.body:getX(), enemy.body:getY()
      local distPlayer = math.sqrt((ex-px)*(ex-px) + (ey-py)*(ey-py))
      if distPlayer < 192 *enemy.enemyLevel then
        local angle = math.atan2(py-ey,px-ex)
        enemy.body:applyForce(enemy.speed * math.cos(angle), enemy.speed*math.sin(angle))
        enemy.body:setAngle(angle + math.pi/2)
      end
      enemy.sprite.position:setXYZ(enemy.body:getX(), enemy.body:getY())
      enemy.sprite.rotation = enemy.body:getAngle()-- + math.pi/2
    end

    for i,projectile in pairs(reactor.projectiles) do
      projectile.index = i
      projectile.sprite.position:setXYZ(projectile.body:getX(), projectile.body:getY())
      projectile.sprite.rotation = projectile.body:getAngle()
      if projectile.spent then
        projectile.fixture:destroy()
        reactor.projectiles[i] = nil
      end
    end

    for i,capsule in pairs(reactor.capsules) do
      capsule.sprite.position:setXYZ(capsule.body:getX(), capsule.body:getY())
      capsule.sprite.rotation = capsule.body:getAngle()
      if capsule.spent then
        capsule.fixture:destroy()
        reactor.capsules[i] = nil
      end
    end
    reactor.uilines = {}
    reactor.uilines[1] = "HP: "..reactor.player.health.."/"..reactor.player.maxHealth
    reactor.uilines[2] = "X: "..math.floor(reactor.player.body:getX()/32)
    reactor.uilines[3] = "Y: "..math.floor(reactor.player.body:getY()/32)

    if reactor.currentMachine ~= nil then 
      table.insert(reactor.uilines, reactor.currentMachine.t.name)
      reactor.currentMachine.t.onUI(reactor.currentMachine)
    else 
      table.insert(reactor.uilines, "No Machine") 
      for i=1,10 do
        table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[reactor.player.inventory[i]].name)
      end
    end

    if player.schemas[player.currentSchemaID] then
      local s = reactor.itemTypes[player.schemas[player.currentSchemaID]]
      table.insert(reactor.uilines, "Schema "..player.currentSchemaID..": "..s.name)
      for i,part in ipairs(s.recipe) do
        table.insert(reactor.uilines, i..": "..reactor.itemTypes[part].name)
      end
    else
      table.insert(reactor.uilines, "No schema with ID of "..player.currentSchemaID)
    end

    for i,mech in pairs(reactor.machineGrid) do
      if mech.t.update then
        mech.t.update(mech, dt)
      end
    end

    if reactor.endingSequence then
      reactor.endingParticles:setPosition(px,py)
      reactor.endingParticles:setTangentialAcceleration(10+eaw, -50*eaw)
      reactor.endingParticles:update(dt)
      eaw = eaw + dt*10
      player.sprite.rotation = player.sprite.rotation + eaw * dt
    end

  end

  function getMachineIndex(x,y)
    return x+64*y
  end

  function getPlayerMachineIndex()
    local px, py = reactor.player.body:getX()/16, reactor.player.body:getY()/16
    px, py = round(px), round(py)
    return px+64*py
  end

  function PlayState:onKeyPressed(key, unicode)
    print(key)
    if love.keyboard.isDown("lshift") then
      if tonumber(key) ~= nil then
        local n = tonumber(key)
        if n == 0 then n = 10 end
        if player.inventory[n] ~= "nothing" then
          local c = newCapsule(player.body:getX(), player.body:getY(),player.inventory[n],"item")
          c.active = false
          cron.after(4, function(v) v.active=true end, c)
          table.insert(reactor.capsules, c)
          c.body:applyLinearImpulse(rand(-500, 500), rand(-500,500))
          player.inventory[n] = "nothing"
        end
      end
      return nil
    end 
    if key == "left" then
      player.currentSchemaID = reactor.player.currentSchemaID - 1
    elseif key == "right" then
      player.currentSchemaID = reactor.player.currentSchemaID + 1
    end

    if key == "up" then
      local ni = {}
      for i,item in ipairs(player.inventory) do
        local b = i - 1
        if b == 0 then b = 10 end
        ni[b] = item
      end
      player.inventory = ni
    elseif key == "down" then
      local ni = {}
      for i,item in ipairs(player.inventory) do
        local b = i+1
        if b == 11 then b = 1 end
        ni[b] = item
      end
      player.inventory = ni
    end

    if self.currentMachine == nil then
      if tonumber(key) ~= nil then 
        local n = tonumber(key)
        if n == 0 then n = 10 end
        local item = self.player.inventory[n]
        if string.sub(item,1,4) == "mech" then
          if reactor.machineGrid[getPlayerMachineIndex()] ~= nil then return nil end
          newMachine(reactor.player.body:getX(),reactor.player.body:getY(), reactor.itemTypes[item])
          self.player.inventory[n] = "nothing"
        elseif item == "food" then
          player.health = player.health + math.random(10,25)
          if player.health >= player.maxHealth then player.health = player.maxHealth end
          self.player.inventory[n] = "nothing"
        elseif item == "cookedfood" then
          player.health = player.health + math.random(20,45)
          if player.health >= player.maxHealth then player.health = player.maxHealth end
          self.player.inventory[n] = "nothing"
        end
      end
    else
      if key == "q" then
        m = self.currentMachine
        for i,slot in ipairs(player.inventory) do
          if slot == "nothing" then 
            self.currentMachine = nil
            self.machineGrid[m.gridIndex] = nil
            player.inventory[i] = m.t.id
            break
        end
        end
      else
        if self.currentMachine.t.onKeyPressed and not reactor.endingSequence then
          self.currentMachine.t.onKeyPressed(self.currentMachine, key)
        end
      end
    end
  end

  function PlayState:draw()
    self.gamera:draw(function(l,t,w,h)
      love.graphics.setColor(255,255,255)
      local visible = affable.newRectangle(w,h,l,t)
      for i,rect in ipairs(affable.getIntersectingRectangles(visible,reactor.terrainRectangles)) do
        love.graphics.draw(reactor.terrainImages[reactor.terrainSequence[rect.index]], rect.position.x, rect.position.y)
      end

      love.graphics.setColor(222,222,222)
      love.graphics.rectangle("fill", 164, 2048-384, 680, 384-16)

      love.graphics.setColor(32,32,32)
      love.graphics.print([[
        You have crash-landed on a distant planet.
        In order to return home, you must build a teleporter and configure it correctly.
        The parts you need for the teleporter must be mined up in the purple temple to the far south.
        Many redneck hooloovoos will attempt to kill you on your way, but potatoes will heal you.

        Gather Capsules. They have items, machines, or schematics in them.
        Nearby is a fabricator. Find it. Press the corresponding number on your keyboard to place it.
        Walk over it. Put your organic fibres in it by pressing the corresponding number. Press enter to
        fabricate your first potato. You can use the arrow keys (up and down) to rotate your inventory,
        and left and right to scroll through the schematics you have found. 
        After you have placed a machine on the ground, you may press Q to pick it up, but all items in it 
        will be lost.  
        In order to get more resources, you must use miner to extract them from the earth. Though much 
        can be used immediately, metal ore must be ground, washed, and cooked to refine it into metal.
        Many machines do not have a use. Do not worry about them.
        You may improve yourself at an Upgrade Station. Mine in the desert to get metal and crystal.

        WASD to move, mouse to look, click to shoot. 

        Share and enjoy.

        ]], 156, 2048-332)
      love.graphics.setColor(255,255,255)


      reactor.entityBatch:clear()
      for i,mech in pairs(reactor.machineGrid) do
        mech.sprite:onDrawBatch()
      end
      for i,enemy in pairs(reactor.enemies) do
        enemy.sprite:onDrawBatch()
      end
      for i,projectile in pairs(reactor.projectiles) do
        projectile.sprite:onDrawBatch()
      end
      for i,rock in pairs(reactor.rocks) do
        rock.sprite:onDrawBatch()
      end
      for i,capsule in pairs(reactor.capsules) do
        capsule.sprite:onDrawBatch()
      end
      love.graphics.draw(reactor.entityBatch)
      if reactor.endingSequence then
        love.graphics.draw(reactor.endingParticles)
      end
      reactor.player.sprite:onDraw()
      
    end)
    if not reactor.endingSequence then
      love.graphics.setColor(0,0,0)
      local uistr = table.concat(reactor.uilines, "\n")
      love.graphics.print(uistr, 8,8)
    end

    

  end

  function PlayState.physicsBeginContact(f1,f2,c)
    local function hit(bullet, entity)
      if not (entity.isPlayer or entity.isMachine) then bullet.spent = true end
      if not entity.isEnemy then return nil end
      dDamage = bullet.damage - entity.defense
      if dDamage <= 0 then dDamage = 0 end
      entity.health = entity.health - dDamage
    end
    local function playerHit(player, enemy)
      dDamage = enemy.attack - player.defense
      if dDamage <= 0 then dDamage = 0 end
      player.health = player.health - dDamage
    end
    local function playerPickUp(player, capsule)
      if not capsule.active then return end
      if capsule.containsType == "item" then
        for i,slot in ipairs(player.inventory) do
          if slot == "nothing" then
            player.inventory[i] = capsule.name
            capsule.spent = true
            return
          end
        end
      elseif capsule.containsType == "schema" then
        for i,slot in ipairs(player.schemas) do 
          if capsule.name == slot then
            capsule.spent = true
            return nil 
          end
        end
        table.insert(player.schemas, capsule.name)
        capsule.spent = true
      end
    end
    
    if not f1.getUserData or not f2.getUserData then print("no user data!"); return end
    if f1:getUserData() and f2:getUserData() then
      local f1u, f2u = f1:getUserData(), f2:getUserData()
      if f1u.isProjectile then 
        hit(f1u, f2u)
      elseif f2u.isProjectile then
        hit(f2u, f1u)
      end
      if (f1u.isPlayer and f2u.isEnemy) then
        playerHit(f1u, f2u)
      elseif (f2u.isPlayer and f1u.isEnemy) then
        playerHit(f2u, f1u)
      end
      if f1u.isPlayer and f2u.isCapsule then
        playerPickUp(f1u, f2u)
      elseif f2u.isPlayer and f1u.isCapsule then
        playerPickUp(f2u, f1u)
      end

    end
  end
  reactor:gotoState("PlayState")

  CreditsState = affable.Reactor:addState("CreditsState")
  credits = [[
  Congratulations! 
  You teleported home!
  You managed to beat the game!
  My badly-written, hitchhiker-alluding, made-in-48hr game!
  I hope the experience wasn't too mind-numbingly banal or stupidly frustrating.

  ==========================================
                CONTACT: LOST 
  ==========================================
  A game by William Bundy.
  Licenced under the GPL.
  Uses Love2D and a bunch of kikito's code. https://github.com/kikito

  Code can be found at https://github.com/williambundy

  A game made for Ludum Dare 26 -- themed: minimalism




  Share and Enjoy!







  ...press any key to quit. 
  ]]


  function CreditsState:onKeyPressed(key,unicode)
    love.event.push("quit")
  end

  function CreditsState:draw()
    love.graphics.print("You completed the game in "..reactor.dtsum.." seconds.",8,8)
    love.graphics.print(credits, 8, 100)
  end


end

function love.update(dt)
  reactor:_update(dt)
end

function love.draw()
  reactor:_draw()
end

function love.mousepressed(x,y, button)
  if reactor:getStateStackDebugInfo()[1] == "PlayState" and button == "l" then
    reactor.gunSound:play()
    local a = reactor.player.body:getAngle()
    local px, py = reactor.player.body:getX(), reactor.player.body:getY()
    local p = newProjectile(reactor.player.projectileSpeed*math.cos(a),
      reactor.player.projectileSpeed*math.sin(a), px + 10*math.cos(a), py+10*math.sin(a), reactor.player.projectileDamage)
    table.insert(reactor.projectiles, p)
    cron.after(.5, function(b) b.spent = true; end, p )
  end
end 

function love.keypressed(key, unicode)
  reactor:_onKeyPressed(key, unicode)
end