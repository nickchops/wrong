
-- NB: We have more node tracking than needed. Could clean up scene basically
-- by just calling destroyNodesInTree(origin)! but we are tearing down in a very
-- controlled way. Useful for debugging still.
--------------------------------------------------------------------------------

require("Utility")
require("NodeUtility")
dofile("Player.lua")
dofile("WeaponsMeter.lua")

function PushCollidablesAwayFromPos(x, y, boostSpeed)
    boostSpeed = boostSpeed or 1

    for k,obj in pairs(collidables) do
        if not obj.ignore then
            local vecToX = obj.x - x
            local vecToY = obj.y - y
            local length = math.sqrt(vecToX*vecToX+vecToY*vecToY)
            vecToX = vecToX / length
            vecToY = vecToY / length
            obj.vec.x = vecToX * obj.speed * boostSpeed
            obj.vec.y = vecToY * obj.speed * boostSpeed
            
            if obj.xMirror then
                if obj.vec.x > 0 then
                    obj.xMirror = 1
                else
                    obj.xMirror = -1
                end
            end
        end
    end
end

function PushCollidableAwayFromPos(obj, x, y, boostSpeed)
    if obj.ignore then
        return
    end
    boostSpeed = boostSpeed or 1
    local vecToX = obj.x - x
    local vecToY = obj.y - y
    local length = math.sqrt(vecToX*vecToX+vecToY*vecToY)
    vecToX = vecToX / length
    vecToY = vecToY / length
    obj.vec.x = vecToX * obj.speed * boostSpeed
    obj.vec.y = vecToY * obj.speed * boostSpeed
end

-------- Timer callbacks for weapons and weapon effects --------

function AppearTimer(event)
    dbg.print("appear over")
    local timer = event.timer
    timer.target.ignore = nil
    timer.target.appearTimer = nil
end

function putObjInRecycler(obj, objType)
    sceneBattle.recyclerCount[objType] = sceneBattle.recyclerCount[objType] + 1
    table.insert(sceneBattle.recycler[objType], obj)
    -- TODO: may want to just assign and set to nil rather than use insert/remove for efficiency?
    --sceneBattle.recycler[objType][sceneBattle.recyclerCount[objType]] = obj
    destroyNode(obj) --not garbage collected, just parent-less, as still has ref in the recycler
end

function putFxInRecycler(obj)
    putObjInRecycler(obj, "fx")
end

function TrailFx(event)
    startAlpha = event.timer.startAlpha or 0.6
    if not event.target.flicker and event.target.radius >= ballRadius then -- wait till initial expand is over
        local fx
        if sceneBattle.recyclerCount.fx > 0 then
            fx = sceneBattle.recycler.fx[sceneBattle.recyclerCount.fx]
            table.remove(sceneBattle.recycler.fx)
            --sceneBattle.recycler.fx[sceneBattle.recyclerCount.fx] = nil
            sceneBattle.recyclerCount.fx = sceneBattle.recyclerCount.fx-1
        else
            fx = director:createCircle({xAnchor=0.5,yAnchor=0.5,
            strokeWidth=1, alpha=0, color=color.black})
        end
        fx.x = event.timer.target.x - event.timer.target.vec.x*system.deltaTime
        fx.y = event.timer.target.y - event.timer.target.vec.y*system.deltaTime
        fx.strokeAlpha=startAlpha
        fx.radius=ballRadius-1
        fx.strokeColor=event.target.strokeColor
        
        origin:addChild(fx)
        tween:to(fx, {radius=0, strokeAlpha=0, time=0.5, onComplete=putFxInRecycler})
    end
end

ExpanderAnim = function(expander)
    -- move up/down from more central position
    tween:from(expander, {y=expander.y-expander.yMirror*25, time=0.37+15/expander.speed, onComplete=ExpanderAnim})
end

ExpanderFx = function(event)
    -- create trailing objects that fade away and destroy themselves
    local expander = event.target
    local fx = director:createLines({x=expander.x, y=expander.y, coords={-ballRadius,0, 0,expander.yMirror*ballRadius, ballRadius,0}, strokeWidth=0, color=collidableColours.expander, alpha=0.5})

    origin:addChild(fx)
    tween:to(fx, {x=fx.x-expander.vec.x*system.deltaTime*2, y=fx.y+expander.yMirror*30, rotation=120*expander.yMirror*expander.xMirror, xScale=8, yScale=4, alpha=0, time=0.37+15/expander.speed, onComplete=destroyNode})
end

-- Functions to animate objects to destruction. Timers (for effects) are cencelled; tweens left to do the death anim
function ShrinkDestroy(collidable)
    CollidableDestroy(collidable, true) -- collidable is still alive (untill DyingCollidableDestroy called at tween-end)
    collidable.deathTween = tween:to(collidable, {xScale=0, yScale=0, strokeAlpha=0, time=0.2, onComplete=DyingCollidableDestroy})
end

function GrowDestroy(collidable)
    CollidableDestroy(collidable, true)
    collidable.deathTween = tween:to(collidable, {radius=collidable.radius*3, strokeAlpha=0, time=0.3, onComplete=DyingCollidableDestroy})
end

function FadeDestroy(collidable) --for non-circles!
    CollidableDestroy(collidable, true)
    collidable.deathTween = tween:to(collidable, {strokeAlpha=0, time=0.2, onComplete=DyingCollidableDestroy})
end

function HeatseekerDestroy(collidable)
    -- heatseeker is more complex. Still let collidable die but shape and sub-nodes
    -- have multi-stage animation
    CollidableDestroy(collidable, true)
    collidable:addTimer(HeatseekerImpactFX, 0.1, 7, 0)
    device:vibrate(100, 0.5)
end

--generic effect, used for new ball adds
function RingFX(event)
    local timer = event.timer
    local strokeWidth = timer.strokeWidth or 1
    local strokeAlpha = timer.strokeAlpha or 1
    local alpha = timer.alpha or 0
    local radiusStart = timer.rStart or 0
    local radiusEnd = timer.rEnd or self.screenMaxY
    local time = timer.endTime or 2
    local colour = timer.color or color.white

    local fx = director:createCircle({xAnchor=0.5,yAnchor=0.5,
        x=timer.x,
        y=timer.y,
        radius=radiusStart,
        strokeColor=colour,
        strokeWidth=strokeWidth,
        strokeAlpha=strokeAlpha,
        color=colour,
        alpha=alpha})

    origin:addChild(fx)
    tween:to(fx, {radius=radiusEnd, alpha=0, strokeAlpha=0, time=time, onComplete=destroyNode})
end

function SpriteFX(event)
    local durationMin = event.timer.durationMin
    local durationMax = event.timer.durationMax
    local freqMin = event.timer.freqMin
    local freqMax = event.timer.freqMax
    local timerId = event.timer.id
    local radius = sceneBattle.screenMaxX*1.35 -- well off screen in any direction
    local fxType = event.timer.fxType
    local fx
    
    if fxType == "shooting" then
        -- sprite comes on at centre and tweens to random pos off screen while growing
        local angle = math.random(0,359)
        local destX = radius*math.cos(angle)
        local destY = radius*math.sin(angle)
        local time = math.random(durationMin,durationMax)/10
        fx = director:createSprite({x=0, y=0, xAnchor=0.5, yAnchor=0.5, source="textures/asteroid1.png", xScale=0, yScale=0, rotation=angle, alpha=0.5, zOrder=-2})
        local rotation = angle+(math.random(0,360)*6/time)
        tween:to(fx, {time=time, x=destX, y=destY, xScale=1.5, yScale=1.5, onComplete=destroyNode, rotation=rotation, alpha=0.7})
        
    elseif fxType == "floating" then
        -- sprite comes on at side at random pos and across to another random offscreen pos
        local originAngle = math.random(0,359)
        local originX = radius*math.cos(originAngle)
        local originY = radius*math.sin(originAngle)
        
        local destAngle = ((originAngle+180) + math.random(-60, 60)) % 360
        local destX = radius*math.cos(destAngle)
        local destY = radius*math.sin(destAngle)
        local size = math.random(4, 12)/10
        
        local time = math.random(durationMin,durationMax)/10
        fx = director:createSprite({x=originX, y=originY, xAnchor=0.5, yAnchor=0.5, source="textures/asteroid1.png", xScale=size, yScale=size, rotation=originAngle, alpha=size/2, zOrder=-2})
        
        local completeFn
        if event.timer.canExplode and (math.random(1,10) <= event.timer.canExplode) then
            completeFn = splitAsteroid
            local explodePoint = math.random(30,65)/100
            destX = destX*explodePoint
            destY = destY*explodePoint
            fx.time = time
        else
            completeFn = destroyNode
        end
        
        local targetAngle = math.random(originAngle+90,originAngle+350) % 360 -- at least 90 deg rotation or looks too static
        tween:to(fx, {time=time, x=destX, y=destY, onComplete=completeFn, rotation=targetAngle})
    else
        dbg.assert("SpriteFX has invalid type")
        return
    end
    origin:addChild(fx)
    
    local t = system:addTimer(SpriteFX, math.random(freqMin,freqMax)/10, 1)
    t.durationMin = durationMin
    t.durationMax = durationMax
    t.freqMin = freqMin
    t.freqMax = freqMax
    t.fxType = fxType
    t.id = timerId
    t.canExplode = event.timer.canExplode
    -- just replace previous timer in table and let old one garbage collect
    sceneBattle.spriteFxTimer[timerId] = t
end

function splitAsteroid(target)
    local radius = sceneBattle.screenMaxX*0.8
    rotation=target.rotation + 60
    
    for i = 1,3 do
        local fx = director:createSprite({x=target.x, y=target.y, xAnchor=0.5, yAnchor=0.5, source="textures/asteroid1.png", xScale=target.xScale/2, yScale=target.yScale/2, rotation=rotation, alpha=target.alpha, zOrder=-2})
        origin:addChild(fx)
        local destX = target.x+radius*math.cos(rotation)
        local destY = target.y+radius*math.sin(rotation)
        tween:to(fx, {time=target.time, x=destX, y=destY, onComplete=destroyNode, rotation=800, alpha=0})
        rotation = rotation + 120
    end
    
    destroyNode(target)
end

AirFX = function(event)
    local timer = event.timer

    local fx = director:createCircle({xAnchor=0.5, yAnchor=0.5,
        x=timer.x,
        y=timer.y,
        radius=2,
        strokeColor=collidableColours.air,
        strokeWidth=1, strokeAlpha=0, alpha=0, color=color.black}) --set colour to avoid white circle on creation bug...

    origin:addChild(fx)
    tween:to(fx, {radius=100, time=0.5, strokeColor={g=110,b=60}})
    tween:to(fx, {radius=300, time=1.5, delay=0.5, strokeColor={g=0,b=0}})
    tween:to(fx, {strokeAlpha=timer.initAlpha, time=0.5})
    tween:to(fx, {strokeAlpha=0, time=1.2, delay=0.8, onComplete=destroyNode})
    timer.initAlpha = timer.initAlpha - 0.3

    -- push all balls away from sled on 2nd effect
    if event.doneIterations == 2 then
        PushCollidablesAwayFromPos(timer.x, timer.y)
    end
end

FreezePlayers = function(event)
    -- override if players are already frozen (extend freeze time)
    if sceneBattle.unFreezeTimer ~= nil then
        sceneBattle.unFreezeTimer:cancel()
    end
    for k,player in pairs(players) do
        player.sledColour = collidableColours.freezer
        player.sled.color = collidableColours.freezer
        player.sled.alpha = 1
        tween:from(player.sled, {alpha=0.3, time=0.5})
    end

    sceneBattle.unFreezeTimer = system:addTimer(EndFreeze, 2.0, 1)
end

EndFreeze = function(event)
    -- second is the actual freeze
    sceneBattle.unFreezeTimer = nil
    sceneBattle.freezeStarted = nil

    for k,player in pairs(players) do
        player.sledColour = gameInfo.playerColours[player.id]
        player.sled.color = gameInfo.playerColours[player.id]

        player.sled.alpha = 1
        tween:from(player.sled, {alpha=0.3, time=0.5})
    end
end

FreezerFX = function(event)
    local timer = event.timer

    local fx = director:createCircle({xAnchor=0.5,yAnchor=0.5,
        x=timer.x,
        y=timer.y,
        radius=2,
        strokeColor=collidableColours.freezer,
        strokeWidth=1, strokeAlpha=0, alpha=0, color=color.black})

    origin:addChild(fx)
    tween:to(fx, {radius=100, time=0.4})
    tween:to(fx, {radius=600, time=0.8, delay=0.4})
    tween:to(fx, {strokeAlpha=timer.initAlpha, time=0.3})
    tween:to(fx, {strokeAlpha=0, time=0.9, delay=0.3, onComplete=destroyNode})
    timer.initAlpha = timer.initAlpha - 0.15
end

HeatseekerImpactFX = function(event)
    local bomb = event.target
    local phase = event.doneIterations

    if phase < 5 then
        -- get each red light and explode it
        local light = table.remove(bomb.lights)
        --local light = bomb.lights[phase-4] KILLME?
        tween:to(light, {radius=6, alpha = 1, time=0.1})
        tween:to(light, {radius=6, alpha = 0, strokeAlpha=0, time=0.2, delay=0.09, onComplete=destroyNode})
    elseif phase < 7 then
        -- Inner rings: we destroy the rings and make new effects (rather than re-using them) as if the parent bomb
        -- circle starts scaling before children have finished animating, they will move in unexpected ways
        -- due to the way circles have different origin to anchor.
        local ring = table.remove(bomb.rings)
        local fx = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=bomb.x, y=bomb.y, radius=ring.radius, strokeColor=color.red, color=color.orange, strokeWidth=1, strokeAlpha=0, alpha=0.5})
        origin:addChild(fx)
        tween:to(fx, {radius=(phase-4)*100, strokeAlpha=1, strokeColor={r=255,g=255,b=255}, alpha=0, time=0.3, onComplete=destroyNode})

        destroyNode(ring)
    else
        -- as above for bomb itself
        local fxExplode = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=bomb.x, y=bomb.y, radius=bomb.radius, strokeColor=color.orange, color=color.orange, strokeWidth=1, strokeAlpha=0, alpha=0.5})
        origin:addChild(fxExplode)
        tween:to(fxExplode, {radius=300, strokeAlpha=1, alpha=0, time=0.3, onComplete=destroyNode})

        for n=3, 1, -1 do
            local fxImplode = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=bomb.x, y=bomb.y, radius=n*150, strokeColor=color.red, strokeWidth=1, strokeAlpha=1, alpha=0, color=color.black})
            origin:addChild(fxImplode)
            tween:to(fxImplode, {radius=0, strokeAlpha=0, time=1, onComplete=destroyNode})
        end

        DyingCollidableDestroy(bomb) -- will clear up remaining root obj

        -- point all balls at player
        for k,obj in pairs(collidables) do
            if not obj.ignore then
                local vecToPlayerX = bomb.x - obj.x
                local vecToPlayerY = bomb.y - obj.y
                local length = math.sqrt(vecToPlayerX*vecToPlayerX+vecToPlayerY*vecToPlayerY)
                vecToPlayerX = vecToPlayerX / length
                vecToPlayerY = vecToPlayerY / length
                obj.vec.x = vecToPlayerX * obj.speed
                obj.vec.y = vecToPlayerY * obj.speed
            end
        end
    end
end

HeatseekerFX = function(event)
    local timer = event.timer

    for k,ring in pairs(timer.target.rings) do
        ring.strokeAlpha = ring.ringAlpha
        tween:to(ring, {strokeAlpha=0, time=0.15})
    end

    timer.startAlpha = 0.8
    TrailFx(event)
end

function VectorFromAngle(angle, size)
    return {x = (math.sin(angle) * size), y = (math.cos(angle) * size)}
end

function sceneBattle:clearScreenFx()
    if self.rt then
        self.rt:clear(clearCol)
    end
end

