
require("Utility")
require("Counter")

-- Pseudo-class to track a player's info
-- Call: instance = Player.Create()
-- Then: instance:Fire() etc to call functions with automatic access to "instance.self" value
Player = {}
Player.__index = Player -- meta table to implement a "class" in lua (google it!)

Player.xPos = -appWidth/2 + 20

-- we use a table of nodes and re-use once anim is over to save creating and garbage collecting hundreds of these
-- TODO: turn this into generic code that can be re-used by any node or even generic table
-- Generic version should have a max size setting - balance memory used vs garbage collection
function ReusePlayerFX(target)
    --point to this slot if fxLastFreed doesnt point to a currently "free" slot
    if not target.player.effects[target.player.fxLastFreed].freed then
        target.player.fxLastFreed = target.freeIndex --flag as next one to try re-using
    end
    
    target.freed = true --allow re-use
    --print("PLAYER FX: freed fx at: " .. target.freeIndex)
end

function PlayerFx(event)
    local x = event.target.x
    local y = event.target.y
    local player = event.timer.player
    local fx = nil

    local iFx = player.fxLastFreed
    local prev = nil
    for n=1, player.fxSize, 1 do
        fx = player.effects[iFx]
        if fx.freed then
            if fx.size ~= player.halfHeight then
                -- slightly convoluted! still have to recreate effect node if player changes size.
                -- cleaner to replace in-place than to insert/remove from player.effects table...
                fx:removeFromParent()
                fx = director:createLines({x=x, y=y, strokeWidth=0, color=event.target.color, coords=event.target.coords, alpha=0.5, zOrder=-1})
                fx.player = player
                fx.freeIndex = iFx
                fx.size = player.halfHeight
                player.effects[iFx] = fx
                origin:addChild(fx)
                --print("RELEASING player fx")
            else
                fx.alpha = 0.5
                fx.xScale = 1
                fx.yScale = 1
                fx.x=x
                fx.y=y
                --print("PLAYER FX: reusing fx at slot: " .. iFx)
            end
            player.fxLastFreed = iFx+1 -- guess next one is next to be freed. Likley if timers expire in order added.
            if player.fxLastFreed > player.fxSize then player.fxLastFreed = 1 end
            fx.freed = false
            break
        end
        fx = nil
        iFx = iFx + 1
        if iFx > player.fxSize then iFx = 1 end
    end
    
    if not fx then
        fx = director:createLines({x=x, y=y, strokeWidth=0, color=event.target.color, coords=event.target.coords, alpha=0.5, zOrder=-1})
        fx.player = player
        fx.size = player.halfHeight
        table.insert(player.effects, fx)
        player.fxSize = table.getn(player.effects)
        fx.freeIndex = player.fxSize
        origin:addChild(fx)
        --print("PLAYER FX: new fx added to pos: " .. fx.freeIndex)
    end
    
    if player.cloakTimer then fx.alpha=0.06 end
    
    tween:to(fx, {alpha=0, time=0.8, xScale=2, yScale=2, onComplete=ReusePlayerFX})
end

function Player.Create(id, health, ammo, ammoDefault, onePlayerMode)
    local player = {}            -- the new object
    setmetatable(player,Player)  -- make Player handle lookup
    -- initialize the object

    player.id = id -- note that player is just a table and we're assigning key-value pairs to it
    player.reverseTimer = nil -- if non nil, player controls are reversed and a timer counts down
    player.cloakTimer = nil --0  -- as above for player being invisible
    player.touches = {} -- track touch events to do movement and weapons
    player.touchCount = 0 -- can't auto get size of key table in lua
    player.moveWithFinger = nil -- points to finger id currently controlling movement
    player.velocity = 0 -- allow decelerating movement after touch is released
    player.touchPosDiff = 0
    player.halfHeight = initSledHalfHeight --for detecting collisions
    player.newHalfHeight = initSledHalfHeight
    player.sledColour = nil -- allow retain current colour on sled re-creation

    -- Visual stuff
    -- Sleds are 8x42 with anchor at "front"
    -- y pos of sled used for movement
    -- Note that coords are relative to cenre of screen (background/parent has anchor at centre)
    player.mirrorX = nil -- allow reverse X coords for player2
    local xPos = nil

    if id == 1 then
        player.mirrorX = 1
        xPos = Player.xPos
    else
        player.mirrorX = -1
        xPos = -Player.xPos
    end

    player.sledColour = gameInfo.playerColours[id]
    player:AddSled(xPos, 0)

    local colourOverride = nil
    if onePlayerMode then colourOverride = 2 end
    player.health = Counter.Create(id, health, 99, true, colourOverride)
    player.weaponsMeter = WeaponsMeter.Create(id, player.mirrorX, ammo, ammoDefault, colourOverride)

    -- pre-calculate collision pos for balls to do super-cheap collision detection
    player.collideX = xPos + player.mirrorX*ballRadius

    player.cloakTimer = nil
    
    -- rotate digits if two player touch game
    -- dont rotate whole weapons meter as direction of weapon colour strip parallels finger movement
    if not onePlayerMode and deviceIsTouch then
        player.health.origin.x = player.mirrorX*8 --move out a bit and also cancel the "nudge" that is set for 1 player
        player.health.origin.y = 4 -- edge out a little since meter typically has "1" as tens digit
        player.health.origin:rotate(player.mirrorX*90)
        player.weaponsMeter.ammoCounter.origin.x = player.mirrorX*5
        player.weaponsMeter.ammoCounter.origin:rotate(player.mirrorX*90)
    end

    -- position HUD
    player.health.origin:translate(player.mirrorX*(minX+40), maxY-38)
    player.weaponsMeter.origin:translate(player.mirrorX*(minX+65), minY+25)
    
    return player
