-- NB: Quick supports makePrecompiledLua etc if using dofile(), but not require()
-- So, for good performance but with some ease of code reuse, I'm using
-- dofile for big one-off inlcudes and require otherwise
--require("mobdebug").start() -- to debug before dofile(Globals)!

--workaround for asserts causing game to hang on Win Store 8.1 (at least)
if device:getInfo("platform") == "WS81" or device:getInfo("platform") == "WINDOWS" then
    dbg.assert = function(a,b) if not a then if b then dbg.print("assert: " .. b) else dbg.print("assert with no comment!") end end end
    --above must be on one line so will be trimmed out safely if using debug.general = false!
end

-- turn fullscreen on as early as possible. screen size won't update till bar is gone
if androidFullscreen == nil then
    dbg.assert(false, "androidFullscreen extension not found. rebuild quick binaries with this extension!")
else
    if androidFullscreen.isImmersiveSupported() then
        androidFullscreen.turnOn(true, true)
    end
end

require("Utility")

dofile("Globals.lua") --globals contains all our sensitive data so def want to precompile for some minimal security!
require("VirtualResolution")

if showFrameRate then
    dofile("FrameRate.lua")
end

-- garbage  defaults are both 200
collectgarbage("setpause", 200) -- wait between cycles (deafult of 200 = wait for memory use to increase by 2x) 
collectgarbage("setstepmul", 150) -- run cycles for less time (1.5x speed of memory allocation)

-- by default, try to keep each pixel scaling up to an integer size for crisp visuals
-- and have extra border area if needed
local nearestMultiple = true
local overrideW = nil
local overrideH = nil

-- Using virtual resolution with nearestMultiple (only use 1x, 2x, 3x, etc scaling)
-- Using ignoreMultipleIfTooSmall when upscaled height is < 0.9 of the screen width - in
-- that case, we just stretch and we go to 0.96 of the screen to leave a little
-- padding - looks nicer and guarantees a little space for finger gestures.
-- e.g. iPhone 4/4s retina resolution (960x640) would give 640x480 (1x scaling) with
-- a huge border without this.
-- For iPad mini, this logic would give nice 1->3 nearest Multiple scaling but finger
-- space is a little tight... so we limit width to 0.92 of screen and this will
-- stretch out and ignore nearestMultiple in that case.

virtualResolution:initialise{userSpaceW=appWidth, userSpaceH=appHeight, nearestMultiple=nearestMultiple,
    windowOverrideW=overrideW, windowOverrideH=overrideH, ignoreMultipleIfTooSmall = 0.9, forceScale=0.96, maxScreenW=0.9}
--virtualResolution:scaleTouchEvents(true) -- not using as not very stable or fast!

-- default values to allow turning off VR for testing
screenWidth = director.displayWidth
screenHeight = director.displayHeight

-- Re-setup virtual resolution on rotation events
function adaptToOrientation(event)
    if event then --avoid apply to default scene on startup
        virtualResolution:update()
        virtualResolution:applyToScene(director:getCurrentScene())
    end
    
    -- User space values of screen edges: for detecting edges of full screen area, including letterbox/borders
    -- Useful for positioning things like the title screen hills just on the screen no matter the resolution
    screenWidth = virtualResolution:winToUserSize(director.displayWidth)
    screenHeight = virtualResolution:winToUserSize(director.displayHeight)
end
adaptToOrientation()

----------------------------------------------------------
-- "offscreen" texure for applying effects, can be used by any scene

function fullscreenEffectsReset(self)
    dbg.print("resetting render texture")
    if self.screenFxTimer then
        self.screenFxTimer:cancel()
        self.screenFxTimer = nil
    end
    if self.screenFx then
        self.screenFx = destroyNode(self.screenFx)
    end
    if self.rt then
        self.rt = self.rt:removeFromParent()
    end
end

clearCol = quick.QColor:new()
clearCol.r = 1
clearCol.g = 1
clearCol.b = 1
clearCol.a = 255
--clearCol = color.darkBlue

local fxFrameLock = 0

function visitChildren(obj, scene)
    for k,v in pairs(obj.children) do
        v:visit()
    end
    visitChildren(v, scene)
end

function fullscreenEffectsUpdate(self)
    if not self.rt or self.effectSkipFlag or self.pauseRt then
        return
    end

    -- update render texture with whole scene every frame
    if self.rtWorkaround then
        --workaround for getSprite texture being in wrong place on fitst frame: make sure first frame is empty!
        self.rtWorkaround = nil
    else
        if self.rtDontClear then
            self.rt:begin(nil)
            --pick up the old image.. the screen burn type effect is awesome so keep it!
        else
            self.rt:begin(clearCol)
        end
        --self.screenFx.isVibile = false
        self:visit()
        --visitChildren(self.scalerRootNode, self)
        --self.screenFx.isVibile = true
        
        self.rt:endToLua()
    end