function sceneBattle:reshowScreenFx(time)
    if self.screenFx then
        cancelTweensOnNode(self.screenFx)
        self.screenFx.alpha = 0.7
        
        if self.ballTimer then
            tween:to(self.screenFx,
                {alpha=0.05, time=time or self.ballTimer.period + self.ballTimer.delay - self.ballTimer.elapsed, easing=ease.powIn})
        end
    end
end
    
function ShowMessage(message, delay, shrink, expandDir, vDisplacement, xPos, yPos, color)    
    x = xPos or 0
    y = yPos or 0
    local vAlign
    -- direction of grow/shring depends on text-to-origin alignment
    -- defaults to alternating between up and down

    if not expandDir then
        expandDir = sceneBattle.messageDir or "up"
    end
    if expandDir == "down" then
        vAlign="top"
        sceneBattle.messageDir = "up" --switch on next call
    elseif expandDir == "up" then
        vAlign="bottom"
        sceneBattle.messageDir = "down"
    elseif expandDir == "none" then
        vAlign="center"
    else
        dbg.assert("expandDir is invalid")
        vAlign="bottom"
    end
    
    if not vDisplacement then
        if vAlign == "bottom" then
            vDisplacement = 40
        elseif vAlign == "top" then
            vDisplacement = -40
        else
            vDisplacement = 0
        end
    end
    
    message = director:createLabel({x=x, y=y+vDisplacement, hAlignment="centre", vAlignment=vAlign, text=message, color=color or menuBlue, font=fontMainLarge, xScale=0, yScale=0})
    origin:addChild(message)
    
    if shrink then
        message.xScale=5
        message.yScale=5
        alpha=0
        tween:to(message, {alpha=1, time=0.5, delay=delay})
        tween:to(message, {xScale=0, yScale=0, alpha=0, time=2, onComplete=destroyNode, delay=delay})
    else
        tween:to(message, {xScale=5, yScale=5, alpha=0, time=2, onComplete=destroyNode, delay=delay})
    end
end

function ShowAchievement(achievementId)
    gameInfo.achievements[achievementId] = true
    sceneBattle:reshowScreenFx()
    ShowMessage("NEW ACHIEVEMENT:", 2.0, false, "up", nil, nil, nil, achieveCol)
    
    --local offset = -40
    local delay = 2.3
    --if table.getn(gameInfo.achievementNames[achievementId]) > 1 then
    --    offset = 0
    --end
    local dir = "down"
    for k,v in pairs(gameInfo.achievementNames[achievementId]) do
        ShowMessage(v, delay, false, dir, nil, nil, nil, achieveCol)
        --offset = -100
        if dir == "down" then
            delay = delay + 1
            dir = "up"
        else
            delay = delay + 0.3
            dir = "down"
        end
    end
    
    if googlePlayServices and sceneMainMenu.gotPlayServices then
        if googlePlayServices.unlockAchievement(gameInfo.achievementServiceIds[achievementId].googlePlay, true) == false then
            dbg.assert(false, "failed to unlock achievement: " .. achievementId)
        end
        dbg.print("Google Play Services: unlocking achievement: " .. achievementId ..
            "(" .. gameInfo.achievementServiceIds[achievementId].googlePlay .. ")")
    end

    analytics:logEvent("achievement", {name=achievementId})
end
---------------------------------------------------------------------------
-- "collidables": balls and bullets that players can hit.
-- Not using a class for these... they are always created dynamically
-- and have little need for methods. Avoiding classes and just using
-- Nodes  directly means we can pass them easily around with onComplete
-- in tweens, etc.

function CollidableCreate(objType, xPos, yPos, startVector, startSpeed, objectOnly)
    objType = DEBUG_OVERRIDE_TYPE or objType
    
    local colour = collidableColours[objType]
    
    if objType == "expander-up" or objType == "expander-down" then
        local yMirror
        if objType == "expander-up" then
            yMirror = 1 --allow flipping for up & down arrow
        else
            yMirror = -1
        end

        collidable = director:createLines({x=xPos, y=yPos+yMirror*30, coords={-ballRadius,0, 0,yMirror*ballRadius, ballRadius,0}, strokeWidth=1, strokeColor=colour, color=colour, alpha=0.5})

        collidable.objType = "expander"
        collidable.yMirror = yMirror
        collidable.dontBounce = true -- dont bounce back

        if objectOnly == nil then
            collidable.speed = startSpeed --wouldn't be set yet otherwise
            ExpanderAnim(collidable) -- start animating shape movement (recursive)

            -- draw self-destroying trail effects
            if startVector.x > 0 then
                collidable.xMirror = 1
            else
                collidable.xMirror = -1
            end
            local fxTimer = collidable:addTimer(ExpanderFx, 25/startSpeed, 0, 0) -- effects are applied to shapes, so we can cancel them easily on shape destruction
        end

    elseif objType == "heatseeker" then
        -- using ballRadius+1 as it looks nicer for heatseekers! collisions are still just ballRadius but thats near enough!
        collidable = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=xPos, y=yPos, radius=ballRadius+1, strokeWidth=1, strokeColor=collidableColours[objType], alpha=0, color=color.black})
        collidable.rings = {}
        collidable.lights = {}
        collidable.dontBounce = true

        -- objects added in order we want to hide them in eventually (outside->middle)
        local ringRadius = ballRadius+1

        -- NB: we position relative to centre of ball. Annoyingly Quick beta
        --     makes balls centre on x&y by changing their anchor pos, then children positioned
        --     relative to that anchor change so they are not relative to parents centre.
        --     Because anchors are fractions, its a pain to work around by changing anchors
        --     so we're just offsetting children.
        --     We've set anchors to 0.5,0.5 explicitly so the workaround wont break if anchors change in Quick release.
        xPos = ringRadius
        yPos = ringRadius
        local childX
        local childY
        local ringAlpha = 1
        local startAlpha

        local ringColour
        for n=1, 6, 1 do
            if n < 3 then
                childX = xPos childY = yPos
                -- fading rings outside of bomb
                ringRadius = ringRadius + 3
                ringAlpha = ringAlpha - 0.4
                startAlpha = 0
                if n == 1 then ringColour = color.grey
                else ringColour = color.lightGrey end
            else
                -- 4 red lights that will flash in sequence on detonation
                ringRadius = 2
                ringColour = color.red
                startAlpha = 1
                if n == 3 then childX = xPos-3 childY=yPos-3
                elseif n == 4 then childX = xPos+3 childY=yPos-3
                elseif n == 5 then childX = xPos+3 childY=yPos+3
                else childX = xPos-3 childY=yPos+3
                end
            end

            -- NB: circle parent has offset anchors so have to set x=,y= to offset that!
            local item = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=childX, y=childY, radius=ringRadius, strokeWidth=1, strokeAlpha=startAlpha, strokeColor=ringColour, color=ringColour, alpha=0})
            collidable:addChild(item)

            -- NB: tween values aren't inherited (apart from position which is always inherited!)
            -- so need to match parents animation per child
            if objectOnly == nil then
                tween:from(item, {strokeAlpha=0, time=0.5})
            end

            if n < 3 then
                item.ringAlpha = ringAlpha
                table.insert(collidable.rings, item)
            else
                table.insert(collidable.lights, item)
            end
        end

        if objectOnly == nil then
            tween:from(collidable, {strokeAlpha=0, time=0.5})

            -- ignore object (no movement or collisions until it appears)
            collidable.ignore = true
            collidable.appearTimer = collidable:addTimer(AppearTimer, 0.4, 1, 0)
            --collidable.appearTimer.obj = collidable

            -- reuse Bullet trail effect, but slower as heatseeker moves slower
            local fxTimer = collidable:addTimer(HeatseekerFX, 0.2, 0, 0.2)
            --fxTimer.obj = collidable
            
            if gameInfo.controlType == "onePlayer" and gameInfo.mode ~= "survival" and gameInfo.wave == 1 then
                ShowMessage("heatseeker", 0.5, false)
                sceneBattle:reshowScreenFx()
            end
        end
    else
        -- ball, powerup, cloak and bullet are all coloured balls
        
        collidable = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=xPos, y=yPos, radius=ballRadius, strokeWidth=1, strokeColor=colour, alpha=0, color=color.black})
        
        if objType == "health" then
            collidable.strokeAlpha=0.6
            collidable.alpha=1
            --TODO: seems like alpha/strokeAlpha are always inherited and cant be overriden
            --So, having to make ball non-trasparent. Using a node breaks the tween/trailfx logic.
            -- could improve that to allow collidable != circle. Investigate if alpha can be overriden somehow.
            local part1 = director:createRectangle({x=ballRadius, y=ballRadius, xAnchor=0.5, yAnchor=0.5, w=ballRadius*2-6, h=ballRadius/2, strokeWidth=0, color=colour, alpha=1})
            local part2 = director:createRectangle({x=ballRadius, y=ballRadius, xAnchor=0.5, yAnchor=0.5, w=ballRadius/2, h=ballRadius*2-6, strokeWidth=0, color=colour, alpha=1})
            tween:to(part1, {time=0.5, xScale=1.5, yScale=1.5, mode="repeat", alpha=0.5})
            tween:to(part2, {time=0.5, xScale=1.5, yScale=1.5, mode="repeat", alpha=0.5})
            collidable:addChild(part1)
            collidable:addChild(part2)
            
        elseif objType == "powerup" or objType == "cloak" then
            local bolt = director:createLines({x=ballRadius, y=ballRadius, coords={1-4,0-5, 4-4,5-5, 0-4,5-5, 3-4,10-5, 7-4,10-5, 5-4,7-5, 10-4,7-5, 1-4,0-5}, strokeWidth=1, strokeColor=colour, color=color.black, alpha=0})
            tween:to(bolt, {time=0.5, xScale=3, yScale=3, mode="repeat", strokeAlpha=0})
            collidable:addChild(bolt)
            if objType == "cloak" then
                collidable.flickerMin = 1
                collidable.flickerMax = 10
                collidable:addTimer(FlickerFx, math.random(15,20)/10, 1)
            end
        end
        
        tween:from(collidable, {xScale=0, yScale=0, time=0.2})

        local fxTimer
        if objType == "bullet" then
            fxTimer = collidable:addTimer(TrailFx, 0.1, 0, 0)
            fxTimer.startAlpha = 0.9
        else
            fxTimer = collidable:addTimer(TrailFx, 0.3, 0, 0)
        end
        --fxTimer.obj = collidable
    end

    collidable.vec = startVector
    collidable.speed = startSpeed
    if not collidable.objType then collidable.objType = objType end
    
    if not objectOnly then
        -- table indexed by unique main element name. Easier and more robust than trying to use an array with unit index (lua arrays are fiddly)
        collidables[collidable.name] = collidable
    end
    
    collidable.mainColor = colour --for easy look up in effects etc
    
    origin:addChild(collidable)
    return collidable
end

function RestoreBall(vals)
    local ball = CollidableCreate(vals.objType, vals.x, vals.y, vals.vec, vals.speed)
    ball.replaceOnLeaveScreen = vals.replaceOnLeaveScreen
    
    if vals.objType == "expander-up" then
        CollidableCreate("expander-down", vals.x, vals.y, vals.vec, vals.speed)
    elseif vals.objType == "heatseeker" then
        ball.enemy = players[vals.enemyId]
    end
end

function AddBall(vals)
    dbg.print("AddBall")
    -- deafult values
    if not vals then vals = {} end
    local xPos = vals.xPos or 0
    local yPos = vals.yPos or 0
    local minAngle = vals.minAngle or 0
    local maxAngle = vals.maxAngle or 359
    local angle = vals.angle or math.random(minAngle,maxAngle)
    
    local allowedBallTypes = vals.allowedBallTypes
    local objType = vals.objType
    if not objType then
        local typesCount
        local defaultProbability = true
        if allowedBallTypes then
            typesCount = table.getn(allowedBallTypes)
        else
            if gameInfo.controlType == "onePlayer" then
                defaultProbability = false
                local waveToCheck
                if gameInfo.mode == "survival" then
                    waveToCheck = MAX_MANAGED_WAVE -- last wave has nice probabilities set with all the items in play
                else
                    waveToCheck = math.min(MAX_MANAGED_WAVE, gameInfo.wave)
                end
                allowedBallTypes = ALLOWED_BALLS_IN_WAVE[waveToCheck]
                typesCount = POWERUP_PROBABILITY_IN_WAVE[waveToCheck]
                if not vals.dontDefaultTypeToBall then
                    typesCount = typesCount + BALL_PROBABILITY_IN_WAVE[waveToCheck]
                end
            else
                allowedBallTypes = {"powerup", "cloak", "health"}
                typesCount = 3
            end
        end
        if defaultProbability and not vals.dontDefaultTypeToBall then
            typesCount = typesCount*2 -- 1:1 ratio of balls to other types
        end
        
        objType = math.random(1, typesCount)
        objType = allowedBallTypes[objType] or "ball"
    end
    
    local defaultSpeed = sceneBattle.ballSpeed
    if objType == "bullet" then defaultSpeed = defaultSpeed*1.4 end
    local minSpeed = vals.minSpeed or defaultSpeed
    local maxSpeed = vals.maxSpeed or defaultSpeed+15
    local speed = vals.speed or math.random(minSpeed, maxSpeed) --NB math.random needs integers
    
    if objType == "reverser" then
        if sceneBattle.reverseStarted then
            sceneBattle:queueReplacementBall(0.5)--gets too messy/hard with overlapping freeze or reverse
        else
            ReverserFx(1, origin)
            for k,player in pairs(players) do
                if player.reverseTimer then
                    player.reverseTimer:cancel()
                else
                    if player.touches and player.moveWithFinger then
                        player.reversePos = player.touches[player.moveWithFinger].y
                    end
                    player.velocity = -player.velocity
                end
                player.reverseTimer = system:addTimer(UnReverse, 4, 1, 0)
                player.reverseTimer.player = player
            end
            sceneBattle:queueReplacementBall(1.5)--dont want instant replacement
            ShowMessage("reverse")
            sceneBattle:reshowScreenFx()
        end
        return
    elseif objType == "freezer" then
        if sceneBattle.freezeStarted then
            sceneBattle:queueReplacementBall(0.5)
        else
            player1.sled:addTimer(FreezePlayers, 1, 1, 0)
            sceneBattle.freezeStarted = true
            --todo: no need to track sceneBattle.freezeTimers. can just cancel all play timers
            local fxTimer = player1.sled:addTimer(FreezerFX, 0.2, 3, 0)
            fxTimer.x = 0 --center in screen
            fxTimer.y = 0
            fxTimer.initAlpha = 1
            ShowMessage("freeze")
            sceneBattle:reshowScreenFx()
            sceneBattle:queueReplacementBall(1.5)
        end
        return
    end
    
    local vector = VectorFromAngle(math.rad(angle), speed)
    local ball = CollidableCreate(objType, xPos, yPos, vector, speed) --we push the ball to a global table in create
    ball.replaceOnLeaveScreen = true
    
    if objType == "expander-up" then
        CollidableCreate("expander-down", xPos, yPos, vector, speed)
    elseif objType == "heatseeker" then
        ball.enemy = players[math.random(1,2)]
    end
    
    RingFX({timer={x=xPos, y=yPos, color=ball.mainColor, strokeAlpha=0.5, rEnd=speed/MAX_BALL_SPEED*sceneBattle.screenMaxY}})
end

-- Collidable callbacks and helper functions --------