end

function Player:Destroy()
    self:CancelTimersAndAnims()
    self.health:Destroy()
    self.weaponsMeter:Destroy()
    self:RemoveSled()
    --no need to nil anything as we'll just nil the player after destrouction and then there are no references left to any of its member values
end

function Player:AddSled(xPos, yPos)
    --dbg.print("Ad sled at: " .. xPos .. "," .. yPos)
    self.sled = director:createLines({xAnchor=0, yAnchor=0, x=xPos, y=yPos, strokeWidth=0, color=self.sledColour,
        coords={0,self.halfHeight, -1*self.mirrorX,self.halfHeight, -initSledWidth*self.mirrorX,self.halfHeight-7, -initSledWidth*self.mirrorX,-(self.halfHeight-7), -1*self.mirrorX, -self.halfHeight, 0,-self.halfHeight, 0, self.halfHeight }})

    -- black mask to make sled look like vector (drawing with lines is buggy!)
    self.sledMask = director:createLines({xAnchor=0, yAnchor=0, x=0, y=0, strokeWidth=0, color=color.black,
        coords={-1*self.mirrorX, self.halfHeight-2 , (-initSledWidth+1)*self.mirrorX,self.halfHeight-8, (-initSledWidth+1)*self.mirrorX,-(self.halfHeight-8),  -1*self.mirrorX,-(self.halfHeight-2), -1*self.mirrorX, self.halfHeight-2 }})

    origin:addChild(self.sled)
    self.sled:addChild(self.sledMask)

    self.collideY = self.halfHeight + ballRadius --relative to sled

    self.sled:sync()
    
    if self.halfHeight == self.newHalfHeight then
        local fxTimer = self.sled:addTimer(PlayerFx, 0.3, 0, 0.5)
        if not self.effects then
            self.effects = {}
            self.fxLastFreed = 1
            self.fxSize = 0
        end
        fxTimer.player = self
    end
end

function Player:RemoveSled()
    cancelTimersOnNode(self.sled)
    self.sledMask:removeFromParent()
    self.sled:removeFromParent()
end

