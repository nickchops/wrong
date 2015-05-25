
require("Counter")

-- Counter class for on screen value display
WeaponsMeter = {}
WeaponsMeter.__index = WeaponsMeter

--function WeaponsMeter.Create(playerId, mirrorX, ammoBulletAmmount, ammoOtherAmount, colourOverride)
function WeaponsMeter.Create(playerId, mirrorX, ammo, ammoDefault, colourOverride)
    local meter = {}
    setmetatable(meter,WeaponsMeter)

    meter.id = playerId
    --meter.origin = director:createRectangle({x=0, y=0, w=1, h=1, xAnchor=0, yAnchor=0, alpha=1, strokeWidth=0}) --uncomment to check origin position visually
    meter.origin = director:createNode({x=0, y=0, zOrder=10})
    origin:addChild(meter.origin)

    meter.mirrorX = mirrorX
    meter.frameCount = 0

    -- nudge meter again to cope with scaling adjusting size by 1 pixel (cant scale after rotation)
    local nudge
    if playerId == 1 then nudge = -1 else nudge = 0 end
    meter.origin:translate(nudge,0)

    -- AMMO DISPLAY --
    meter.ammoCounter = Counter.Create(playerId, 0, 9, true, colourOverride)
    meter.ammoCounter.origin:scale(0.6666,0.6666)
    meter.origin:addChild(meter.ammoCounter.origin)
    meter.ammoCounter.origin:translate(0,23)

    meter.currentWeaponID = 1
    meter.currentWeapon = "bullet"
    meter.ammo = {bullet = ammo.bullet or ammoDefault, ball = ammo.ball or ammoDefault, air =  ammo.air or ammoDefault, expander = ammo.expander or ammoDefault, freezer = ammo.freezer or ammoDefault, heatseeker = ammo.heatseeker or ammoDefault, reverser = ammo.reverser or ammoDefault}

    -- only allow air to have ammo at start in survival
    if gameInfo.controlType == "onePlayer" then
        meter.ammo.bullet = 0
        meter.ammo.expander = 0
        meter.ammo.freezer = 0
        meter.ammo.reverser = 0
        meter.ammo.ball = 0
        if gameInfo.mode == "survival" then -- give player ammo to start in this mode
            meter.currentWeaponID = 3 --explicitly set to air as its most practical
            meter.currentWeapon = "air"
        else
            meter.ammo.heatseeker = 0
        end
    end

    -- DASHBOARD (SELECTED WEAPON LIGHTS) & ICONS --

    -- parent node of "dashboard" weapon select lights to allow them to be mirrored easily for p1 vs p2
    meter.dashboard = {}
    meter.dashboardOrigin = director:createNode({x=0, y=0})
    meter.origin:addChild(meter.dashboardOrigin)
    --meter.dashboardOrigin.xScale = 10-- -mirrorX

    meter.icons = {}
    meter.iconsOrigin = director:createNode({x=-20*mirrorX, y=23})
    meter.origin:addChild(meter.iconsOrigin)

    -- NB, we're flipping in x for p1 vs p2. To keep things simple, we're leaving x & y anchors in the centre so we
    -- can grow/shrink the lights cleanly. However, Quick does some slightly unpredictable positioning and scaling
    -- with rectangles (seems point to pixel space conversion leads to not very pixel perfect) so I wound up having
    -- to do trial and error tweaking, hence 1 pixel xPos tweak and 0.52 anchor!
    local dashPosDiff = -36 +3 -- 6*light offset so 1st light is to left, 3 pixel nudge to line up yellow light with ammo counter

    for k,weapon in pairs(weapons) do
        meter.dashboard[weapon] = director:createRectangle({x=dashPosDiff*mirrorX + 1, y=0, xAnchor=0.52, w=3, h=8, strokeWidth=0, color=dashboardColours[weapon]})
        meter.dashboardOrigin:addChild(meter.dashboard[weapon]) --use counter as our origin
        dashPosDiff = dashPosDiff + 6

        -- WEAPON ICON --
        local icon = director:createNode({x=0,y=0})

        if weapon == "bullet" or weapon == "ball" or weapon == "air" or weapon == "freezer" then
            local ringAlpha = 1
            local startRadius = ballRadius+1
            local scaleDown = 2
            local xOffset = 0
            if weapon == "air" then
                startRadius = ballRadius+3
                scaleDown = 3
                ringAlpha = 0.7
            elseif weapon == "freezer" then
                startRadius = ballRadius-3
                scaleDown = -3
                ringAlpha = 0.7
            end
            for n=0, 2, 1 do
                if weapon == "bullet" or weapon == "ball" then
                    xOffset = (-5*n*mirrorX)+(mirrorX*3)
                end
                if n == 1 then
                    ringAlpha = ringAlpha - 0.3
                elseif n == 2 then
                    ringAlpha = ringAlpha - 0.2
                end
                local circle = director:createCircle({xAnchor=0.5,yAnchor=0.5, x=xOffset, y=0, radius=startRadius-n*scaleDown, strokeWidth=1, strokeColor=collidableColours[weapon], strokeAlpha=ringAlpha, alpha=0, color=color.black})
                icon:addChild(circle)
            end
        elseif weapon == "expander" then
            local arrow1 = CollidableCreate("expander-up", 0, 0, {0,0}, 0, true)
            arrow1.xScale = 0.8 arrow1.yScale = 0.8
            arrow1.y = 3
            icon:addChild(arrow1)
            local arrow2 = CollidableCreate("expander-down", 0, 0, {0,0}, 0, true)
            arrow2.xScale = 0.8 arrow2.yScale = 0.8
            arrow2.y = -3
            icon:addChild(arrow2)
        elseif weapon == "heatseeker" then
            icon:addChild(CollidableCreate(weapon, 0, 0, {0,0}, 0, true))
            icon:addChild(director:createCircle({xAnchor=0.5,yAnchor=0.5, x=0, y=0, radius=ballRadius+3, strokeWidth=1, strokeColor=collidableColours[weapon], strokeAlpha=0.5, alpha=0, color=color.black}))
        elseif weapon == "reverser" then
            local stepSize = 360/10
            for n=0, 360-stepSize, stepSize do
                local vec = VectorFromAngle(n, 12)
                local randomColour = colorIndex[math.random(1,numColors)]
                local spoke = director:createLines({x=0, y=0, coords={0,0, vec.x, vec.y}, xScale=1, yScale=1, strokeColor=color[randomColour], strokeWidth=1, strokeAlpha=1, alpha=0})
                icon:addChild(spoke)
            end
        end

        meter.icons[weapon] = icon
        meter.iconsOrigin:addChild(icon)
    end

    --local mask = director:createRectangle({x=0, y=0, w=20, h=20, strokeWidth=0, strokeAlpha=0, color=color.black, alpha=0.5})
    --meter.iconsOrigin:addChild(mask)

    meter:UpdateDisplay(false, true)

    return meter