function setStarAnimation(speedMultiple, rotation, decelerate)
    if sceneBattle.deathPhase then
        return
    end
        
    if speedMultiple == 0 then
        endStarMovement(2)
    else
        cancelTweensOnNode(origin)
        
        sceneBattle.starSpeed = (speedMultiple+1) * speedMultiple * 20 - 10 --max speed on multiple=5 is 590 pixels/sec
        sceneBattle.starAlpha = 0--(speedMultiple-1)/10 -- >0 means get white dot as stars pile up in center!
        sceneBattle.starsMove = true
        
        -- turn from dots to streaks
        if speedMultiple > 2 or decelerate then
            local streakSize
            if speedMultiple > 2 then
                streakSize = speedMultiple*(speedMultiple-1)
            else
                streakSize = 1
            end
            for kStar, star in pairs(sceneBattle.background.children) do
                --if gameInfo.wave and (gameInfo.wave > 6 and speedMultiple == 5) then
                --    -- on later levels turn to crazy vortext effect at the end
                --    tween:to(star, {yScale=streakSize, xScale=1, time=1})
                --else
                    tween:to(star, {xScale=streakSize, time=1})
                --end
            end
        end
        
        -- screen wobble on fastest speed
        local time
        if gameInfo.wave and speedMultiple > 0 then
            rotation = gameInfo.wave*0.15
            if speedMultiple == 5 then
                time = 2
                rotation = gameInfo.wave*0.6
            end
        end
        
        if rotation then
            if not time then
                time = 10 / rotation
            end
            
            if speedMultiple == 1 and not gameInfo.wave then
                tween:to(origin, {time=1, rotation=0}) --reset on deceleration
            else
                tween:to(origin, {time=time/2, rotation=-rotation})
                tween:to(origin, {time=time, mode="mirror", delay=time/2, rotation=rotation})
            end
        end
        --[[if (gameInfo.wave and speedMultiple == 5) or rotation then
            local time = 2
            
            if rotation then
                time = 10 / rotation
            end
            rotation = rotation or gameInfo.wave*0.5
            
            if speedMultiple == 1 then
                tween:to(origin, {time=1, rotation=0}) --reset on battle deceleration
            else
                tween:to(origin, {time=time/2, rotation=-rotation})
                tween:to(origin, {time=time, mode="mirror", delay=time/2, rotation=rotation})
            end
        end]]--
    end
    
    sceneBattle.previousStarSpeedMultiple = speedMultiple
end

function setBgAnimations(wavePosInSet)
    -- set star movement and screen rotation.
    -- first of 6 wave set has static twinkling stars.
    -- then they move, accelerate and eventually reset to static
    setStarAnimation((gameInfo.wave-1) % 6) --0->5, not 1->6
    
    --animate flying sprites
    for kT,vT in pairs(sceneBattle.spriteFxTimer) do
        vT:cancel()
        sceneBattle.spriteFxTimer[kT] = nil
    end
    sceneBattle.spriteFxTimer = {}
    
    if wavePosInSet == 5 or (gameInfo.wave > 6 and wavePosInSet > 3) then
        for i=0,2 do
            local t = system:addTimer(SpriteFX, 2, 1, i*2)
            table.insert(sceneBattle.spriteFxTimer, t)
            t.id = i+1
            
            if wavePosInSet == 4 then
                t.durationMin = 40
                t.durationMax = 60
                t.freqMin = 40
                t.freqMax = 80
            else
                t.durationMin = 20
                t.durationMax = 40
                t.freqMin = 10
                t.freqMax = 30
            end
            t.fxType = "shooting"
        end
    elseif wavePosInSet < 4 and gameInfo.wave > 6 then
        for i=0,2 do
            local delay = 0
            if wavePosInSet == 1 then delay = 6 end
            local t = system:addTimer(SpriteFX, 2, 1, delay+i*2)
            table.insert(sceneBattle.spriteFxTimer, t)
            t.id = i+1
            
            if wavePosInSet == 1 then
                t.freqMin = 50
                t.freqMax = 80
            else
                t.freqMin = 20
                t.freqMax = 40
                t.canExplode = 4 --4 in 10 explode
            end
            
            if wavePosInSet == 3 then
                t.durationMin = 20
                t.durationMax = 30
            else
                t.durationMin = 40
                t.durationMax = 80
            end
            t.fxType = "floating"
        end
    end
end

function endStarMovement(time)
    cancelTweensOnNode(origin)
    tween:to(origin, {time=time, rotation=0})
    
    --starsDecelerate controls if and how quickly stars slow down.
    --(300 pixels per sec)/time is a cheap estimate!
    sceneBattle.starsDecelerate = 300/time
    
    for kStar, star in pairs(sceneBattle.background.children) do
        cancelTweensOnNode(star)
        tween:to(star, {xScale=1, yScale=1, time=time})
        tween:to(star, {strokeColor=star.originalStroke, time=time, delay=1})
        tween:to(star, {strokeAlpha=0.3, mode="mirror", time=0.5+kStar*0.05, delay=kStar*0.05})
    end
end

-- subtracts 1 from wave count and does update logic if wave is over
function checkWaveIsOver()
    if sceneBattle.waveLeft then
        if sceneBattle.waveLeft.value == 0 then
            for k,obj in pairs(collidables) do
                obj.dontBounce = true
                obj.replaceOnLeaveScreen = false
                PushCollidableAwayFromPos(obj, 0, 0, 2)
            end
            
            --if sceneBattle.rt then
            --    sceneBattle.rt:clear(clearCol)
            --    cancelTweensOnNode(sceneBattle.screenFx)
            --    sceneBattle.screenFx.alpha = 0.7
            --end
            -- Note that mnessage display will clear screenFx and set its alpha back on
            
            sceneBattle.waveLeft:SetValue(INIT_WAVE_SIZE+gameInfo.wave+1)
            --increase by 2 on 2nd wave (go from super easy intro to real difficulty!)
            gameInfo.wave = gameInfo.wave + 1
            ShowMessage("WAVE " .. gameInfo.wave, 0, false, "up")
            if gameInfo.controlType == "onePlayer" and gameInfo.wave == 2 then
                ShowMessage("collect powerups", 2.0, false, "down", 0)
                ShowMessage("for ammo and health", 2.8, false, "down", -100)
            elseif gameInfo.controlType == "onePlayer" and gameInfo.wave == 3 then
                ShowMessage("beware of ", 2.0, false, "down", 0)
                ShowMessage("faulty powerups!", 2.8, false, "down", -100)
            end
            
            local achievement = "wave" .. (gameInfo.wave-1)
            if (gameInfo.wave == 7 or gameInfo.wave == 16 or gameInfo.wave == 21) and not gameInfo.achievements[achievement] then
                ShowAchievement(achievement)
            end
            
            if gameInfo.wave == SURVIVAL_UNLOCKED_WAVE and not gameInfo.achievements.survival then
                ShowAchievement("survival")
            end
            
            --ensure message text is emphasised
            sceneBattle:clearScreenFx()
            sceneBattle:reshowScreenFx()
            
            analytics:logEvent("waveStarted", {waveNum=tostring(gameInfo.wave), score=tostring(sceneBattle.score.value)})
            -- restart ball adding timers
            sceneBattle.ballSpeed = math.min(SECOND_BALL_SPEED + sceneBattle.ballSpeed/4, MAX_BALL_WAVE_START_SPEED)
                --reduce speed or gets too hard too fast
            -- todo: we may want to control both speed and wave length explicitly
            -- with similar method to the ball types tables, and then default to just upping them later
            
            -- waves run in sets of 6
            local wavePosInSet = gameInfo.wave % 6
            
            setBgAnimations(wavePosInSet)
            
            if sceneBattle.ballInitTimer then
                sceneBattle.ballInitTimer:cancel() --maybe user created balls with weapon before timer finished!
            end
            sceneBattle.ballTimer:cancel() --safe to cancel as not yet nilled
            local newBallDelay = math.min(sceneBattle.ballTimer.ballDelay+1, MAX_NEW_BALL_DELAY)
            sceneBattle.ballTimer = system:addTimer(AddNewBall, newBallDelay, 1)
            sceneBattle.ballTimer.ballDelay = newBallDelay
            sceneBattle.ballInitTimer = system:addTimer(AddNewBall, INITIAL_BALL_DELAY, math.min(INITIAL_BALL_QUEUE+gameInfo.wave-1, MAX_INIT_BALLS))

            sceneBattle.ballInitTimer.isInit = true
            
            sceneBattle:setBallOverrides(gameInfo.wave, wavePosInSet)
            
            for n=1, INITIAL_BALL_QUEUE do
                 -- lock first balls to fairly horizontal angles
                local randAngle = math.random(0, 359)
                if randAngle < 45 or (randAngle > 135 and randAngle < 225) then
                    randAngle = randAngle + 90
                elseif randAngle > 315 then
                    randAngle = randAngle - 270
                end
                sceneBattle.ballOverrides[n]["angle"]=randAngle
            end
            sceneBattle.ballsAddedThisWave = 0
            
            if gameInfo.soundOn then
                local tryId = gameInfo.wave
                local song = nil
                while song == nil and tryId > 0 do
                    song = waveMusic[tryId]
                    tryId = tryId-6
                end
                if song then
                    audio:playStream("sounds/" .. song, true)
                end
            end
            
            return true -- signal no new ball to add if wave is over
        end
        sceneBattle.waveLeft:Increment(-1)
        if sceneBattle.waveLeft.value == 0 then
            tween:to(sceneBattle.waveLeft.digits[1].origin, {time=0.3, xScale=3, yScale=3, mode="mirror", alpha=0})
            --anim will be auto cancelled once counter gets reset
        end
    end
    return false
end

function AddNewBall(event)
    dbg.print("AddNewBall")
    if event.timer.isInit and event.doneIterations == INITIAL_BALL_QUEUE then
        sceneBattle.ballInitTimer = nil --so we dont try to cancel/pause it when over
    end
    
    -- player gets a point for each new ball added
    if sceneBattle.score then
        sceneBattle.score:Increment(1)
        gameInfo.streak = gameInfo.streak + 1
        if gameInfo.streak == 30 then
            if not gameInfo.achievements.battle then
                ShowAchievement("battle")
            end
        elseif gameInfo.streak >=20 and gameInfo.streak <= 50 and gameInfo.streak % 10 == 0 then
            local achievement = "streak" .. gameInfo.streak
            if not gameInfo.achievements[achievement] then
                ShowAchievement(achievement)
            end
        end
        if gameInfo.mode == "survival" then
            if gameInfo.score == 40 and not gameInfo.achievements.survival40 then
                ShowAchievement("survival40")
            elseif gameInfo.score == 50 and not gameInfo.achievements.survival50 then
                ShowAchievement("survival50")
            end
        end
    end
    sceneBattle.ballsAddedThisWave = sceneBattle.ballsAddedThisWave + 1
    
    if checkWaveIsOver() == true then
        return
    end
    
    sceneBattle.ballSpeed = sceneBattle.ballSpeed + NEW_BALL_SPEED_INCREASE
    local vals = {}
    if sceneBattle.ballOverrides[sceneBattle.ballsAddedThisWave] then
        dbg.print("BALL OVERRIDE!")
        for k,v in pairs(sceneBattle.ballOverrides[sceneBattle.ballsAddedThisWave]) do
            dbg.print("override: " .. k .. "to" .. v)
            vals[k] = v
        end
    end
    
    if event.timer.ballDelay then --re-queue, with new duration on new wave
        sceneBattle.ballTimer = system:addTimer(AddNewBall, event.timer.ballDelay, 1)
        sceneBattle.ballTimer.ballDelay = event.timer.ballDelay
    end
    
    -- reset burn effect on new balls to prevent screen getting too messy
    -- ignore initial volley of balls or will reset too fast
    if sceneBattle.rt then
        if not event.timer.isInit then
            sceneBattle:clearScreenFx()
        end
        
        if not event.timer.isInit or (event.timer.isInit and event.doneIterations == INITIAL_BALL_QUEUE) then
            sceneBattle:reshowScreenFx()
        end
    end
    
    AddBall(vals)
end

-- calls recursively to queue-up adding balls after eachother to guarantee delay between them
ReplenishBalls = function(event)
    dbg.print("ReplenishBalls")
    sceneBattle.ballSpeed = sceneBattle:setBallSpeed(sceneBattle.ballSpeed + REPLACE_BALL_SPEED_INCREASE)
    sceneBattle.ballCreateQueue = sceneBattle.ballCreateQueue -1
    AddBall()
    if sceneBattle.ballCreateQueue > 0 then
        sceneBattle.ballReplaceTimer = system:addTimer(ReplenishBalls, REPLACE_BALL_DELAY, 1)
    else
        sceneBattle.ballReplaceTimer = nil
    end
end

function sceneBattle:setBallSpeed(speed)
    if speed >= MAX_BALL_SPEED then
        if self.waveLeft then
            dbg.print("MAX SPEED REACHED, wave = " .. gameInfo.wave .. ", balls left = " .. self.waveLeft.value)
            dbg.assert(false, "MAX SPEED REACHED, wave = " .. gameInfo.wave .. ", balls left = " .. self.waveLeft.value)
        end
    end
    speed = math.min(speed, MAX_BALL_SPEED)
    return speed
end

function sceneBattle:queueReplacementBall(extraDelayTime)
    if self.deathPhase or self.ignoreEvents then return end
    
    dbg.print("queue replacement ball")
    extraDelayTime = extraDelayTime or 0
    
    -- start timer if not running
    if not self.ballReplaceTimer then
        self.ballReplaceTimer = system:addTimer(ReplenishBalls, REPLACE_BALL_DELAY+extraDelayTime, 1)
    end
    self.ballCreateQueue = self.ballCreateQueue + 1 -- timer recurses for each ball in queue
end


function DyingCollidableDestroy(collidable)
    --dbg.print("destroy dead collidable: " .. target.name)
    if not deadCollidables[collidable.name] then
        dbg.print(collidable.name)
        dbg.assert(false, "dead collidable not in list!!!")
    end
    
    if collidable.replaceOnLeaveScreen then 
        sceneBattle:queueReplacementBall()
    end
    
    destroyNodesInTree(collidable, true) -- may still have children if abandoned during animation
    deadCollidables[collidable.name] = nil
end

-- Remove from main table - visual node can still be active in order to animate death
-- Manually cancelling timers & tweens where appropriate because they can still run until Lua does garbage collection!
-- As this is a static function that takes a Quick Node as 1st param
-- it can be passed to things like tween's onComplete.
function CollidableDestroy(collidable, killLater, keepTimersRunning, keepTweensRunning)
    
    local uniqueId = collidable.name

    --dbg.print("remove collidable with id: " .. collidable.name)

    --keepTimersRunning & keepTweensRunning checked if killLater is used
    --intended use is to run a last timer or tween during death
    
    if collidable.dying then
        --would likely crash at some point oherwise, e.g. trying to do removeFromParent() when has no parent
        -- note that crash could be delayed till some table clean up event, or not occur at all, if
        -- CollidableDestroy cancels a tween that would have called DyingCollidableDestroy.
        -- Might want to enforce ignoring dying collibales, i.e. by returning here instead of asserting
        -- if game logic changes...
        dbg.assert(false, "Trying to destroy dying collidable: " .. uniqueId .. " of type " .. collidable.objType)
        print("Trying to destroy dying collidable: " .. uniqueId .. " of type " .. collidable.objType)
        -- also print() for release build crash debugging
    end
    
    collidable.dying = true --allow quick check if already dead

    if killLater then
        if not keepTimersRunning then -- stop existing timer effects while node dies
            cancelTimersOnNode(collidable)
        end
        if not keepTweensRunning then
            cancelTweensOnNode(collidable)
        end
        
        deadCollidables[uniqueId] = collidable -- store by shape name as table can't be an array
                                               -- NB this would be simpler if we had collidables=nodes!
    else
        if collidable.replaceOnLeaveScreen then
            sceneBattle:queueReplacementBall()
        end
        -- clean up any children, e.g. heatseeker rings etc if they weren't exploded (e.g. battle abandoned)
        --dbg.print("destroy node here: " .. collidable.name)
        destroyNodesInTree(collidable, true)
    end

    collidables[uniqueId] = nil
end


-- Battle Scene main control events --------------------------------------------------------------------

moveFlagAI = 0 --hack to make p2 move on its own for testing
function AIFire(event)
    local timer = event.timer
    player2:Fire()
end