function Player:Fire(weaponOverride)
    --dbg.print("FIRE!")
    --print("Player:Fire")

    if self.weaponsMeter:HasAmmo() then
        weapon = weaponOverride or self.weaponsMeter.currentWeapon

        -- fire from in front of player (avoid having to ignore collisions on firing)
        local xPos = self.sled.x + self.mirrorX*(ballRadius+5)

        if weapon == "bullet" then
            --dbg.print("FIRE bullet")
            local speed = 750 --speeds are in pixels/sec (multiplied by update delta in main update func to get pixels/frame)
            local bullet = CollidableCreate("bullet", xPos, self.sled.y, {x=self.mirrorX*speed, y=0}, speed) -- some objects dont need speed as their velocity never changes
        elseif weapon == "ball" then
            --dbg.print("FIRE ball")
            local minAngle
            local maxAngle
            if self.mirrorX == 1 then
                minAngle = 45
                maxAngle = 135
            else
                minAngle = 225
                maxAngle = 315
            end
            
            if gameInfo.controlType == "onePlayer" then
                -- 1p balls count towards wave and speed up its completion, but are
                -- dangerous esp if fired when waveleft = 1!
                checkWaveIsOver()
            end
            
            AddBall{xPos=xPos, yPos=self.sled.y, minAngle=minAngle, maxAngle=maxAngle, allowedBallTypes = {"ball"}}
        elseif weapon == "expander" then
            --dbg.print("FIRE expander")
            local speed = 500
            local bullet = CollidableCreate("expander-up", xPos, self.sled.y, {x=self.mirrorX*speed, y=0}, speed)
            local bullet = CollidableCreate("expander-down", xPos, self.sled.y, {x=self.mirrorX*speed, y=0}, speed)
        elseif weapon == "air" then
            --dbg.print("FIRE air")
            local fxTimer = self.sled:addTimer(AirFX, 0.2, 3, 0)
            fxTimer.x = self.sled.x + self.mirrorX*8
            fxTimer.y = self.sled.y
            fxTimer.initAlpha = 1
        elseif weapon == "freezer" then
            --dbg.print("FIRE freezer")

            -- we can queue up multiple of timers (will all be cancelled on sled destruction)
            self.sled:addTimer(FreezePlayers, 1, 1, 0)
            sceneBattle.freezeStarted = true
            local fxTimer = self.sled:addTimer(FreezerFX, 0.2, 3, 0)
            fxTimer.x = self.sled.x + self.mirrorX*8
            fxTimer.y = self.sled.y
            fxTimer.initAlpha = 1
        elseif weapon == "heatseeker" then
            --dbg.print("FIRE heatseeker")
            local speed = 400
            if gameInfo.controlType == "onePlayer" then --weapon needs to change all ball directions fast
                speed = 750
            end
            local bullet = CollidableCreate("heatseeker", xPos, self.sled.y, {x=self.mirrorX*speed, y=0}, speed)
            bullet.enemy = self.enemy
        elseif weapon == "reverser" then
            --dbg.print("FIRE reverser")

            ReverserFx(1, self.enemy.sled)
            if self.enemy.reverseTimer then
                self.enemy.reverseTimer:cancel()
            else
                if self.enemy.touches and self.enemy.moveWithFinger then
                    self.enemy.reversePos = self.enemy.touches[self.enemy.moveWithFinger].y
                end
                self.enemy.velocity = 0-self.enemy.velocity
            end
            self.enemy.reverseTimer = system:addTimer(UnReverse, 4, 1, 0) --system timer to allow for sled destruction
            self.enemy.reverseTimer.player = self.enemy
            --self.enemy.touchPosDiff = 0 - self.enemy.touchPosDiff
        end

        self.weaponsMeter:Fire(weaponOverride) --deprecate ammo and switch weapon if current is empty
    end
end

ReverserFx = function(direction, sled)
    sceneBattle.reverseStarted = true
    local stepSize = 360/20
    for n=0, 360-stepSize, stepSize do
        local vec = VectorFromAngle(n, 20)
        local randomColour = colorIndex[math.random(1,numColors)]
        local spoke = director:createLines({x=0, y=0, coords={0,0, vec.x, vec.y}, xScale=0.1, yScale=0.1, strokeColor=color[randomColour], strokeWidth=1, strokeAlpha=0, alpha=0})
        sled:addChild(spoke)
        tween:to(spoke, {rotation=360*direction, time=2, onComplete=destroyNode})
        tween:to(spoke, {strokeAlpha=1, xScale=3, yScale=3, time=1, delay=n*0.002})
        tween:to(spoke, {strokeAlpha=0, xScale=0, yScale=0, time=0.5, delay=1+n*0.002})
    end
end

UnReverse = function(event)
    sceneBattle.reverseStarted = nil --only relevant in 1 player where both sleds always reverse together
    local player = event.timer.player
    ReverserFx(-1, player.sled)

    -- dif between finger and sled has changed, so recalculate if still touching
    if player.moveWithFinger then
        player.touches[player.moveWithFinger].touchPosDiff = player.touches[player.moveWithFinger].y - player.sled.y
    end
    
    player.reverseTimer = nil
    if gameInfo.controlType == "onePlayer" and player.id == 1 then
        ShowMessage("UN-REVERSE!", 0, true)
    end
end

function Player:AddAmmo(value)
    if not self.deadFlag and not self.enemy.deadFlag then
        self.weaponsMeter:AddAmmo(value)
    end
end

function Player:AddHealth(value)
    if not self.deadFlag then
        self.health:Increment(value)
    end
end

function Player:TakeHit()
    if self.deadFlag then
        return
    end
    
    device:vibrate(20)

    --dbg.print("HIT! player=" .. self.id)
    self.health:Increment(-1)

    -- force un-cloak but dont animate it
    self.sled.alpha = 1

    if self.cloakTimer ~= nil then
        self.cloakTimer:cancel()
        self.cloakTimer = nil
    end

    if not self:Shrink() then -- remove last expansion on hit
        self:AnimateHit()
    end