end

function fullscreenEffectsStop(self)
    if self.screenFx then
        cancelTweensOnNode(self.screenFx)
        cancelTimersOnNode(self.screenFx)
        self.pauseRt = true
    end

    if self.screenFxTimer then
        self.screenFxTimer:cancel()
        self.screenFxTimer = nil
    end
end

function fullscreenEffectsOff(self)
    if self.screenFx then
        self.screenFx = destroyNode(self.screenFx) --cancel tweens etc
    end
    if self.rt then
        self.rt = self.rt:removeFromParent()
    end
    
    self.pauseRt = nil
end

----------------------------------------------------------

function addArrowButton(scene, btnType, listener, backKeyListener, x, y, startAlpha) --types are "back", "left", "right"
    local xPos
    local yPos
    local rotation
    local btnName = btnType .. "Btn"
    if btnType == "left" then
        xPos = x or scene.screenMinX + 75
        yPos = y or appHeight*0.6
        rotation = 90
    elseif btnType == "right" then
        xPos = x or scene.screenMaxX - 75
        yPos = y or appHeight*0.6
        rotation = 270
    elseif btnType == "up" then
        xPos = x or appWidth/2
        yPos = y or 80
        rotation = 180
    elseif btnType == "down" then
        xPos = x or appWidth/2
        yPos = y or 80
        rotation = 0
    else
        dbg.assert(false, "invalid button type in addArrowButton")
    end
    
    if backKeyListener then
        sceneMainMenu.backKeyListener = listener
        system:addEventListener("key", backKeyListener)
    end

    scene[btnName] = director:createLines({x=xPos, y=yPos, coords={-50,30, 0,0, 50, 30}, strokeColor=menuBlue, strokeWidth=2, alpha=0, rotation=rotation, strokeAlpha=startAlpha or 1})
    local infoBack2 = director:createLines({y=-20, coords={-50,30, 0,0, 50, 30}, strokeColor=menuBlue, strokeWidth=2, alpha=0})
    
    scene[btnName].button = director:createRectangle({x=-60, y=-30, w=120, h=70, alpha=0, strokeColor=color.blue, zOrder = 10, isVisible=showDebugTouchArea})
    
    scene[btnName]:addChild(infoBack2)
    scene[btnName]:addChild(scene[btnName].button)
    scene[btnName].button:addEventListener("touch", listener)
    tween:to(scene[btnName], {strokeAlpha=0.1, xScale=1.5, yScale=1.5, time=1.0, mode="mirror"})
    
    return scene[btnName]
end

function removeArrowButton(scene, btnType, listener, backKeyListener)
    local btnName = btnType .. "Btn"
    if not scene[btnName] then
        dbg.print("Ignoring request to remove non existing arrow btn: " .. btnName)
        return
    end
    
    if backKeyListener then
        system:removeEventListener("key", backKeyListener)
        sceneMainMenu.backKeyListener = nil
    end
    
    scene[btnName].button:removeEventListener("touch", listener)
    scene[btnName] = scene[btnName]:removeFromParent()
end


----------------------------------------------------------

require("MenuScene") -- precompile MenuScene.lua fails for unknown reason with this file, so avoiding with require()
--dofile("GameScene.lua") -- doing this later to save a little bit of load time on platforms that load slower

analytics:setKeys(flurryApiKeyAndroid, flurryApiKeyIos)
analytics:startSessionWithKeys()

analytics:logEvent("userInfo", {appVersion=appVersion, devUserName=device:getInfo("name"), deviceID=device:getInfo("deviceID"), platform=device:getInfo("platform"), platVersion=device:getInfo("platformVersion"), arch = device:getInfo("architecture"), mem=device:getInfo("memoryTotal"), lang=device:getInfo("language"), locale=device:getInfo("locale")})

if useAdverts then
    ads:init()
end

--device:enableVibration()

director:moveToScene(sceneMainMenu)

function shutDownApp()
    dbg.print("Exiting app")
    system:quit()
end

function shutDownCleanup(event)
    dbg.print("Cleaning up app on shutdown")
    audio:stopStream()
    analytics:endSession()
end

system:addEventListener("exit", shutDownCleanup)


-- Note: We have lots of "classes" with Quick nodes as values. Would be nice to
--   actually "override" the node, but would need some convoluted multiple 
--   inheritance solution to work with lua userdata types. If doable, will have
--   the advantage that things like tweens and timers get a hook to the root
--   object and can destroy themselves without aditional look-ups.