function sceneBattle:update(event)
    self.effectSkipFlag = not self.effectSkipFlag
    
    if pauseflag then
        pauseflag = false
        if self.gamePaused then
            resumeNodesInTree(self.originPause)
        else
            system:resumeTimers()
            resumeNodesInTree(origin)
            if sceneBattle.pauseMenu and not sceneBattle.pauseMenu.disabled then
                PauseGame({phase="ended"}) --activate pause menu on non-paused resume
            end
        end
    end
    
    if self.gamePaused then
        fullscreenEffectsUpdate(self)
        return
    end
    
    self.frameCounter = self.frameCounter+1 --for locking visual time-independant events to only once per frame

    -- limit frame duration as this can return huge values if app pauses
    -- and could result in a huge object distance jump otherwise!
    if system.deltaTime > 0.1 then
        system.deltaTime = 0.1
    end
    
    -- freeze during intro messages on resuming suspended games
    if self.continuePause and system.gameTime < self.continuePause then
        fullscreenEffectsUpdate(self)
        return
    end
    
    if self.starsDecelerate then
        -- wind down speed during death animations and when stars stop every 6 waves
        if self.starSpeed > 0 then
            self.starSpeed = self.starSpeed - self.starsDecelerate * system.deltaTime
        end
        if self.starSpeed <= 0 then
            self.starSpeed = 0
            self.starsMove = false
            self.starsDecelerate = false
        end
    end
    if self.starsMove then
        for kStar,star in pairs(self.background.children) do
            star.x = star.x + star.normVector.x*system.deltaTime*self.starSpeed
            star.y = star.y + star.normVector.y*system.deltaTime*self.starSpeed
            if star.x > self.screenMaxX or star.x < self.screenMinX or star.y > self.screenMaxY or star.y < self.screenMinY then
                star.x = 0
                star.y = 0
                if not self.starsDecelerate then --avoid stopping the stroke shrinking to dot effect if decelerating
                    cancelTweensOnNode(star)
                end
                star.strokeAlpha=self.starAlpha
                tween:to(star, {strokeAlpha=1, time=maxY/self.starSpeed}) -- fade on as moves to screen edge
            end
        end
    end
    
    -- update loop keeps running when battle/game is ending. skip to avoid dealing with players being recreated etc
    if self.endTimer then
        fullscreenEffectsUpdate(self)
        return
    end
    
    --dbg.print("DELTA: " .. system.deltaTime)
    -- system.deltaTime is time elapsed since last frame (TODO: is this already avergaed over some frames)
    -- should be somewhere between 0.03 (about 30fps) and 0.015 (60)
    -- move by system.deltaTime to move 1 pixel in 1 second

    -- MOVE PLAYERS --
    for pK,player in pairs(players) do

        if self.unFreezeTimer == nil then
            if gameInfo.controlType == "p1VsAI" and pK == 2 and not player.deadFlag then
                -- AI for player 2 - for now just moves up and down!!!

                if (moveFlagAI == 0 and player.reverseTimer == nil) or (moveFlagAI == 1 and player.reverseTimer ~= nil) then
                    if player.sled.y < 200 then
                        player.sled.y = player.sled.y + system.deltaTime * 100
                    else
                        moveFlagAI = 1
                    end
                else
                    if player.sled.y > -200 then
                        player.sled.y = player.sled.y - system.deltaTime * 100
                    else
                        moveFlagAI = 0
                    end
                end
            --elseif gameInfo.controlType == "p1LocalVsP2Remote" and pk == 2 or gameInfo.controlType == "p1RemoteVsP2Local" and pk == 1 then
            --    remote control of other player goes here!
            else
                -- local control for player. Can have 2 players if using local vs local

                -- move exactly with finger while finger is down
                if player.moveWithFinger then
                    if player.reverseTimer then
                        --print ("REVERSE for player " .. player.id)
                        player.sled.y = player.reversePos - player.touches[player.moveWithFinger].touchPosDiff + (player.reversePos - player.touches[player.moveWithFinger].y)
                    else
                        player.sled.y = player.touches[player.moveWithFinger].y - player.touches[player.moveWithFinger].touchPosDiff
                    end
                else
                    -- if finger is up, keep moving but decelerate by 100pix/sec (cheap approximation)
                    player.sled.y = player.sled.y + player.velocity*system.deltaTime
                    
                    local decel = 100*system.deltaTime

                    if player.velocity > 0 then
                        player.velocity = math.max(0, player.velocity - decel)
                    elseif player.velocity < 0 then
                        player.velocity = math.min(0, player.velocity + decel)
                    end
                end
            end
        end

        -- keep within screen bounds
        if player.sled.y > maxY - player.halfHeight then
            player.sled.y = maxY - player.halfHeight
            player.velocity = 0
        elseif player.sled.y < minY + player.halfHeight then
            player.sled.y = minY + player.halfHeight
            player.velocity = 0
        end

        -- change sled size

        if player.halfHeight ~= player.newHalfHeight and not player.deadFlag then
            if player.halfHeight < player.newHalfHeight then
                player.halfHeight = player.halfHeight + 1 --why bother with frame rate here :)
            else
                player.halfHeight = player.halfHeight - 1
            end

            -- literally replace onld sled with new! Note that anything the sled node is doing (tween etc) will be cancelled
            local xPos = player.sled.x
            local yPos = player.sled.y
            player:RemoveSled()
            player:AddSled(xPos,yPos)
        end

        -- Players die but we keep most logic running so 1) anims finish and 2) other player has to try to survive the explosion!
        if player.health.value <= 0 and not player.deadFlag then
            player.deadFlag = 1
        end
    end


    -- Handle Collisions

    for k,obj in pairs(collidables) do
        if obj.ignore == nil then
            -- point heatseeker at player
            if obj.objType == "heatseeker" then
                local vecToPlayerX = obj.enemy.sled.x - obj.x
                local vecToPlayerY = obj.enemy.sled.y - obj.y
                local length = math.sqrt(vecToPlayerX*vecToPlayerX+vecToPlayerY*vecToPlayerY)
                vecToPlayerX = vecToPlayerX / length
                vecToPlayerY = vecToPlayerY / length
                obj.vec.x = vecToPlayerX * obj.speed
                obj.vec.y = vecToPlayerY * obj.speed
            end

            -- move
            obj.y = obj.y + obj.vec.y * system.deltaTime --scale by frame rate
            obj.x = obj.x + obj.vec.x * system.deltaTime
            
            if obj.objType == "heatseeker" then
                -- if frame rate drops, heatseeker can get "stuck" bouncing around player and never hit it!
                if obj.x < Player.xPos then
                    obj.x = Player.xPos
                    obj.speed = 0
                elseif obj.x > -Player.xPos then
                    obj.x = -Player.xPos
                    obj.speed = 0
                end
            end

            if not obj.dontCollide then
                -- super simplistic bounce function. We put the ball on the screen edge rather than moving exactly
                if not obj.dontBounce then
                    if obj.x > maxX then
                        obj.x = maxX
                        obj.vec.x = -obj.vec.x
                        -- bullets bounce once
                        if obj.objType == "bullet" then
                            obj.dontBounce = true
                            obj.strokeColor = {105,0,105}
                        end
                    end
                    if obj.x < minX then
                        obj.x = minX
                        obj.vec.x = -obj.vec.x
                        if obj.objType == "bullet" then
                            obj.dontBounce = true
                            obj.strokeColor = {105,0,105}
                        end
                    end
                    if obj.y > maxY then
                        obj.y = maxY
                        obj.vec.y = -obj.vec.y
                    end
                    if obj.y < minY then
                        obj.y = minY
                        obj.vec.y = -obj.vec.y
                    end
                end
                
                -- Collisions (cheap collisions, ignoring fact ball is rounded!)
                for pK,player in pairs(players) do
                    local playerCollideYTop = player.sled.y + player.collideY
                    local playerCollideYBot = player.sled.y - player.collideY

                    if ((player.collideX < 0 and obj.x < player.collideX) or (player.collideX > 0 and obj.x > player.collideX))
                            and obj.y < playerCollideYTop and obj.y > playerCollideYBot then

                        -- ShrinkDestroy etc will remove a collidable from the collidables table but leave nodes alive to animate out
                        if obj.objType == "bullet" then
                            player:TakeHit()
                            playerHit()
                            GrowDestroy(obj)
                        elseif obj.objType == "expander" then
                            player:Grow()
                            FadeDestroy(obj)
                        elseif obj.objType == "heatseeker" then
                            player:AnimateHit()
                            HeatseekerDestroy(obj)
                        else
                            if obj.objType == "powerup" then
                                player:AddAmmo(1)
                                ShrinkDestroy(obj)
                            elseif obj.objType == "health" then
                                player:AddHealth(1)
                                playerHit(true)
                                ShrinkDestroy(obj)
                            elseif obj.objType == "cloak" then
                                if not gameInfo.firstCloak then
                                    gameInfo.firstCloak = true
                                    ShowMessage("power surge!")
                                    sceneBattle:reshowScreenFx()
                                end
                                player:AddAmmo(1) -- cloak balls also provide powerups
                                player:Cloak()
                                ShrinkDestroy(obj)
                            elseif obj.objType == "ball" then
                                player:TakeHit()
                                playerHit()
                                GrowDestroy(obj)
                            end
                        end
                    end
                end
            end
            
            -- Destroy non-bouncing objects (bullets etc) once well off screen:
            -- Bullets and expanders are only objects that can go "behind" a player, for one frame
            -- We should count these as collisions as they
            -- likely "hit" the player (player may have slid in front of them after they passed,
            -- but player cant see this so who cares!)
            -- Therefore, we do this *after* checking for collision with player.
            -- obj.dying flag prevents killing a node twice (likley to crash eventually otherwise)
            if obj.dontBounce and not obj.dying then --check dontBounce to save testing every ball
                if obj.x < minX - 50 or obj.x > maxX + 50 then
                    -- +/- 50 is for heatseekers which can overshoot and come back
                    -- arbitrary but "big enough" number to catch them.
                    obj.dontCollide = true
                end
                if obj.x > self.screenMaxX+20 or obj.x < self.screenMinX-20 or obj.y > self.screenMaxY+20 or obj.y < self.screenMinY-50 then
                    CollidableDestroy(obj)
                end
            end
        end
    end

    -- allow both players to die in same loop for fairness
    if (player1.deadFlag or player2.deadFlag) and not self.deathPhase then
        self.deathPhase = true
        self:cancelTimers()
        if gameInfo.controlType == "onePlayer" and gameInfo.mode ~= "survival" then
            cancelTweensOnNode(sceneBattle.waveLeft.origin, true)
            tween:to(sceneBattle.waveLeft.origin, {time=2, xScale=0, yScale=0})
        end
    end

    if self.deathPhase then
        -- explode players
        for kP, player in pairs(players) do
            if player.deadFlag == 1 then
                player.deadFlag = 2
                player.moveWithFinger = false
                player.velocity = 0
                player:Explode() -- cancels all anims and timers, destroys player on completion
                if self.demoTimers then
                    if self.demoTimers[player.id] then
                        self.demoTimers[player.id]:cancel()
                        self.demoTimers[player.id] = nil
                    end
                end

                -- player who's not exploding has weapons meter flicker to show it doesnt work
                if player.weaponsMeter.weaponFxTimer then
                    player.weaponsMeter.weaponFxTimer:cancel()
                    player.weaponsMeter.origin.isVisible=true
                end
                
                tween:to(player.weaponsMeter.dashboardOrigin, {alpha=0, time=1})
                player.weaponsMeter.iconsOrigin.isVisible = false
                player.weaponsMeter.ammoCounter:SetValue(0)

                if not player.enemy.deadFlag then
                    player.enemy.weaponsMeter.weaponFxTimer = player.enemy.weaponsMeter.origin:addTimer(MeterInterference, 0.1, 0, 0)
                    player.enemy.weaponsMeter.weaponFxTimer.meter = player.enemy.weaponsMeter.origin
                end
                
                -- can call for both players - will just pleasantly stretch out deceleration a bit more
                endStarMovement(5)
            end

            -- flags increment once when all balls are gone and once player's explosion is over
            -- Opponent must survive until both these events happen!
            if not player.deadFlag and player.enemy.deadFlag == 4 then
                DisablePauseMenu()
                self:removeSceneMoveButton()
                if gameInfo.controlType == "onePlayer" then
                    player.health:SetValue(0)
                else
                    local message = director:createLabel({x=0, y=0, hAlignment="centre", vAlignment="centre", text="PLAYER " .. player.id .. " WINS", color=gameInfo.playerColours[player.id], font=fontMainLarge})
                    origin:addChild(message)
                    
                    --timer used for testing only
                    if player.weaponsMeter.weaponFxTimer then
                        player.weaponsMeter.weaponFxTimer:cancel()
                        player.weaponsMeter.origin.isVisible=true
                    end
                    
                    self:beginGameOver(2.5)

                    player.deadFlag = 5
                end
            end
        end

        if player1.deadFlag == 4 and player2.deadFlag == 4 then
            local message
            if gameInfo.controlType == "onePlayer" then
                message = director:createLabel({x=0, y=0, hAlignment="centre", vAlignment="centre", text="GAME OVER", color=menuBlue, font=fontMainLarge})
                gameInfo.score = self.score.value
                analytics:logEvent("1pGameOver", {score=tostring(self.score.value), mode=gameInfo.mode})
                menuCheckNewHighScoreAndSave() --causes next menu scene to jump to name input if new high score
                
                
                -- show interstitial or banner add (defined earlier) on game over without new high score
                -- interstitial ought to display over the top of the transition.
                -- TODO: planning to do own slide out animation for this scene before transition, so
                -- make sure banner is shown between custom and transition animations then.
                if not gameInfo.newHighScore and useAdverts then
                    ShowGameOverAd()
                end
            else
                message = director:createLabel({x=0, y=0, hAlignment="centre", vAlignment="centre", text="BATTLE DRAWN", color=menuBlue, font=fontMainLarge})
            end
            origin:addChild(message)
            self:beginGameOver(2.5)
            DisablePauseMenu()
            self:removeSceneMoveButton()
            player1.deadFlag = 5
            player2.deadFlag = 5
        end
    end
    
    fullscreenEffectsUpdate(self)
end

function sceneBattle:beginGameOver(duration)
    self.endTimer = system:addTimer(GameOver, duration, 1)
    cancelTweensOnNode(self.screenFx)
    if self.screenFx then
        tween:to(self.screenFx, {alpha=0, time=duration*0.7})
    end
end

function playerHit(restoreHealth)
    if gameInfo.controlType == "onePlayer" then
        if not restoreHealth then
            --streak/combo resets on player hit
            if gameInfo.streak > gameInfo.streakMax then
                gameInfo.streakMax = gameInfo.streak
            end
            if gameInfo.streak > gameInfo.streakMax or gameInfo.streak > 2 then
                ShowMessage(gameInfo.streak .. " bomb streak", 0, false, "up", nil, 0, minY+20, color.red)
                sceneBattle:reshowScreenFx()
            end
            gameInfo.streak = 0
        end
    end
    if gameInfo.controlType == "p1LocalVsP2Local" or gameInfo.mode == "survival" then
        --re-using logic from one player game. Instead of speed based on waves
        -- multiple of 2 -> 6 = slow->fast; we use health left of >=5 -> 1 = slow->fast
        local speedMultiple = math.max(1, math.min(6, 6-math.min(player1.health.value, player2.health.value)))
        if (speedMultiple ~= sceneBattle.previousStarSpeedMultiple) and speedMultiple > 0 and speedMultiple < 6 then
            setStarAnimation(speedMultiple, (speedMultiple-1)*2, sceneBattle.previousStarSpeedMultiple > speedMultiple)
        end
    end
end

--function keyInput(event)
--end
--system:addEventListener('key', keyInput)

function touchReleaseTimer(event)
    event.timer.touch.touchWasTap = false --timer expired -> dont cause fire events; allow movement
    event.timer.touch.tapTimer = nil
    event.timer.player.velocity = 0 --touch didnt cause fire or movement -> stop movement