end

function Player:AnimateHit()
    --apply "flash" animation
    --tween:to(self.sled, {color=color.white, time=0.1})
    cancelTweensOnNode(self.sled)
    tween:to(self.sled, {xScale=1, alpha=0.2, time=0.1})
    tween:to(self.sled, {xScale=1, alpha=1.0, time=0.1, delay=0.1})
end

function Player:Grow()
    if self.newHalfHeight < maxSledHalfHeight then
        self.newHalfHeight = self.newHalfHeight + sledExpandSize
    end
end

function Player:Shrink()
    if self.newHalfHeight > initSledHalfHeight then
        self.newHalfHeight = self.newHalfHeight - sledExpandSize
    end
end

function Player:Cloak()
    if self.deadFlag then
        return
    end

    cancelTweensOnNode(self.sled)
    tween:to(self.sled, {alpha=0, time=0.2})

    if self.cloakTimer ~= nil then
        self.cloakTimer:cancel()
    end

    self.cloakTimer = system:addTimer(EndCloak, 3, 1)
    self.cloakTimer.player = self --allow timer to access player itself when timer fires
end

EndCloak = function(event)
    local timer = event.timer -- event.timer is the timer we created
    timer.player.cloakTimer = nil
    cancelTweensOnNode(timer.player.sled)
    tween:from(timer.player.sled, {xScale=0.2, time=0.2})
    tween:to(timer.player.sled, {alpha=1, time=0.2})
end

function Player:CancelTimersAndAnims(cancelSledChildren)
    if self.AITimer then
        self.AITimer:cancel()
        self.AITimer = nil
    end

    -- cloak
    if self.cloakTimer ~= nil then
        self.cloakTimer:cancel()
        self.cloakTimer = nil
    end

    -- reverse is a system timer. OK to leave reverse spoke anims to finish if already running.
    if self.reverseTimer ~= nil then
        self.reverseTimer:cancel()
        self.reverseTimer = nil
    end

    -- all tweened anims on the sled
    cancelTweensOnNode(self.sled)
    cancelTimersOnNode(self.sled)
    
    -- e.g. cancel reverser spokes. usually want to leave these to animate out
    if cancelSledChildren then
        for k,v in pairs(self.sled.children) do
            for k2,vChild in pairs(v.tweens) do
                tween:cancel(vChild)
            end
        end
    end
end

function Player:Explode()
    dbg.print("pre-explode clear-up done...")

    self:CancelTimersAndAnims()
    tween:to(self.sled, {alpha=1, xScale=1, yScale=1, time=0.2}) -- negate any half-completed anims

    -- create explosion waves --

    -- mini explosions on sled. Random but getting bigger, faster and covering more of shape area
    local delay = 1
    local waves = 3
    for n=1,10,1 do
        local randomExplosionTimer = self.sled:addTimer(ExplodeFX, 0.1, waves, delay)
        delay = delay + (10-n)*0.05 -- all timers start at once, with delays that increasingly converge so explosions get closer together
        randomExplosionTimer.origin = {}
        if self.mirrorX > 0 then
            randomExplosionTimer.origin.x = math.random(self.sled.x-initSledWidth, self.sled.x)
        else
            randomExplosionTimer.origin.x = math.random(self.sled.x, self.sled.x+initSledWidth)
        end
        randomExplosionTimer.origin.y = math.random(self.sled.y - self.halfHeight/10*n, self.sled.y + self.halfHeight/10*n) -- start in middle, expand out
        randomExplosionTimer.blastRadius = math.random(15+n*2,20+n*2)
        randomExplosionTimer.duration = 0.3
        randomExplosionTimer.useFill = true
        randomExplosionTimer.useStroke = false
        randomExplosionTimer.waves = waves
    end

    -- big explosion fills screen and pushes, then destroys, all the collidables left
    local pushTimer = self.sled:addTimer(PushFromSled, 0, 1, delay-0.8)
    pushTimer.origin = self.sled

    local bigExplosionTimer = self.sled:addTimer(ExplodeFX, 0.2, 9, delay-0.7)
    bigExplosionTimer.blastRadius = appWidth
    bigExplosionTimer.duration = 2
    bigExplosionTimer.origin = self.sled
    bigExplosionTimer.useFill = true
    bigExplosionTimer.useStroke = true
    bigExplosionTimer.waves = 9
    bigExplosionTimer.completeTarget = self
    bigExplosionTimer.completeFunc = PlayerExplosionFinished -- call on final explosion done

    self.ballDestroyTimer = self.sled:addTimer(ExplodeRadius, 0.1, 0, delay-0.2)
    self.ballDestroyTimer.player = self
    self.ballDestroyTimer.step = appWidth/(2.0/0.1) -- at each update, exapand by: total dist/(total duration/frame duration)

    -- timer destroys balls that waves "hit".
    -- onComplete event checks for all balls gone and any deadFlag players finishing exploding, then ends battle