end

function WeaponsMeter:Destroy()
    self.ammoCounter:Destroy()

    for k,v in pairs(self.dashboard) do
        v:removeFromParent()
    end

    for k,v in pairs(self.icons) do
        for kParts,vParts in pairs(v.children) do
            vParts:removeFromParent()
        end
        v:removeFromParent()
    end
    self.iconsOrigin:removeFromParent()

    self.origin:removeFromParent()
end

function WeaponsMeter:HasAmmo()
    -- currenet weapon must have ammo, unless no weapons have ammo
    if self.ammo[self.currentWeapon] > 0 then
        return true
    else
        return false
    end
end

function WeaponsMeter:Fire(weaponOverride)
    weapon = weaponOverride or self.currentWeapon
    self.ammo[weapon] = self.ammo[weapon] - 1

    self:UpdateDisplay()
end

function WeaponsMeter:ChangeWeapon(swipe)
    --dbg.print("swipe dif=" .. swipe)

    if self.frameCount == sceneBattle.frameCounter then
        return false
    end
    self.frameCount = sceneBattle.frameCounter

    if swipe*self.mirrorX > 0 then
        self.currentWeaponID = self.currentWeaponID + 1
        if self.currentWeaponID > weaponCount then self.currentWeaponID = 1 end
    else
        self.currentWeaponID = self.currentWeaponID - 1
        if self.currentWeaponID < 1 then self.currentWeaponID = weaponCount end
    end

    self.currentWeapon = weapons[self.currentWeaponID]
    self:UpdateDisplay(swipe)

    return true
end

function WeaponsMeter:SetWeapon(weaponID)
    self.currentWeaponID = weaponID
    self.currentWeapon = weapons[weaponID]
    self:UpdateDisplay()
end