end

function sceneBattle:touch(touch)
    if sceneBattle.endTimer then
        return
    end
    
    --reject event when > 1 occurs per frame, for performance
    if touch.phase == "moved" and self.lastFrameTime[touch.id] == system.gameTime then
        return
    end
    
    self.lastFrameTime[touch.id] = system.gameTime

    -- TODO: - Add keyboard controls for desktop (and phones or tablets with physical keys)
    --         also support bluetooth keyboard!
    --       - Add optional gestures for weapons - wont actually make it easier but is fun! 

    -- Touch coords are 0,0 bottom left and always in window/world coords
    -- Convert from window-space to user-space/virtual resolution coords and
    -- subtract half screen width since our origin is in the center
    -- Use local vars instead of modifying touch.x/y (Quick re-uses event objects for began->moved->ended)
    local touchX = virtualResolution:getUserX(touch.x) - maxX
    local touchY = virtualResolution:getUserX(touch.y) - maxY
    -- TODO: should be able to just use following but not working:
    --local touchX, touchY = getLocalCoords(touch.x, touch.y, origin)
    
    --print(touch.x .. "," .. touch.y)

    --[[ We loop through players, identify which player touch is for and identify touch type based on how finger moves
      - We allow 2 fingers per player, but control scheme allows you to play one fingered if needed
      - Only apply movement etc once touch type is determined
      - Dont allow 2 fingers to both move the sled (would be confusing), but do allow 2 fingers to both fire or change weapon
      - If finger just changed weapon, it can switch to movement (eg swipe right, then up) but not vice-versa
      - That's because movement doesnt use ammo and allows player to get to safety - i.e. we play it safe!
      - which player a touch is for is determined by which half of screen the touch *starts* in.
      - after touch starts, the area of screen is irrelevant (avoid p1 vs p2 switching mid-gesture!)
    ]]--

    local touchZone
    if player1.touchZone == 3 then
        touchZone = 3 -- 3 and 4 indicate left and right both for one local player object
    elseif player2.touchZone == 4 then
        touchZone = 4
    elseif touchX < 0 then
        touchZone = 1 --left side for player 1
    else
        touchZone = 2 --right side for player 2 (or p1 in one player mode)
    end
    --dbg.print("------------------------------------------")
    --dbg.print("NEW TOUCH EVENT")
    --dbg.print("touch zone: " .. touchZone)
    --dbg.print ("touchX: "..touchX)

    for k,player in pairs(players) do
        if not player.deadFlag and not (k==2 and touchZone > 2) then
            -- no controls if dead, all touches will then get cancelled on player destruction
            -- ignore player 2 if only 1 local player

            --dbg.print("player number: " .. k)
            if touch.phase == "began" then
                --dbg.print("touch began, id=" .. touch.id)
                 if player.touchZone == touchZone then --touch is for this player
                    --dbg.print("in touch zone for player " .. k)

                     if player.touchCount < 2 then -- ignore > 2 fingers per player
                         player.touchCount = player.touchCount + 1

                         player.touches[touch.id] = {}
                         player.touches[touch.id].x = touchX
                         player.touches[touch.id].y = touchY

                         -- allowed to swipe horizontally until vertical movement starts
                         -- dont mind both fingers swiping at once - just change weapon twice!
                         player.touches[touch.id].canSwipeLR = true

                         -- player-finger offset as we move directly with finger while held down
                         player.touches[touch.id].touchPosDiff = touchY - player.sled.y

                         -- reversed movement control (based on point where touch starts from when timer is in effect)
                         -- always set because any touch could become movement and reverse could start afterwards
                         player.reversePos = touchY

                         player.touches[touch.id].touchWasTap = true -- flag will be turned off once finger moves
                        
                         player.touches[touch.id].tapTimer = system:addTimer(touchReleaseTimer, 0.3, 1) -- or on timeout
                        
                         if player.touches[touch.id].tapTimer then
                             player.touches[touch.id].tapTimer.touch = player.touches[touch.id]
                             player.touches[touch.id].tapTimer.player = player
                         end
                        
                         player.touches[touch.id].weaponMoveGate = 0
                    end
                --else
                --    dbg.print("touch ignored! not in touch zone")
                end
            else
                -- which player move/end is for is determined by ID set above
                for kID, pTouch in pairs(player.touches) do
                    --dbg.print("testing non-began touch event for player " .. k)

                    if kID == touch.id then -- 3rd,4th,etc finger -> wont have made it into player.touches table, so automatically ignored
                        -- Quick has a quirk that it records touch events as the pointer moves outside of the
                        -- window (desktop only) by returning x=0, y=window height. It fires a "moved" and then
                        -- an "ended" event as soon as the pointer leaves. We ignore by setting to last value.
                        if touch.x == 0 and touch.y == director.displayHeight then
                            touchX = pTouch.x
                            touchY = pTouch.y
                        end

                        if touch.phase == "ended" then
                            --dbg.print("touch " .. kID .. "ended")
                            player.touchCount = player.touchCount - 1

                            if player.moveWithFinger == touch.id then -- stop this finger from controlling movement
                                player.moveWithFinger = nil
                                -- player continues moving via velocity (will decelerate)
                                -- useful to flick out of way, and for one handed play as can tap to fire
                                -- while still moving
                                -- "ended" and "moved" events happen in same frame, so cant just calc yDiff
                                -- here as it would be zero
                                -- yDiff is already scaled from world to user coords
                                -- NB: using yDiffPrev (from one before last update) because on android the last
                                -- touch event tends to return weird values, e.g. really short or even negative ones.
                                -- seems like a quirk of the native API/screen. TODO: Better solution would be to average
                                -- velocity over a few frames.
                                player.velocity = pTouch.yDiffPrev / system.deltaTime
                                if player.reverseTimer then player.velocity = -player.velocity end
                            end
                            
                            -- fire on release without noticeable movement. No weapons when opponent is dying.
                            if pTouch.touchWasTap then
                                if player.touches[kID].tapTimer then --safety check
                                    player.touches[kID].tapTimer:cancel()
                                    player.touches[kID].tapTimer = nil
                                end
                                if not player.enemy.deadFlag then
                                    player:Fire()
                                end
                            end
                            player.touches[kID] = nil
                        end

                        if touch.phase == "moved" then
                            --dbg.print("touch " .. touch.id .. " moved to " .. touchX .. "," .. touchY)
                            local xDiff = touchX - pTouch.x
                            local yDiff = touchY - pTouch.y

                            -- we check distance moved *per second* is > gating values to decided which
                            -- action to do (move/changeweapon/fire)
                            yDiffAbs = yDiff / system.deltaTime
                            if yDiffAbs < 0 then
                                yDiffAbs = 0 - yDiffAbs
                            end
                            
                            xDiffAbs = xDiff
                            if xDiffAbs < 0 then
                                xDiffAbs = 0 - xDiffAbs
                            end
                            xDiffAbsSpeed = xDiffAbs / system.deltaTime
                            
                            --print("MOVE ABS: " .. xDiffAbs .. ", " .. yDiffAbs)

                            --ignore very small movements (so we will get "tap" events to fire weapon)
                            if pTouch.touchWasTap then
                                if yDiffAbs > MIN_TOUCH_MOVE_Y or xDiffAbsSpeed > MIN_TOUCH_MOVE_X then
                                    pTouch.touchWasTap = false
                                    if player.touches[kID].tapTimer then -- otherwise velocity still gets killed by move
                                        player.touches[kID].tapTimer:cancel()
                                        player.touches[kID].tapTimer = nil
                                    end
                                end
                            end
                            if not pTouch.touchWasTap then
                                -- horizontal swipe if horiz > half vertical, or if horiz > min and other finger is
                                -- already doing movement. No weapons when other player is dying
                                if not player.enemy.deadFlag and pTouch.canSwipeLR and xDiffAbsSpeed > 
                                        WEAPON_MOVE_AMOUNT_X and (xDiffAbsSpeed*3 > yDiffAbs 
                                        or (player.moveWithFinger ~= nil
                                        and player.moveWithFinger ~= touch.id)) then
                                    
                                    if xDiffAbs > pTouch.weaponMoveGate then --first touch always moves
                                        if player.weaponsMeter:ChangeWeapon(xDiff) then --mac one per frame
                                            pTouch.changedWeapon = true
                                            if xDiff > 0 then
                                                -- limit recorded pos if > WEAPON_MOVE_AMOUNT_X, so we keep changing on
                                                -- next touch event. Means weapons always cycle smoothly.
                                                pTouch.x = pTouch.x + math.min(xDiff, WEAPON_MOVE_AMOUNT_X)
                                            else
                                                pTouch.x = pTouch.x + math.max(xDiff, -WEAPON_MOVE_AMOUNT_X)
                                            end
                                        end
                                    end
                                    pTouch.weaponMoveGate = WEAPON_MOVE_AMOUNT_X

                                    --pTouch.canSwipeLR = false --if want to only allow one swipe per touch
                                elseif player.moveWithFinger == nil and ((pTouch.changedWeapon and yDiffAbs > MIN_TOUCH_MOVE_X) or (not pTouch.changedWeapon and yDiffAbs > MIN_TOUCH_MOVE_Y)) then
                                    -- on vertical movement, start moving exactly with finger
                                    -- changeWeapon flag gives weapon changing equal priority once a succesfull change occurs (for better 1-finger control)
                                    -- only one finger can do movement, determined by player's global flag

                                    player.moveWithFinger = touch.id -- this finger is now the only move finger
                                    pTouch.canSwipeLR = false -- and it can't change weapon anymore
                                end
                                if player.moveWithFinger == touch.id then
                                    pTouch.y = touchY -- will position player based on pTouch.y
                                    pTouch.yDiffPrev = pTouch.yDiff or yDiff
                                    pTouch.yDiff = yDiff
                                    -- using yDiffPrev for velocity as Android often returns weird values just before finger is lifted!
                                    -- TODO: This may be performance related. Ideally dont want to do this on iOS/fast devices because
                                    -- It does mean you get slightly unnatural deceleration.
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function randomPlayerTimer(event)
    local actions = {"fire", "fire", "weapon-next", "weapon-next", "weapon-switchdir", "move-switchdir", "move-switchdir", "move-switchdir"}
    local actionId = math.random(1,16)
    local action = actions[actionId] or "move"
    
    local player = event.timer.player
    if not player.demoDir then
        player.demoDir = math.random(0,1)
        if player.demoDir == 0 then
            player.demoDir = -1
        end
        player.demoDirWeapon = math.random(0,1)
        if player.demoDirWeapon == 0 then
            player.demoDirWeapon = -1
        end
    end
    
    if action == "move" or action == "move-switchdir" then
        if action == "move-switchdir" then
            player.demoDir = -player.demoDir
        end
        player.velocity = player.velocity + player.demoDir*50
        if player.velocity > 0 then
            player.velocity = math.min(200, player.velocity)
        elseif player.velocity < 0 then
            player.velocity = math.max(-200, player.velocity)
        end
    elseif action == "weapon-next" or action == "weapon-switchdir" then
        if action == "weapon-switchdir" then
            player.demoDirWeapon = -player.demoDirWeapon
        end
        player.weaponsMeter:ChangeWeapon(player.demoDirWeapon) 
    elseif action == "fire" then
        player:Fire()
    end
    
    if not debugGoSlow then
        sceneBattle.demoTimers[player.id] = system:addTimer(randomPlayerTimer, 1/actionId, 1)
    else
        sceneBattle.demoTimers[player.id] = system:addTimer(randomPlayerTimer, 4, 1)
    end
    sceneBattle.demoTimers[player.id].player = player
end

function cancelBattle(event)
    if event.phase == "ended" then -- guard or else will try to transition twice!
        sceneBattle.ignoreEvents = true -- stop balls regenerating etc
        --sceneMainMenu:wipeContinueFile()
        sceneBattle:goToMenu()
        --objects will all be destroyed in post transition event
    end
end

--[[-- TODO: use this if supporting battles with multiple rounds
function RoundOver(event)
    
    -- need to "reset" player objects and start again without changing scene...
end]]--

function GameOver(event)
    sceneBattle.endTimer = nil
    sceneMainMenu:wipeContinueFile()
    sceneBattle:goToMenu()
    -- all effects must have finished by this point :)
end

function sceneBattle:goToMenu()
    if gameInfo.controlType ~= "p1LocalVsP2Local" or demoMode then --already locked in battle mode
        -- Lock rotation during transition or else values are broken next scene start.
        -- Prob should fix this in SDK...
        if screenWidth > screenHeight then
            device:setOrientation("landscape") --screen can still flip safely, only dimensions are an issue
        elseif screenWidth < screenHeight then
            device:setOrientation("portrait")
        end -- square screen (unlikely but exists!) doesnt need any locking
    end
    
    director:moveToScene(sceneMainMenu, {transitionType="slideInB", transitionTime=1.5})
end

function ShowGameOverAd(event)
    -- show interstitial or banner add (defined earlier) on game over without new high score
    ads:newAd(director.displayHeight, 100, useAdverts, advertType, advertId)
    ads:show(true)
end

function AddStar(twinkleAnimate, n)
    local x = math.random(minX, maxX)
    local y = math.random(minY, maxY)
    
    local normVector = {}
    local length = math.sqrt(x*x+y*y)
    normVector.x = x/length
    normVector.y = y/length

    local star = director:createLines({x=x, y=y, coords={0,0, 1,0.5}, strokeWidth = 1})
    --local star = director:createCircle({x=x, y=y, xAnchor=0.5, yAnchor=0.5, radius=1})
    star.normVector = normVector
    
    -- rotation allows xScale to be used to strewtch star out into a line for high speeds
    -- vectors are actually polygons, so cant just scale in x and y as would creae big squares!
    star.rotation = math.deg(math.atan2(star.normVector.x, star.normVector.y))+90
    
    -- set star colour: get a random white value then allow some variance in each channel for off-white result
    local brightness = math.random(40, 180)
    -- NB: if we assigned value to star.strokeColor first and then do star.originalStroke=star.strokeColor
    -- it actually becomes a 'userdata' type due to Quick C++ internals and then we cant use it in tweens
    star.originalStroke = {r=math.random(brightness-40, brightness), g=math.random(brightness-40, brightness), b=math.random(brightness-40, brightness)}
    star.strokeColor = star.originalStroke
    
    if twinkleAnimate and performanceLevel > 1 then
        tween:to(star, {strokeAlpha=0.3, mode="mirror", time=0.5+n*0.05, delay=n*0.05})
    else
        tween:to(star, {strokeAlpha=math.random(3,10) / 10, time=0.5}) -- avoid tweens running during play
    end

    sceneBattle.background:addChild(star) -- background.children is now a table with refs to all stars
end

function StretchStar(star, length)
    -- Sadly cant just do xScale and yScale as vectors have thickness (they are made with polygons!)
    -- Also can change coords after creating them so have to re-create..
    
    local newStar = director:createLines({x=star.x, y=star.y, coords={0,0, star.normVector.x*length,star.normVector.y*length}, strokeWidth = 1})
    newStar.normVector = star.normVector
    newStar.originalStroke = star.originalStroke
    destroyNode(star)
end