end

function PlayerExplosionFinished(player)
    dbg.print("explosion over for player " .. player.id)
    player.deadFlag = player.deadFlag + 1
    --destroyNode(target)
end

ExplodeRadius = function(event)
    local timer = event.timer
    local ballDestroyRadius = event.doneIterations * timer.step

    if event.doneIterations == 1 then
        timer.player.sled.isVisible = false
    end

    local allDone = false
    if ballDestroyRadius > appWidth+100 then
        allDone = true
    end

    for k,obj in pairs(collidables) do
        xDif = obj.x - timer.player.sled.x
        yDif = obj.x - timer.player.sled.x

        -- if ball within radius then destroy
        -- allDone checks for any balls left for some reason, eg off-screen
        if allDone or xDif*xDif + yDif*yDif < ballDestroyRadius*ballDestroyRadius then
            if obj.objType == "heatseeker" then
                HeatseekerDestroy(obj)
            elseif obj.objType == "expander" then
                FadeDestroy(obj)
            else
                GrowDestroy(obj)
            end
        end
    end

    if allDone then
        dbg.print("no balls left after player " .. timer.player.id .. " died")
        timer:cancel()
        timer.player.ballDestroyTimer = nil
        timer.player.deadFlag = timer.player.deadFlag + 1
    end
end

PushFromSled = function(event)
    local timer = event.timer
    PushCollidablesAwayFromPos(timer.origin.x, timer.origin.y, 3)
    local pushExplosionTimer = timer.origin:addTimer(ExplodeFX, 0, 1, 0)
    pushExplosionTimer.origin = timer.origin
    pushExplosionTimer.blastRadius = appWidth
    pushExplosionTimer.duration = 0.5
    pushExplosionTimer.useFill = false
    pushExplosionTimer.useStroke = true
    pushExplosionTimer.waves = 1
end

ExplodeFX = function(event)
    local timer = event.timer
    local duration = timer.duration + event.doneIterations*0.1 -- each wave is a little slower

    if event.doneIterations == 1 or event.doneIterations == timer.waves then
        ringColour = color.red
    elseif event.doneIterations == 2 or event.doneIterations == timer.waves-1 then
        ringColour = color.orange
    elseif event.doneIterations == 3 or event.doneIterations == timer.waves-2 then
        ringColour = color.yellow
    else
        ringColour = color.white
    end

    local fx = director:createCircle({xAnchor=0.5,yAnchor=0.5,
        x=timer.origin.x,
        y=timer.origin.y,
        radius=2,
        strokeColor=ringColour,
        color=ringColour,
        strokeAlpha=0, alpha=0})

    if timer.useStroke then fx.strokeWidth=1 end

    origin:addChild(fx)

    if timer.useFill and (not timer.useStroke or timer.waves < 4 or event.doneIterations < timer.waves - 1) then -- no fill on last few waves of big explosions
        tween:to(fx, {alpha=0.7, time=timer.duration*0.2})
        if timer.useStroke then
            tween:to(fx, {alpha=0, delay=timer.duration*0.3, time=timer.duration*0.2})
        else
            tween:to(fx, {alpha=0, delay=timer.duration*0.4, time=timer.duration*0.4})
        end
    end
    if timer.useStroke then
        tween:to(fx, {strokeAlpha=1, time=timer.duration*0.1})
        tween:to(fx, {strokeAlpha=0, delay=timer.duration*0.5, time=timer.duration*0.5})
    end

    local onCompleteFunc
    if event.doneIterations == timer.waves and timer.completeTarget and timer.completeFunc then
        -- run optional final event on completion via tween. If fx is destroyed (eg battle cancelled)
        -- and tween never completes then event never runs
        fx.completeFunc = timer.completeFunc
        fx.completeTarget = timer.completeTarget
        onCompleteFunc = ExplodeFinalFunc
        device:vibrate(1500)
    else
        device:vibrate(20)
    end
    tween:to(fx, {radius=timer.blastRadius, time=timer.duration, onComplete=onCompleteFunc})
end

function ExplodeFinalFunc(target)
    dbg.print("calling ExplodeFinalFunc")
    target.completeFunc(target.completeTarget)
    destroyNode(target)
end
