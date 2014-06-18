-- COUNTERDIGIT class for each digital clock style digit used by the COUNTER class --

CounterDigit = {}
CounterDigit.__index = CounterDigit
function CounterDigit.Create(initValue, sideImage, middleImage, counterOrigin)
    local counterDigit = {}
    setmetatable(counterDigit,CounterDigit)

    counterDigit.value = initValue

    -- start alpha=0 so we can fade on
    counterDigit.origin = director:createNode({x=0, y=0, xScale=4, yScale=4, alpha=0})
    counterDigit.origin.zOrder = 10 -- keep to front
    counterDigit.segments = {}

    -- load image and position for each part of digital counterDigit (prob should be doing some cloning etc
    -- or could just use vectors to make colouring easier)
    -- use .top segment as parent so other parts position and scale with it
    -- (Quick doesn't give us a flexible way to set parent coordinates so this is prob easiest option)
    -- 0,0 is bottom left of digit

    -- x at -7 to put conceptual centre in middle (13 pixel wide counterDigit)
    -- could change this to do double digit counters
    local centreOffsetX = 6
    local centreOffsetY = 13

    counterDigit.segments.top = director:createSprite(0-centreOffsetX, 22-centreOffsetY, sideImage)
    counterDigit.origin:addChild(counterDigit.segments.top)

    counterDigit.segments.topLeft = director:createSprite(3-centreOffsetX, 12-centreOffsetY, sideImage)
    counterDigit.origin:addChild(counterDigit.segments.topLeft)
    counterDigit.segments.topLeft.rotation = -90

    counterDigit.segments.bottomLeft = director:createSprite(3-centreOffsetX, 0-centreOffsetY, sideImage)
    counterDigit.origin:addChild(counterDigit.segments.bottomLeft)
    counterDigit.segments.bottomLeft.rotation = -90

    counterDigit.segments.topRight = director:createSprite(10-centreOffsetX, 25-centreOffsetY, sideImage)
    counterDigit.origin:addChild(counterDigit.segments.topRight)
    counterDigit.segments.topRight.rotation = 90

    counterDigit.segments.bottomRight = director:createSprite(10-centreOffsetX, 13-centreOffsetY, sideImage)
    counterDigit.origin:addChild(counterDigit.segments.bottomRight)
    counterDigit.segments.bottomRight.rotation = 90

    counterDigit.segments.bottom = director:createSprite(13-centreOffsetX, 3-centreOffsetY, sideImage)
    counterDigit.origin:addChild(counterDigit.segments.bottom)
    counterDigit.segments.bottom.rotation = 180

    counterDigit.segments.middle = director:createSprite(0-centreOffsetX, 11-centreOffsetY, middleImage)
    counterDigit.origin:addChild(counterDigit.segments.middle)

    counterOrigin:addChild(counterDigit.origin)
    return counterDigit
end

function CounterDigit:Destroy()
    for k,v in pairs(self.segments) do
        v:removeFromParent()
        self.segments[k] = nil
    end
    self.origin:removeFromParent()
    self.origin = nil
    self = nil
end

function CounterDigit:UpdateDisplay(value)
    -- our counter is made of cloned and rotated images shown/hidden
    -- prob way simpler to just have a list of full bitmaps to show/hide for each value!
    -- But since I did this, we can do some fun per-trapezium animation if we want :)
    -- Actually prob just want to make these out of primitives then can colour them too.
    if value == 0 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = true
        self.segments.bottomLeft.isVisible = true
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = false
    elseif value == 1 then
        self.segments.top.isVisible = false
        self.segments.topLeft.isVisible = false
        self.segments.bottomLeft.isVisible = false
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = false
        self.segments.middle.isVisible = false
    elseif value == 2 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = false
        self.segments.bottomLeft.isVisible = true
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = false
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = true
    elseif value == 3 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = false
        self.segments.bottomLeft.isVisible = false
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = true
    elseif value == 4 then
        self.segments.top.isVisible = false
        self.segments.topLeft.isVisible = true
        self.segments.bottomLeft.isVisible = false
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = false
        self.segments.middle.isVisible = true
    elseif value == 5 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = true
        self.segments.bottomLeft.isVisible = false
        self.segments.topRight.isVisible = false
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = true
    elseif value == 6 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = true
        self.segments.bottomLeft.isVisible = true
        self.segments.topRight.isVisible = false
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = true
    elseif value == 7 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = false
        self.segments.bottomLeft.isVisible = false
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = false
        self.segments.middle.isVisible = false
    elseif value == 8 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = true
        self.segments.bottomLeft.isVisible = true
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = true
    elseif value == 9 then
        self.segments.top.isVisible = true
        self.segments.topLeft.isVisible = true
        self.segments.bottomLeft.isVisible = false
        self.segments.topRight.isVisible = true
        self.segments.bottomRight.isVisible = true
        self.segments.bottom.isVisible = true
        self.segments.middle.isVisible = true
    end
end