-- Save retrievable game state data. Can recreate game state form this if
-- game gets killed by OS or user in mid play.
function sceneBattle:saveState()
    local continueData = {}
    
    if not player1.deadFlag and not player2.deadFlag then
        continueData.controlType = gameInfo.controlType    
        continueData.mode = gameInfo.mode
        continueData.score = self.score.value
        continueData.wave = gameInfo.wave --can be nil
        continueData.powerupLevel = gameInfo.powerupLevel
        continueData.streak = gameInfo.streak
        continueData.streakMax = gameInfo.streakMax
        continueData.firstCloak = gameInfo.firstCloak

        if self.waveLeft then
            continueData.waveLeft = self.waveLeft.value
        end
        
        continueData.ballCreateQueue = self.ballCreateQueue
        continueData.ballsAddedThisWave = self.ballsAddedThisWave
        continueData.ballSpeed = self.ballSpeed
        
        if self.ballTimer then
            continueData.ballDelay = self.ballTimer.ballDelay
        end
        
        continueData.saveObj = {}
        
        for k,obj in pairs(collidables) do
            local saveInfo = {}
            saveInfo.objType = obj.objType
            saveInfo.vec = obj.vec
            saveInfo.speed = obj.speed
            saveInfo.x = obj.x
            saveInfo.y = obj.y
            saveInfo.replaceOnLeaveScreen = obj.replaceOnLeaveScreen
            if obj.enemy then
                saveInfo.enemyId = obj.enemy.id
            end
            continueData.saveObj[obj.name] = saveInfo
        end
        
        continueData.players = {}
        
        for k,p in ipairs(players) do
            local player = {}
            player.id = p.id
            player.velocity = p.velocity
            player.halfHeight = p.newHalfHeight
            player.y = p.sled.y            
            player.health = p.health.value
            
            --TODO These need to be values which are used to set the timers again
            -- e.g. reverseTimer = p.reverseTimer.timeLeft or whatever
            --player.reverseTimer = p.reverseTimer
            --player.cloakTimer = p.cloakTimer
            
            player.ammo = {}
            player.ammo.bullet = p.weaponsMeter.ammo.bullet
            player.ammo.ball = p.weaponsMeter.ammo.ball
            player.ammo.air = p.weaponsMeter.ammo.air
            player.ammo.expander = p.weaponsMeter.ammo.expander
            player.ammo.freezer = p.weaponsMeter.ammo.freezer
            player.ammo.heatseeker = p.weaponsMeter.ammo.heatseeker
            player.ammo.reverser = p.weaponsMeter.ammo.reverser 
            
            player.currentWeaponID =  p.weaponsMeter.currentWeaponID
            --FYI for restoring: player.currentWeapon = weapons[player.currentWeaponID]
            
            table.insert(continueData.players, player)
        end
        
        continueData.canContinue = true -- last flag set for safety check plus allowing use of empty table
        
        dbg.printTable(continueData)
    else
        dbg.print("wiping save state file as player(s) is/are dead")
    end
    
    local success, jsonData = pcall(json.encode, continueData) --"exception" handling
    if success then
        local saveStatePath = system:getFilePath("storage", "continue.txt")
        local file = io.open(saveStatePath, "w")
        if not file then
            dbg.print("failed to open continue data file for saving: " .. saveStatePath)
        else
            file:write(jsonData)
            file:close()
            dbg.print("game state saved for resuming")
        end
    else
        dbg.print("encode JSON save data failed: " .. jsonData) --jsonData is error info
    end
end

function sceneBattle:fullscreenEffect()
    if not gameInfo.useFullscreenEffects then
        return
    end
    
    dbg.print("setting up fullscreen render texture effect")
    self.rt = director:createRenderTexture(director.displayWidth, director.displayHeight, pixel_format.RGBA8888)
        
    self.rt.x = virtualResolution.userWinMinX + screenWidth/2
    self.rt.y = virtualResolution.userWinMinY + screenHeight/2
    self.rt.isVisible = false

    -- Bug: sprite from getSprite will be inverted un-transformed version of the rendertexture for first frame
    -- Workaround: render nothing for first frame
    self.rtWorkaround = 1
    self.rt:clear(clearCol)
    -- Workaround end --
    
    -- Only create sprite for rendering once. It has a clone of the renderTexture's texture
    -- so gets updated with each frame
    self.screenFx = self.rt:getSprite()
    self.screenFx.zOrder = -1

    -- have to scale to match VR
    self.screenFx.xScale = 1/virtualResolution.scale
    self.screenFx.x = virtualResolution.userWinMinX -- - screenWidth/2 -- 0,0 is centre screen!
    self.screenFx.yScale = -1/virtualResolution.scale
    self.screenFx.y = screenHeight + virtualResolution.userWinMinY --  - screenWidth/2
        --screenHeight is workaround for bug in renderTexture!
    
    self.screenFx.alpha=0.7
    
    if self.gamePaused then
        self:startPauseEffects()
    else
        self:reshowScreenFx()
    end
end

function sceneBattle.moveSceneTopOrMiddle(event)
    if not event or event.phase == "ended" then
        local newBtn, oldBtn
        
        if event then
            if gameInfo.portraitTopAlign then
                gameInfo.portraitTopAlign = false
                oldBtn = "down"
            else
                gameInfo.portraitTopAlign = true
                oldBtn = "up"
            end
            
            removeArrowButton(sceneBattle, oldBtn, sceneBattle.moveSceneTopOrMiddle)
            sceneBattle.moveBtn = nil
        end
            -- if not event, then calling from setup -> use current value and just add first button
        
        if gameInfo.portraitTopAlign then
            newBtn = "down"
        else
            newBtn = "up"
        end
        
        sceneBattle.moveBtn = addArrowButton(sceneBattle, newBtn, sceneBattle.moveSceneTopOrMiddle,
            nil, nil, sceneBattle.screenMinY*0.3, 0.35)
        sceneBattle.moveBtn.xScale = 0.5
        sceneBattle.moveBtn.yScale = 0.5
        sceneBattle.moveBtn.zOrder = 100
        
        -- move origins, pause overlay mask and moveBtn
        -- only restart screen effect if button was pressed (not on first setup)
        sceneBattle:orientation(nil, not event)
        
    end
    return true
end

function sceneBattle:orientation(event, dontRestartEffects)
    adaptToOrientation(event)
    
    -- User space coords for screen edges inc letterboxes
    -- Game uses 0,0 is centre point (via origin node)
    self.screenMaxX = screenWidth/2
    self.screenMinX = -self.screenMaxX
    self.screenMaxY = screenHeight/2
    self.screenMinY = -self.screenMaxY
    
    local lockPlayAreaCentred = screenWidth >= screenHeight or (screenHeight - appHeight) / 2 < 100
    
    -- origins move to match positioning, pause mask is only thing that needs to match screen size
    local offset, maskOffset
    if screenHeight / appHeight > 2 then
        offset = screenHeight/2 - (screenHeight/2 - appHeight)*0.7
        maskOffset = (screenHeight-appHeight) / 2 - (screenHeight/2 - appHeight) * 0.7
    else
        offset = screenHeight/2
        maskOffset = (screenHeight-appHeight) / 2
    end
    
    if not demoMode and (not lockPlayAreaCentred and gameInfo.portraitTopAlign) then
        if origin then
            origin.y = offset
        end
        if self.originPause then
            self.originPause.y = offset
            self.originMaskAnchor.y = offset
        end
    else
        if origin then
            origin.y = appHeight/2
        end
        if self.originPause then
            self.originPause.y = appHeight/2
            self.originMaskAnchor.y = appHeight/2
        end
    end
    
    if self.originMask then
        self.originMask.x = self.screenMinX
        self.originMask.w = screenWidth
        self.originMask.h = screenHeight
        
        if not demoMode and not lockPlayAreaCentred and gameInfo.portraitTopAlign then
            self.originMask.y = self.screenMinY - maskOffset
        else
            self.originMask.y = self.screenMinY
        end
    end
    
    if self.moveBtn then
        if lockPlayAreaCentred then
            self.moveBtn.isVisible = false
        else
            self.moveBtn.isVisible = true
            self.moveBtn.y = math.max(virtualResolution.userWinMinY*0.4, virtualResolution.userWinMinY+60)
        end
    end
    
    self:scalePauseBtns()

    -- (re)setup screen burn filter effect...
    if not dontRestartEffects then
        fullscreenEffectsReset(self)
        sceneBattle:fullscreenEffect()
        self.effectSkipFlag = true -- will go false on first update event and set effect, then alternate
    end
end

function sceneBattle:setUp(event)
    dbg.print("sceneBattle:setUp")
        
    self.lastFrameTime = {}
    for i=1,10 do
        self.lastFrameTime[i] = system.gameTime
    end
    
    -- onePlayerMode mode: p1 controls both sleds and score records survival time in amount of balls added
    local onePlayerMode = gameInfo.controlType == "onePlayer"
    
    system:addEventListener({"suspend", "resume", "orientation"}, sceneBattle)
    
    virtualResolution:applyToScene(self)
    self:orientation()
    self.rtDontClear = true
    
    -- root object at screen centre. Adding children to it means their coords will be
    -- relative to this position. Annoyingly Quick provides no way to set the origin; instead,
    -- parent's origins are automatically set to their lowest x&y coords.
    -- To hide it we've just made it match the black background (changing visibility or zOrder would be inherited by children!)
    --origin = director:createRectangle({x=appWidth/2, y=appHeight/2, xAnchor=0, yAnchor=0, w=3, h=3, strokeWidth=0, alpha=0})
    origin = director:createNode({x=appWidth/2, y=appHeight/2, zOrder=0})
    
    -- we dont have any nodes that need to be touched so for performance prevent whole scene tree ever
    -- being hit tested. Pause menu has its own originPause
    origin.isTouchable = false
    
    self.background = director:createRectangle({
        x=0, y=0,
        xAnchor=0, yAnchor=0,
        w=appWidth, h=appHeight,
        strokeWidth=0,  --strokeColor=color.green, strokeAlpha=1.0,
        color=color.black, alpha=0, zOrder=-10})
    origin:addChild(self.background)

    -- create random stars on background
    math.randomseed(os.time())
    local starCount = 20
    if performanceLevel > 1 then starCount = 100 end
    for n=1, starCount do
        AddStar((performanceLevel > 1), n)
    end
    
    self.starsMove = false
    self.starsDecelerate = false
    self.starSpeed = 0
    
    -- table to keep references to nodes that have been created, have no parent and are waiting to be reused
    self.recycler = {ball={},fx={}}
    -- manually count add/remove of reference to avoid getn
    self.recyclerCount = {ball=0,fx=0}
    
    self.unFreezeTimer = nil
    self.frameCounter = 0
    self.spriteFxTimer = {}
    
    local health, health2
    local ammo = {}
    local ammo2 = {}
    local wavePosInSet
    
    gameInfo.playerColours[1] = {50,255,50}
    if onePlayerMode then
        gameInfo.playerColours[2] = {50,255,50}
        self.score = Counter.Create(0, gameInfo.continue.score or 0, 9999, false, 1, true)
        self.score.origin:translate(0, maxY-38)
        health = DEFAULT_HEALTH_SURVIVAL
        
        if gameInfo.mode == "survival" then -- survival mode
            gameInfo.powerupLevel = 8 --allow all weapons from start
            ammoDefault = DEFAULT_AMMO_SURVIVAL
            gameInfo.wave = nil
            gameInfo.firstCloak = gameInfo.continue.firstCloak or true --flag so only first cloak powerup will show message
            setStarAnimation(1) -- static is boring!
        else
            self.waveLeft = Counter.Create(0, gameInfo.continue.waveLeft or INIT_WAVE_SIZE, 9999, false, nil, true)
            self.waveLeft.origin:translate(0, minY+38)
            gameInfo.powerupLevel = gameInfo.continue.powerupLevel or 0
            ammoDefault = DEFAULT_AMMO_WAVES
            gameInfo.wave = gameInfo.continue.wave or INITIAL_WAVE
            wavePosInSet = gameInfo.wave % 6
            gameInfo.firstCloak = nil --never show message
            if gameInfo.wave > 1 then
                setBgAnimations(wavePosInSet)
            end
        end

        gameInfo.streak = gameInfo.continue.streak or 0
        gameInfo.streakMax = gameInfo.continue.streakMax or 0
        --TODO: currently will mix in some wave 1 logic with whatever the INITIAL_WAVE wave is.
        --      Should move all the wave logic out to a standalone funciton used both here and in the next wave event.
    else
        gameInfo.wave = nil
        gameInfo.playerColours[2] = {255,50,50}
        health = DEFAULT_HEALTH_BATTLE
        ammo = {bullets = DEFAULT_BULLETS_BATTLE}
        
        if demoMode then
            ammoDefault = DEFAULT_AMMO_BATTLE_DEMO --less dull!
        else
            ammoDefault = DEFAULT_AMMO_BATTLE
        end
        
        setStarAnimation(1)
    end
    
    health2 = health
    
    if gameInfo.continue.players then
        health = gameInfo.continue.players[1].health
        ammo = gameInfo.continue.players[1].ammo
        health2 = gameInfo.continue.players[2].health
        ammo2 = gameInfo.continue.players[2].ammo
    end

    player1 = Player.Create(1, health, ammo, ammoDefault, onePlayerMode)
    player2 = Player.Create(2, health2, ammo2, ammoDefault, onePlayerMode)
    player1.enemy = player2
    player2.enemy = player1
    
    players = {}
    table.insert(players, player1)
    table.insert(players, player2)
    
    if gameInfo.continue.players then
        for k,saveInfo in ipairs(gameInfo.continue.players) do
            players[k].weaponsMeter:SetWeapon(saveInfo.currentWeaponID)
            players[k].sled.y = saveInfo.y
            players[k].velocity = saveInfo.velocity
            players[k].halfHeight = saveInfo.halfHeight
            players[k].newHalfHeight = saveInfo.halfHeight
            --These need to be values which are used to set the timers again
            --players[k].reverseTimer = saveInfo.reverseTimer
            --players[k].cloakTimer = saveInfo.cloakTimer
        end
    end
    
    sceneBattle.deathPhase = false
    sceneBattle.ignoreEvents = false

    self.ballSpeed = gameInfo.continue.ballSpeed or SECOND_BALL_SPEED --(pixels/second)
    self.ballCreateQueue = gameInfo.continue.ballCreateQueue or 0 -- queues up balls to add to replace destroyed ones
    self.ballsAddedThisWave = gameInfo.continue.ballsAddedThisWave or 0

    self.ballOverrides={}
    
    if gameInfo.controlType == "onePlayer" and gameInfo.mode == "waves" then
        self:setBallOverrides(gameInfo.wave, wavePosInSet)
    else
        for n=1, INITIAL_BALL_QUEUE do
            self.ballOverrides[n] = {}
             -- lock first three to balls with fairly horizontal angles
            local randAngle = math.random(0, 359)
            if randAngle < 45 or (randAngle > 135 and randAngle < 225) then
                randAngle = randAngle + 90
            elseif randAngle > 315 then
                randAngle = randAngle - 270
            end
            self.ballOverrides[n]["angle"] = randAngle
            self.ballOverrides[n]["speed"] = FIRST_BALL_SPEED/n
        end
    end
    
    if not (demoMode and not demoModeDebug) and (gameInfo.controlType == "p1LocalVsP2Local" or gameInfo.controlType == "onePlayer") then
        --one uses left, one usese right side of screen
        player1.touchZone = 1
        player2.touchZone = 2
    elseif gameInfo.controlType == "p1LocalVsP2Remote" or gameInfo.controlType == "p1VsAI" then
        player1.touchZone = 3
    elseif gameInfo.controlType == "p1RemoteVsP2Local" then
        player1.touchZone = 4
    end
    
    -- we manage ball movement ourselves. physics/box2d doesn't appear to be well suited to
    -- simple top-down type movement so we just move balls per-frame and do collisions manually.
    collidables = {}
    deadCollidables = {} --table to hold objects kept active while they animate death
    
    -- re-set position/scaling for any new things added since start of function (like the origin itself!)
    self:orientation()
end