function WeaponsMeter:UpdateDisplay(swipe, hideCounter)
    swipe = swipe or 0

    -- Cycle to prev/next weapon when ammo is out (ends back on current if all ammo gone)
    weaponsTried = 0
    while self.ammo[self.currentWeapon] == 0 and weaponsTried < weaponCount do

        if swipe*self.mirrorX > 0 then --next weapon if we got here on a forward swipe
            self.currentWeaponID = self.currentWeaponID + 1
            if self.currentWeaponID > weaponCount then self.currentWeaponID = 1 end
        else -- prev weapon on back swipe or no swipe
            self.currentWeaponID = self.currentWeaponID - 1
            if self.currentWeaponID < 1 then self.currentWeaponID = weaponCount end
        end
        weaponsTried = weaponsTried + 1
        self.currentWeapon = weapons[self.currentWeaponID]
    end

    for weapon,light in pairs(self.dashboard) do
        if self.ammo[weapon] == 0 then
            self.icons[weapon].isVisible = false
            light.alpha = 0.15
            light.xScale = 1
            light.yScale = 1
        elseif weapon == self.currentWeapon then
            self.icons[weapon].isVisible = true
            light.alpha = 1
            light.xScale = 1.7
            light.yScale = 1.3
        else
            self.icons[weapon].isVisible = false
            light.alpha = 0.5
            light.xScale = 1
            light.yScale = 1
        end
    end

    --if not hideCounter then
        self.ammoCounter:SetValue(self.ammo[self.currentWeapon])
    --end
end

--TODO amount doesnt do anything!!
function WeaponsMeter:AddAmmo(amount)
    if gameInfo.controlType == "onePlayer" then
        if gameInfo.powerupLevel == 0 then
            gameInfo.powerupLevel = 1
            ShowMessage("first weapon:", 0, false, "up", 100)
            ShowMessage("air cannon", 0.5, false, "up", 40)
            ShowMessage("tap to fire", 1.5, false, "down", -40)
        end
        if gameInfo.powerupLevel == 1 and self.ammo.air == POWERUP_FOR_NEXT_WEAPON-2 then
            gameInfo.powerupLevel = 2
            ShowMessage("get weapon", 0, false, "up", 100)
            ShowMessage("ammo over " .. POWERUP_FOR_NEXT_WEAPON, 0.5, false, "up", 40)
            ShowMessage("to unlock the", 1.5, false, "down", -40)
            ShowMessage("next weapon...", 2.0, false, "down", -100)
        end
        
        --when value goes over 9, next weapon becomes available
        if gameInfo.powerupLevel == 2 and self.ammo.air >= POWERUP_FOR_NEXT_WEAPON then
            gameInfo.powerupLevel = 3
            ShowMessage("new weapon:", 0, false, "up", 100)
            ShowMessage("heatseeker", 0.5, false, "down", 40)
            ShowMessage("slide L/R to", 1.5, false, "down", -40)
            ShowMessage("switch weapon", 2.0, false, "down", -100)
        end
        self.ammo.air = self.ammo.air + 1
        
        if gameInfo.powerupLevel >= 3 then
            if gameInfo.powerupLevel == 3 and self.ammo.heatseeker >= POWERUP_FOR_NEXT_WEAPON then
                gameInfo.powerupLevel = 4
                ShowMessage("new weapon:", 0, false, "up", 40)
                ShowMessage("more balls!", 0.5, false, "down", -40)
                ShowMessage("fire to speed up wave", 1.5, false, "down", -40)
            end
            self.ammo.heatseeker = self.ammo.heatseeker + 1
        end
        
        if gameInfo.powerupLevel >= 4 then
            if gameInfo.mode ~= "survival" then -- a useless weapon for survival!
                --if gameInfo.powerupLevel == 2 and self.ammo.heatseeker >=6 then
                --    gameInfo.powerupLevel = 3
                --    ShowMessage("new weapon:", 0, false, "up", 40)
                --    ShowMessage("health gun", 0.5, false, "down", -40)
                --end
                self.ammo.ball = self.ammo.ball + 1
            end
        end
    else
        self.ammo.bullet = self.ammo.bullet + 1
        self.ammo.ball = self.ammo.ball + 1
        self.ammo.expander = self.ammo.expander + 1
        self.ammo.air = self.ammo.air + 1
        self.ammo.freezer = self.ammo.freezer + 1
        self.ammo.heatseeker = self.ammo.heatseeker + 1
        self.ammo.reverser = self.ammo.reverser + 1
    end

    self:UpdateDisplay()
end

function MeterInterference(event)
    local timer = event.timer
    if event.doneIterations % 2 == 0 then
        timer.meter.isVisible = true
    else
        timer.meter.isVisible = false
    end
end