-- COUNTER class for holding scores and displaying then as multiple digits using CounterDigit objects --

Counter = {}
Counter.__index = Counter

function Counter.Create(playerId, initValue, maxValue, hideOnStart, colourOverride, dontHideOnZero)
    local counter = {}
    setmetatable(counter,Counter)

    counter.id = playerId
    counter.value = initValue
    counter.maxValue = maxValue
    counter.unitValue = initValue % 10
    counter.dontHideOnZero = dontHideOnZero

    -- Visual stuff

    local colour = playerId
    if colourOverride then colour = colourOverride end

    if colour == 1 then
        colour = "Green"
    elseif colour == 2 then
        colour = "Red"
    else
        colour = "Blue"
    end

    local sideImage = "textures/DigiCounterSide" ..colour.. ".png"
    local middleImage = "textures/DigiCounterMiddle" ..colour.. ".png"

    -- meter needs to offset by a pixel to be equal distance from each screen side using same origin (odd sized counter, even sized screen)
    local nudge
    if playerId == 1 then nudge = -1 else nudge = 0 end
    
    -- origin object for positioning visual parts.
    counter.origin = director:createNode({x=nudge, y=0})
    counter.origin.zOrder = 10 -- keep to front

    counter.localOrigin = director:createNode({x=0, y=0})
    counter.origin:addChild(counter.localOrigin) -- to allow us to move counter when animating

    -- create (and hide if needed) all visual digits at start to avoid doing at runtime
    counter.digitWidth = 15 -- dist from one digit to the next
    counter.visibleDigits = 0
    counter.digitCount = 0
    counter.digits = {}
    local number = counter.maxValue
    repeat
        number = number / 10
        counter.digitCount = counter.digitCount + 1
    until number < 1

    for n=1, counter.digitCount, 1 do
        table.insert(counter.digits, CounterDigit.Create(0, sideImage, middleImage, counter.localOrigin))
    end

    origin:addChild(counter.origin)

    if not hideOnStart then
        counter:UpdateDisplay()
    end

    return counter
end

function Counter:Destroy()
    self.localOrigin:removeFromParent()
    self.origin:removeFromParent()
    self = nil
end


function Counter:SetValue(value)
    -- bouncy anim on units counter on change
    local unit = value % 10

    if unit ~= self.unitValue then
        cancelTweensOnNode(self.digits[1].origin)

        if value > self.value then
            tween:to(self.digits[1].origin, {xScale=0.7, yScale=1.5, time=0.2, onComplete=CounterAnimReset})
        else
            tween:to(self.digits[1].origin, {xScale=0.2, time=0.2, onComplete=CounterAnimReset})
        end
    end

    self.value = value
    self.unitValue = unit

    if self.value > self.maxValue then
        self.value = self.maxValue
    elseif self.value < 0 then
        self.value = 0
    end

    self:UpdateDisplay()
end

function CounterAnimReset(target)
    tween:to(target, {xScale=1, yScale=1, alpha=1, time=0.2})
end

function Counter:Increment(value)
    self:SetValue(self.value + value)
end

function Counter:UpdateDisplay(firstTime)
    local number = self.value

    local newVisibleDigits = 0
    if self.value ~= 0 then -- final digit animates out on value==0. remove if we want to still show final zero.
        repeat
            number = number / 10
            newVisibleDigits = newVisibleDigits + 1
        until number < 1
    end

    local divValue = 1
    local modValue = 10

    -- slide whole counter along for player 1 so counter is left-aligned
    -- player 2 doesnt need this as numbers are right-aligned by default!
    if self.id ~= 2 and newVisibleDigits ~= self.visibleDigits then
        cancelTweensOnNode(self.localOrigin)

        local newX = (newVisibleDigits-1)*self.digitWidth
        if self.id == 0 then newX = newX /2 end
        tween:to(self.localOrigin, {x=newX, time = 0.5})
    end

    -- animate new/old digits appearing/disappearing
    for k,digit in pairs(self.digits) do
        -- lose digit as value is smaller than digit's multiple of ten
        if k <= self.visibleDigits and k > newVisibleDigits then
            cancelTweensOnNode(digit.origin)

            digit:UpdateDisplay(0)
            if not (self.dontHideOnZero and self.value == 0) then
                tween:to(digit.origin, {alpha=0, xScale=4, yScale=4, time=0.7})
            end
        -- gain digit
        elseif k <= newVisibleDigits then
            if k > self.visibleDigits then
                cancelTweensOnNode(digit.origin)

                --if firstTime then --on first creation, digits all appear instantly, but could change...
                --else
                    tween:to(digit.origin, {alpha=1, xScale=1, yScale=1, time=0.5})
                --end
            end

            digit:UpdateDisplay(math.floor(self.value % modValue / divValue))
            digit.origin.x = -self.digitWidth*(k-1)
        end
        divValue = divValue*10
        modValue = modValue*10
    end

    self.visibleDigits = newVisibleDigits
end