--set params for certain balls in the wave. index 1 = first ball added, 6=6th ball, etc
function sceneBattle:setBallOverrides(wave, wavePosInSet)
    -- these keep the first round especially from being too dull!
    self.ballOverrides[1]={angle=95, objType="ball", speed=FIRST_BALL_SPEED}
    self.ballOverrides[2]={angle=275, objType="ball", speed=FIRST_BALL_SPEED}
    self.ballOverrides[3]={objType="ball", speed=FIRST_BALL_SPEED}
    self.ballOverrides[4]={objType="ball", speed=FIRST_BALL_SPEED}
    
    for i = 5,7 do
        self.ballOverrides[i] = {}
    end
    
    if wave == 1 then
         -- run flashiest powerup early on to peek user interest
        self.ballOverrides[6]={objType="heatseeker", speed=FIRST_BALL_SPEED/2}
    elseif wave == 2 then
        self.ballOverrides[3]["objType"]="health" -- guarantee introduce powerups
        self.ballOverrides[4]["objType"]="powerup"
    elseif wave == 3 then
        self.ballOverrides[5]["objType"]="cloak" -- new powerup
    elseif wave == 4 or wave == 6 then
        for i = 1,6 do
            self.ballOverrides[i]["objType"]="bullet"
        end
        if wave == 6 then
            self.ballOverrides[7]["objType"]="freezer"
        end
    elseif wave == 5 or wave == 7 then
        for i = 1,7 do
            self.ballOverrides[i]["objType"]=nil --keep init ball speeds but rest is random
        end
    end
    
    if wave > 1 and wavePosInSet == 1 then --7,13,19, etc
        -- waves afer star speed resets - give player help since they survived!
        self.ballOverrides[1]["objType"]="health"
        self.ballOverrides[2]["objType"]="powerup"
    end
end

function ScoreHelperLabels(event)
    tween:to(event.target, {alpha=1, time=1.5, onComplete=LabelHelperDestroy})
    
    if sceneBattle.waveLeft then
        local waveHelper = director:createLabel({x=30, y=minY+22, hAlignment="left", vAlignment="center", text="bombs left this wave", w=80, color=menuBlue, font=fontMainSmall, alpha=0})
        origin:addChild(waveHelper)
        tween:to(waveHelper, {alpha=1, time=1, delay=2, onComplete=LabelHelperDestroy})
    end
end

function LabelHelperDestroy(target)
    tween:to(target, {alpha=0, time=2.5, onComplete=destroyNode})
end

