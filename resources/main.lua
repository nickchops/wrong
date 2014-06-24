-- NB: Quick supports makePrecompiledLua etc if using dofile(), but not require()
-- So, for good performance but with some ease of code reuse, I'm using
-- dofile for big one-off inlcudes and require otherwise

androidFullscreen:turnOn(true, true)
-- turn on as early as possible. screen size won't update till bar is gone

require("Utility")

dofile("Globals.lua") --globals contains all our sensitive data so def want to precompile for some minimal security!
require("VirtualResolution")

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

-- User space values of screen edges: for detecting edges of full screen area, including letterbox/borders
-- Useful for positioning things like the title screen hills just on the screen no matter the resolution
screenWidth = virtualResolution:winToUserSize(director.displayWidth)
screenHeight = virtualResolution:winToUserSize(director.displayHeight)

-- These are for game scene, not menu
screenMaxX = screenWidth/2
screenMinX = -screenMaxX
screenMaxY = screenHeight/2
screenMinY = -screenMaxY

require("MenuScene") -- precompile MenuScene.lua fails for unknown reason with this file, so avoiding with require()
dofile("GameScene.lua")

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