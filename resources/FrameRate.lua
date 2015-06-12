
-- Simple frame rate overlay
-- (C) Nick Smith 2014

frameRateOverlay = {}

function frameRateOverlay.update(event)
    local fps = 1 / system.deltaTime

    if frameRateOverlay.count == 5 then
        frameRateOverlay.average = frameRateOverlay.total / 5
        frameRateOverlay.count = 0
        frameRateOverlay.total = 0
    end

    frameRateOverlay.count = frameRateOverlay.count + 1
    frameRateOverlay.total = frameRateOverlay.total + fps
    
    frameRateOverlay.label.text = string.format("FPS: %d (%.1f)", frameRateOverlay.average, fps)

end

function frameRateOverlay.showFrameRate(xOrTable, y, width, boxColor, zOrder, parent)
    if type(xOrTable) == "table" then
        x = xOrTable.x
        y = xOrTable.y
        width = xOrTable.width
        boxColor = xOrTable.boxColor
        parent = xOrTable.parent
    end
    
    x = x or 0
    y = y or 0
    width = width or 150
    boxColor = boxColor or {0,255,0}
    
    frameRateOverlay.box = director:createRectangle({zOrder=10, x=x, y=y, w=150, h=24, color=boxColor, alpha=0.7, strokeWidth=1, strokeColor=color.white, strokeAlpha=1, zOrder=zOrder or 0})
    frameRateOverlay.label = director:createLabel({zOrder=11, x=6, y=3, w=200, h=20, color=color.black, text="fps: ?", xScale=0.7, yScale=0.7})
    frameRateOverlay.box:addChild(frameRateOverlay.label)
    
    if parent then
        parent:addChild(frameRateOverlay.box)
    end
    
    local scale = width/150
    frameRateOverlay.box.xScale = scale
    frameRateOverlay.box.yScale = scale

    frameRateOverlay.count = 0
    frameRateOverlay.total = 0
    frameRateOverlay.average = 0
    
    system:addEventListener({"update"}, frameRateOverlay)
end

function frameRateOverlay.hideFrameRate()
    if frameRateOverlay.box then
        system:removeEventListener({"update"}, frameRateOverlay)
        frameRateOverlay.box:removeFromParent()
        frameRateOverlay.label:removeFromParent()
        frameRateOverlay.box = nil
        frameRateOverlay.label = nil
    end
end

function frameRateOverlay.isShown()
    return frameRateOverlay.box ~= nil
end