function sceneBattle:enterPostTransition(event)
    dbg.print("sceneBattle:enterPostTransition")
    -- start game running after transitions
    
    --diable screen lock for non-battle games once the transition is over
    if gameInfo.controlType ~= "p1LocalVsP2Local" or demoMode then
        device:setOrientation("free")
        self:orientation(true) -- also re-check orientation for dekstop or anything else where locking isn't supported
    end
    
    -- wait till now so isnt wiped instantly by pre scenes hide call!
    if showFrameRate then
        dbg.print("showframe rate!")
        frameRateOverlay.showFrameRate({x = virtualResolution.userWinMinX+5, y = virtualResolution.userWinMinY+5, zOrder = 100, width = 100}) --debugging
    end

    -- show and animate counters appearing
    player1.health:UpdateDisplay()
    player2.health:UpdateDisplay()
    player1.weaponsMeter:UpdateDisplay()
    player2.weaponsMeter:UpdateDisplay()
    if self.score then self.score:UpdateDisplay() end
    if self.waveLeft then self.waveLeft:UpdateDisplay() end

    if gameInfo.controlType == "p1VsAI" then
        player2.AITimer = player2.sled:addTimer(AIFire, 2.0, 0, 0.5)
    end

    -- main game logic handlers
    system:addEventListener({"update"}, sceneBattle)
    if demoMode and not demoModeDebug then
        system:addEventListener({"touch"}, cancelBattle)
        dbg.print("GAME: added cancel touch")
    else
        system:addEventListener({"touch"}, sceneBattle)
        dbg.print("GAME: added battle touch")
    end
    if demoMode then
        self.demoTimers = {}
        self.demoTimers[1] = system:addTimer(randomPlayerTimer, 1.5, 1)
        self.demoTimers[1].player = player1
        self.demoTimers[2] = system:addTimer(randomPlayerTimer, 2, 1)
        self.demoTimers[2].player = player2
        
        self.demoLabel = director:createLabel({x=0, y=minY+80, hAlignment="centre", vAlignment="centre", text="INSERT COIN", color=menuBlue, font=fontMainLarge, zOrder=20})
        origin:addChild(self.demoLabel)
        tween:to(self.demoLabel, {alpha=0, time=1, mode="mirror"})
    else
        if gameInfo.soundOn then
            if gameInfo.controlType == "onePlayer" and gameInfo.mode ~= "survival" then
                audio:playStream("sounds/" .. waveMusic[1], true)
            else
                audio:playStream("sounds/voyager.mp3", true)
            end
        end
    end
    
    local startDelay
    if gameInfo.controlType == "onePlayer" then
        
        --NB: with debug builds, messages may appear out of order due to slow debug text creation speed vs timers!
        if gameInfo.continue.canContinue then
            startDelay = 4
            self.continuePause = system.gameTime + startDelay
            ShowMessage("CONTINUING", 0.5, false, "up")
            ShowMessage("ABANDONED GAME", 1.5, false, "down")
            if gameInfo.mode == "survival" then
                ShowMessage("survival mode", 2.5, false, "down", 60)
                ShowMessage("GO!", startDelay, false, "up")
            else
                ShowMessage("WAVE " .. gameInfo.wave, 2.5, false, "down", 60)
            end
            ShowMessage("GO!", startDelay, false, "up")
        else
            startDelay = 5
            
            if gameInfo.mode == "survival" then
                ShowMessage("SURVIVAL", 0.5, false, "up")
                ShowMessage("MODE", 0.5, false, "down")
                ShowMessage("no waves", 2.5, false, "up", 60)
                ShowMessage("random items", 3, false, "down", -60)
                ShowMessage("GO!", startDelay, false, "up")
            else
                ShowMessage("control", 0.5, false, "up", 100)
                ShowMessage("both sides", 1, false, "up", 60)
                ShowMessage("with thumbs", 1.5, false, "up", 20)
                 
                ShowMessage("avoid the", 2.5, false, "down", -20)
                ShowMessage("bombs!", 3, false, "down", -100)
                
                ShowMessage("WAVE " .. gameInfo.wave, startDelay, false, "up")
            end
        end
        
        -- self-restarting timer that adds a ball every so-many seconds
        local delay = gameInfo.continue.ballDelay or INTIAL_NEW_BALL_DELAY
        self.ballTimer = system:addTimer(AddNewBall, delay, 1, startDelay)
        self.ballTimer.ballDelay = delay
        
        --only happens when continuing atm, but could use queue up balls on start if wanted
        if self.ballCreateQueue > 0 then
            self.ballReplaceTimer = system:addTimer(ReplenishBalls, REPLACE_BALL_DELAY, 1)
        end
        
        local scoreHelper = director:createLabel({x=30, y=maxY-54, hAlignment="left", vAlignment="center", w=100, text="score: bombs survived", color=menuBlue, font=fontMainSmall, alpha=0})
        origin:addChild(scoreHelper)
        scoreHelper:addTimer(ScoreHelperLabels, startDelay+2, 1)
    else
        startDelay = 2
        ShowMessage("FIGHT", startDelay, false, "up")
        self.ballTimer = system:addTimer(AddNewBall, gameInfo.continue.ballDelay or FIGHT_NEW_BALL_DELAY, 0, startDelay)
    end

    if not gameInfo.continue.canContinue then
        --this timer fires the initial rapid volley of balls on game start
        self.ballInitTimer = system:addTimer(AddNewBall, INITIAL_BALL_DELAY, INITIAL_BALL_QUEUE, startDelay)
        self.ballInitTimer.isInit = true
          -- Note that first frame has a huge time delta so we'd get a fast first ball if there was no delay
          -- Ideally this should be improved in Quick internals.
    end
    
    if gameInfo.continue.saveObj then
        for k,ballInfo in pairs(gameInfo.continue.saveObj) do
            RestoreBall(ballInfo)
        end
    end
    
    --system:addTimer(TestGun, 4, 1)
    
    self.gamePaused = false
    -- pause menu
    if not demoMode then
        self.originPause = director:createNode({x=appWidth/2, y=appHeight/2, zOrder=4})
        self.originMaskAnchor = director:createNode({x=appWidth/2, y=appHeight/2, zOrder=2})
        
        local pauseX = maxX-130 --easy to stretch thumb to for single player and avoids wave counter
        if gameInfo.controlType == "p1LocalVsP2Local" then
            pauseX = 0 --fairer for 2 player, plus otherwise its easier to accidentally hit when holding from side
         end
        
        --.pauseMenu holds all menus (puase, resume, exit, etc)        
        self.pauseMenu = director:createNode({x=pauseX, y=minY+20, zOrder=3})
        self.originPause:addChild(self.pauseMenu)
        
        self:scalePauseBtns() -- btns try to scale to be size of a finger!
        
        --.pause is the initial pause symbol
        self.pauseMenu.pause = director:createNode({x=0, y=0, xScale=0})
        self.pauseMenu:addChild(self.pauseMenu.pause)
        
        
        --y=20 offset put origin at bottom of circle for shrink/expand anims
        self.pauseMenu.touchCircle = director:createCircle({x=0, y=20, xAnchor=0.5, yAnchor=0.5, radius=20, alpha=0, strokeWidth=1, strokeColor=menuBlue})
        self.pauseMenu.pause1 = director:createRectangle({x=-7, y=20, xAnchor=0.5, yAnchor=0.5, w=7, h=25, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        self.pauseMenu.pause2 = director:createRectangle({x=7, y=20, xAnchor=0.5, yAnchor=0.5, w=7, h=25, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        
        self.pauseMenu.pause:addChild(self.pauseMenu.touchCircle)
        self.pauseMenu.pause:addChild(self.pauseMenu.pause1)
        self.pauseMenu.pause:addChild(self.pauseMenu.pause2)
        
        self.pauseMenu.touchCircle:addEventListener("touch", PauseGame)
        self.backKeyListener = PauseGame
        system:addEventListener("key", gameBackKeyListener)
        
        --tween:to(self.pauseMenu.pause, {time=0.4, yScale=1})
        --tween:to(self.pauseMenu.pause, {time=0.25, delay=0.15, xScale=1})
        tween:to(self.pauseMenu.pause, {time=0.4, xScale=1})
    end
    
    if not demoMode then
        -- add button to move play area on long portrait devices (like phones!)
        self.moveSceneTopOrMiddle()
    end
end

----------------------------------------------------------------
-- Pause Menu

-- TODO: should move this out to its own file and pass in origin and originPause
-- Cleaner to use sceneBattle.pauseMenu.touchCircle:touch() etc for functions?

function sceneBattle:scalePauseBtns()
    if not self.pauseMenu then return end
    
    -- want 0.5 inch button... get 0.5 inches in user (VR) space coords
    local btnSizeInches = 0.4
    local screenWidthInches = director.displayWidth / dpiScaler.dpi
    local btnSizeInScreenPix = director.displayWidth / (screenWidthInches / btnSizeInches)
    
    -- constrain by vr coord size - for small devices so button doesnt take up too much of screen
    local btnSize = math.min(virtualResolution:winToUserSize(btnSizeInScreenPix), 60)

    -- When I wrote the code originally, 20 pixels was the radius of the buttons..
    -- scale central node to 40 circumference -> whatever 1 inch is in pixels
    local scaleButtons = btnSize/40

    self.pauseMenu.xScale=scaleButtons
    self.pauseMenu.yScale=scaleButtons
    
    if (screenHeight - appHeight)/2 > btnSize then
        self.pauseMenu.y = minY-btnSize
    else
        self.pauseMenu.y = self.screenMinY+20--minY+20
    end
end

function DisablePauseMenu()
    if sceneBattle.pauseMenu then
        sceneBattle.pauseMenu.disabled = true
        sceneBattle.pauseMenu.touchCircle:removeEventListener({"touch"}, PauseGame)
        tween:to(sceneBattle.pauseMenu.pause, {time=0.4, xScale=0})
       
       system:removeEventListener("key", gameBackKeyListener)
    end
end

function gameBackKeyListener(event)
    if event.keyCode == 210 and event.phase == "pressed" then
        sceneBattle.backKeyListener({phase="ended"})
    end
end

function PauseGame(touch)
    if touch.phase == "ended" then
        sceneBattle.gamePaused = true
        cancelTweensOnNode(sceneBattle.pauseMenu) --can touch while still re-appearing
        
        sceneBattle.pauseMenu.touchCircle:removeEventListener({"touch"}, PauseGame)
        system:removeEventListener({"touch"}, sceneBattle)
        
        system:pauseTimers()
        pauseNodesInTree(origin)
        
        -- Now saving data on pause. Device might die without ever suspending app.
        -- Windows store tries to freeze and do auto resume rather than suspending. Would
        -- rather save in case that doesn't work!
        if not demoMode then
            sceneBattle:saveState()
        end
        
        --sceneBattle.pauseMenu:resumeTweens()
        if not sceneBattle.originMask then
            sceneBattle.originMask = director:createRectangle({x=sceneBattle.screenMinX, y=sceneBattle.screenMinY,
                    w=screenWidth, h=screenHeight, zOrder=2, color={0,20,0}, alpha=0, strokeWidth=0, zOrder=-1})
            sceneBattle.originMaskAnchor:addChild(sceneBattle.originMask)
        end
        
        tween:to(sceneBattle.originMask, {time=0.4, alpha=0.85})
        tween:to(sceneBattle.pauseMenu.pause, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.pause, {time=0.4, yScale=0, onComplete=ShowPauseMenu})
        
        sceneBattle:orientation(nil, true) --make sure mask is in right place
        
        sceneBattle:startPauseEffects()
    end
    return true
end

function sceneBattle:startPauseEffects()
    if self.screenFx then
        cancelTweensOnNode(self.screenFx)
        self.screenFx.filter.name = "blur"
        self.screenFx.filter.x = 0
        self.screenFx.filter.y = 0
        self.screenFx.zOrder = 3
        self:clearScreenFx()
        self.screenFx.alpha = 1
        
        self.screenFx.tween = tween:to(self.screenFx, {filter={x=3,y=3}, time=2, mode="mirror",
            easing=ease.bounceInOut})
        
        self.pauseMenu.tween = tween:to(self.pauseMenu, {color={r=255,g=255,b=255}, time=2, mode="mirror",
            easing=ease.bounceInOut})
    end
end

function ShowPauseMenu()
    local resume = sceneBattle.pauseMenu.resume
    if not resume then
        resume = director:createNode({x=0, y=0, xScale=0, yScale=0, zOrder=3})
        resume.touchCircle = director:createCircle({x=0, y=20, xAnchor=0.5, yAnchor=0.5, radius=20, color=color.black, strokeWidth=1, strokeColor=menuBlue})
        resume.play = director:createLines({x=0, y=20, coords={-8,-12, -8,12, 14,0, -8,-12}, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        resume:addChild(resume.touchCircle)
        resume:addChild(resume.play)
        sceneBattle.pauseMenu:addChild(resume)
        sceneBattle.pauseMenu.resume = resume
    end
    
    local quit = sceneBattle.pauseMenu.quit
    if not quit then
        quit = director:createNode({x=0, y=0, xScale=0, yScale=0, zOrder=3})
        quit.touchCircle = director:createCircle({x=0, y=20, xAnchor=0.5, yAnchor=0.5, radius=20, color=color.black, strokeWidth=1, strokeColor=menuBlue})
        quit.door = director:createLines({x=0, y=20, coords={7,-12, -9,-12, -9,12, 7,12}, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        quit.arrow = director:createLines({x=0, y=20, coords={-5,0, 2,8, 2,3, 12,3, 12,-3, 2,-3, 2,-8, -5,0}, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        quit:addChild(quit.touchCircle)
        quit:addChild(quit.door)
        quit:addChild(quit.arrow)
        sceneBattle.pauseMenu:addChild(quit)
        sceneBattle.pauseMenu.quit = quit
    end
    
    if not sceneBattle.pauseMenu.pauseLabel then
        local labelY = 0
        if gameInfo.controlType == "p1LocalVsP2Local" then
            labelY = 80 --avoid buttons when they are in centre of screen
        end
        sceneBattle.pauseMenu.pauseLabel = director:createLabel({x=0, y=labelY, hAlignment="centre", vAlignment="centre", text="PAUSED", color=menuBlue, font=fontMainLarge, zOrder=20})
        sceneBattle.originPause:addChild(sceneBattle.pauseMenu.pauseLabel)
    end
    sceneBattle.pauseMenu.pauseLabel.isVisible = true
    
    tween:to(sceneBattle.pauseMenu.resume, {time=0.4, x=15, y=55, yScale=1, onComplete=ActivatePauseMenu})
    tween:to(sceneBattle.pauseMenu.resume, {time=0.25, delay=0.15, xScale=1})
    
    tween:to(sceneBattle.pauseMenu.quit, {time=0.4, x=50, y=110, yScale=1})
    tween:to(sceneBattle.pauseMenu.quit, {time=0.25, delay=0.15, xScale=1})
end

function ActivatePauseMenu()
    sceneBattle.pauseMenu.resume.touchCircle:addEventListener("touch", HidePauseMenu)
    sceneBattle.pauseMenu.quit.touchCircle:addEventListener("touch", QuitFromPauseMenu)
    
    sceneBattle.backKeyListener = HidePauseMenu
    system:addEventListener("key", gameBackKeyListener)
    
    analytics:endSession() --try to force upload logs to server
    analytics:startSessionWithKeys()
    
    --TODO:
    -- display banner advert at top of puase screen, with timer to remove and re-show another one every 5 seconds
    -- on pause menu exit, check if banner is showing (need to use own flag probably or check ad internals)
    -- and hide if it is.
end

function HidePauseMenu(touch)
    if touch.phase == "ended" then
        sceneBattle.pauseMenu.resume.touchCircle:removeEventListener("touch", HidePauseMenu)
        sceneBattle.pauseMenu.quit.touchCircle:removeEventListener("touch", QuitFromPauseMenu)
        
        sceneBattle.pauseMenu.pauseLabel.isVisible = false
        
        tween:to(sceneBattle.originMask, {time=0.2, alpha=0})
        tween:to(sceneBattle.pauseMenu.resume, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.resume, {time=0.4, x=0, y=0, yScale=0, onComplete=ResumeGame})
        tween:to(sceneBattle.pauseMenu.quit, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.quit, {time=0.4, x=0, y=0, yScale=0})
        
        system:removeEventListener("key", gameBackKeyListener)
    end
    return true
end

function QuitFromPauseMenu(touch)
    if touch.phase == "ended" then
        sceneBattle.pauseMenu.resume.touchCircle:removeEventListener("touch", HidePauseMenu)
        sceneBattle.pauseMenu.quit.touchCircle:removeEventListener("touch", QuitFromPauseMenu)
        
        sceneBattle.pauseMenu.pauseLabel.isVisible = false
        
        tween:to(sceneBattle.pauseMenu.resume, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.resume, {time=0.4, x=0, y=0, yScale=0, onComplete=ShowQuitConfirmMenu})
        tween:to(sceneBattle.pauseMenu.quit, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.quit, {time=0.4, x=0, y=0, yScale=0})
        
        system:removeEventListener("key", gameBackKeyListener)
    end
    return true
end

function ShowQuitConfirmMenu()
    local yes = sceneBattle.pauseMenu.yes
    if not yes then
        yes = director:createNode({x=0, y=0, xScale=0, yScale=0, zOrder=3})
        yes.touchCircle = director:createCircle({x=0, y=20, xAnchor=0.5, yAnchor=0.5, radius=20, color=color.black, strokeWidth=1, strokeColor=menuBlue})
        yes.tick = director:createLines({x=0, y=20, coords={-5,-12, -14,2, -5,-3, 11,10, -5,-12}, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        yes:addChild(yes.touchCircle)
        yes:addChild(yes.tick)
        sceneBattle.pauseMenu:addChild(yes)
        sceneBattle.pauseMenu.yes = yes
    end
    
    local no = sceneBattle.pauseMenu.no
    if not no then
        no = director:createNode({x=0, y=0, xScale=0, yScale=0, zOrder=3})
        no.touchCircle = director:createCircle({x=0, y=20, xAnchor=0.5, yAnchor=0.5, radius=20, color=color.black, strokeWidth=1, strokeColor=menuBlue})
        no.cross = director:createLines({x=0, y=20, coords={-3,0, -12,9, -9,12, 0,3, 9,12, 12,9, 3,0, 12,-9, 9,-12, 0,-3, -9,-12, -12,-9, -3,0}, alpha=0, strokeWidth=1, strokeColor=menuGreen})
        no:addChild(no.touchCircle)
        no:addChild(no.cross)
        sceneBattle.pauseMenu:addChild(no)
        sceneBattle.pauseMenu.no = no
    end
    
    if not sceneBattle.pauseMenu.quitLabel then
        local labelY = 0
        if gameInfo.controlType == "p1LocalVsP2Local" then
            labelY = 80 --avoid buttons when they are in centre of screen
        end
        sceneBattle.pauseMenu.quitLabel = director:createLabel({x=0, y=labelY, hAlignment="centre", vAlignment="centre", text="QUIT GAME?", color=menuBlue, font=fontMainLarge, zOrder=20})
        sceneBattle.originPause:addChild(sceneBattle.pauseMenu.quitLabel)
    end
    sceneBattle.pauseMenu.quitLabel.isVisible = true
    
    tween:to(sceneBattle.pauseMenu.yes, {time=0.4, x=15, y=55, yScale=1, onComplete=ActivateQuitConfirmMenu})
    tween:to(sceneBattle.pauseMenu.yes, {time=0.25, delay=0.15, xScale=1})
    
    tween:to(sceneBattle.pauseMenu.no, {time=0.4, x=50, y=110, yScale=1})
    tween:to(sceneBattle.pauseMenu.no, {time=0.25, delay=0.15, xScale=1})
end

function ActivateQuitConfirmMenu()
    sceneBattle.pauseMenu.yes.touchCircle:addEventListener("touch", ExitFromQuitConfirmMenu)
    sceneBattle.pauseMenu.no.touchCircle:addEventListener("touch", BackToPauseMenu)
    
    sceneBattle.backKeyListener = BackToPauseMenu
    system:addEventListener("key", gameBackKeyListener)
end

function BackToPauseMenu(touch)
    if touch.phase == "ended" then
        sceneBattle.pauseMenu.yes.touchCircle:removeEventListener("touch", ExitFromQuitConfirmMenu)
        sceneBattle.pauseMenu.no.touchCircle:removeEventListener("touch", BackToPauseMenu)
        
        sceneBattle.pauseMenu.quitLabel.isVisible = false
        
        tween:to(sceneBattle.pauseMenu.yes, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.yes, {time=0.4, x=0, y=0, yScale=0, onComplete=ShowPauseMenu})
        tween:to(sceneBattle.pauseMenu.no, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.no, {time=0.4, x=0, y=0, yScale=0})
        
        system:removeEventListener("key", gameBackKeyListener)
    end
    return true
end

function ExitFromQuitConfirmMenu(touch)
    if touch.phase == "ended" then
        sceneBattle.pauseMenu.yes.touchCircle:removeEventListener("touch", ExitFromQuitConfirmMenu)
        sceneBattle.pauseMenu.no.touchCircle:removeEventListener("touch", BackToPauseMenu)
        
        sceneBattle.pauseMenu.quitLabel.isVisible = false
        
        tween:to(sceneBattle.originMask, {time=0.2, alpha=0})
        tween:to(sceneBattle.pauseMenu.yes, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.yes, {time=0.4, x=0, y=0, yScale=0, onComplete=ExitFromQuitConfirmMenu2})
        tween:to(sceneBattle.pauseMenu.no, {time=0.25, xScale=0})
        tween:to(sceneBattle.pauseMenu.no, {time=0.4, x=0, y=0, yScale=0})
        if sceneBattle.screenFx then
            if sceneBattle.screenFx.tween then
                tween:cancel(sceneBattle.screenFx.tween)
                sceneBattle.screenFx.tween = nil
            end
            sceneBattle.screenFx.filter.name = nil
            sceneBattle.screenFx.zOrder = -1
            sceneBattle.screenFx.alpha = 0.7
            tween:to(sceneBattle.screenFx, {alpha=0, time=0.3})
        end
        
        system:removeEventListener("key", gameBackKeyListener)
    end
    return true
end

function ExitFromQuitConfirmMenu2()
    system:resumeTimers()
    resumeNodesInTree(origin)
    sceneBattle.gamePaused = false
    local wave=gameInfo.wave
    if wave == nil then wave = "none" end
    system:removeEventListener("key", gameBackKeyListener)
    analytics:logEvent("quitGame", {controlType=gameInfo.controlType, wave=tostring(wave)})
    cancelBattle({phase="ended"})
end

function ResumeGame()
    system:addEventListener({"touch"}, sceneBattle)
    sceneBattle.pauseMenu.touchCircle:addEventListener("touch", PauseGame)
    sceneBattle.backKeyListener = PauseGame
    system:addEventListener("key", gameBackKeyListener)
    
    system:resumeTimers()
    resumeNodesInTree(origin)
    sceneBattle.gamePaused = false
    
    --stop filter and clear texture so pause menu doesn't overpower screen!
    if sceneBattle.screenFx then --checks not really needed but let's stay safe in case logic changes
        if sceneBattle.screenFx.tween then
            tween:cancel(sceneBattle.screenFx.tween)
            sceneBattle.screenFx.tween = nil
        end
        sceneBattle.screenFx.filter.name = nil
        sceneBattle.screenFx.zOrder = -1
    end
    
    sceneBattle:clearScreenFx()
    sceneBattle:reshowScreenFx()
    
    sceneBattle:orientation()
    
    tween:to(sceneBattle.pauseMenu.pause, {time=0.4, yScale=1})
    tween:to(sceneBattle.pauseMenu.pause, {time=0.25, delay=0.15, xScale=1})
    
    --in case somethin's gone wrong and bar re-showed itself, now is a good time
    --to force re-hide
    if androidFullscreen and androidFullscreen:isImmersiveSupported() then
        androidFullscreen:turnOn()
    end
end

-----------------------------------------------------------------------------

function sceneBattle:suspend(event)
    dbg.print("suspending...")
    if not pauseflag then
        if not sceneBattle.gamePaused then
            system:pauseTimers()
            pauseNodesInTree(origin) --pauses timers and tweens
        else
            pauseNodesInTree(self.originPause)
        end
    end
    
    if not demoMode then
        self:saveState()
    end
    
    analytics:endSession() --force upload logs to server
    analytics:startSessionWithKeys()
    dbg.print("...suspended!")
end

function sceneBattle:resume(event)
    dbg.print("resuming...")
    pauseflag = true
    --system:resumeTimers()
    --resumeNodesInTree(self)
    dbg.print("...resumed")
end

----------------------------------------------------------------------------

TestGun = function(event)
    player1:Fire("reverser")
end

function sceneBattle:cancelDemoTimers()
    if self.demoTimers then
        if self.demoTimers[1] then
            self.demoTimers[1]:cancel()
            self.demoTimers[1] = nil
        end
        if self.demoTimers[2] then
            self.demoTimers[2]:cancel()
            self.demoTimers[2] = nil
        end
    end
end

function sceneBattle:cancelTimers()
    self:cancelDemoTimers()
    if player2.AITimer then
        player2.AITimer:cancel()
        player2.AITimer = nil
    end
    cancelTimersOnNode(player1.sled)--includes freeze timers
    cancelTimersOnNode(player2.sled)
    if self.unFreezeTimer then self.unFreezeTimer:cancel() self.unFreezeTimer = nil end
    if self.ballTimer then
        self.ballTimer:cancel()
        self.ballTimer = nil
    end
    if self.ballInitTimer then
        self.ballInitTimer:cancel()
        self.ballInitTimer = nil
    end
    if self.ballReplaceTimer then
        self.ballReplaceTimer:cancel()
        self.ballReplaceTimer = nil
    end
    if sceneBattle.spriteFxTimer then
        for kT,vT in pairs(sceneBattle.spriteFxTimer) do
            vT:cancel()
            sceneBattle.spriteFxTimer[kT] = nil
        end
        self.spriteFxTimer = nil
    end
    self.ballCreateQueue = 0
end

function sceneBattle:removeSceneMoveButton()
    if self.moveBtn then
        if gameInfo.portraitTopAlign then
            oldBtn = "down"
        else
            oldBtn = "up"
        end
        removeArrowButton(self, oldBtn, self.moveSceneTopOrMiddle)
        self.moveBtn = nil
    end
end

-- stop controls pre-transition
-- also cancelling timers (looked a bit nicer this way)
function sceneBattle:exitPreTransition(event)
    dbg.print("sceneBattle:exitPreTransition")
    
    if showFrameRate then
        frameRateOverlay.hideFrameRate() --debugging
    end
    
    self:removeSceneMoveButton()
    
    system:removeEventListener({"suspend", "resume", "update", "orientation"}, self)
    if demoMode and not demoModeDebug then
        system:removeEventListener({"touch"}, cancelBattle)
    else
        system:removeEventListener({"touch"}, self)
        audio:stopStream()
    end
    --fine to end touch etc this late as they are guarded against running in game over phase
    
    -- stop all logic before transition begins
    -- without this, for example, tweens will keep running on cancel demo event, which might result in
    -- onComplete function destroying or creating balls. Also better visually to "freeze" during transition
    self:cancelTimers()
    pauseNodesInTree(origin) 
    dbg.print("Cancelled all timers")
    
    if self.demoLabel then
        destroyNode(self.demoLabel)
        self.demoLabel = nil
    end
end 

-- destroy all objects after transition so they are still visible during anim
function sceneBattle:exitPostTransition(event)
    dbg.print("sceneBattle:exitPostTransition")
    
    fullscreenEffectsOff(self)

    -- for most nodes, we coul just do destroyNodesInTree(self.origin, true)!
    -- but instead we're explicitly tearing down items in groups. Useful for finding bugs.
    
    --if self.message then
    --    destroyNode(self.message)
    --    self.message = nil
    --end
    
    --stars
    destroyNodesInTree(self.background, true)
    self.background = nil
    
    -- All of our "Destroy" functions cancel all the nodes' tweens and timers
    -- Needed since some will have events still queued that might try to execute,
    -- prevent garbage collection and generally cause bugs
    for k,v in pairs(collidables) do
        CollidableDestroy(v)
    end
    collidables = nil

    for k,v in pairs(players) do
        v:Destroy()
    end
    player1 = nil
    player2 = nil
    players = nil

    if self.score then
        self.score:Destroy()
        self.score = nil
    end
    if self.waveLeft then
        self.waveLeft:Destroy()
        self.waveLeft = nil
    end
    
    self.recycler = nil --parentless nodes in this will now be garbage collected
    self.recyclerCount = nil
    
    -- Kill any left over effects etc not tracked above
    dbg.print("full origin tree node destroy...")
    origin = destroyNodesInTree(origin, true)
    if self.originPause then
        self.originPause = destroyNodesInTree(self.originPause, true)
    end
    if self.originMaskAnchor then
        self.originMaskAnchor = destroyNodesInTree(self.originMaskAnchor, true)
    end
    
    self.pauseMenu = nil
    self.originMask = nil
    
    dbg.print("..full origin tree node destroy done")
    
    dbg.print("scene Nodes destroyed")
    dbg.print("GC count: " .. collectgarbage("count"))
    
    self:releaseResources()
    collectgarbage("collect")
    dbg.print("GC count: " .. collectgarbage("count"))
    collectgarbage("collect")
    dbg.print("GC count: " .. collectgarbage("count"))
    -- trial and error shoes it takes 3 garbage cycles to collect scene ojects

    dbg.print("sceneBattle:exitPostTransition done")
end

sceneBattle:addEventListener({"setUp", "enterPostTransition", "exitPreTransition", "exitPostTransition"}, sceneBattle)

