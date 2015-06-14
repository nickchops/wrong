-------------------------------------------------------------------
-- Debugging --

--DEBUG_OVERRIDE_TYPE = "cloak"

showDebugTouchArea = false

showFrameRate = true

require("mobdebug").start() -- ZeroBrain IDE debuger support
                   
    -- note that you can only use breakpoints in code loaded *after* this, therefor breakpoints
    -- in engine code will be ignored. TODO: check this is true! may have just been issue with
    -- old ZB version...

--debugGoSlow = true -- flag to manaully make changes during debugging for things we want/need
                     -- to run slowly...

----------------------------------------------------------------------

require("Utility")

DEFAULT_HEALTH_BATTLE = 13
DEFAULT_HEALTH_SURVIVAL = 1 --8 (NSMITH temp for demo)
DEFAULT_BULLETS_BATTLE = 5
DEFAULT_AMMO_BATTLE = 1
DEFAULT_AMMO_WAVES = 0
DEFAULT_AMMO_SURVIVAL = 3 --3 (NSMITH temp for demo)

SECOND_BALL_SPEED = 13 --pixels/second. NB if 5 balls added at start, this ramps quickly up to 15+5*10
FIRST_BALL_SPEED = 110 --very first ball should be fast to keep play interesting
INITIAL_BALL_QUEUE = 4
INITIAL_BALL_DELAY = 0.6
MAX_INIT_BALLS = 7
INTIAL_NEW_BALL_DELAY = 7 --seconds between adding balls
MAX_NEW_BALL_DELAY = 12
FIGHT_NEW_BALL_DELAY = 12
REPLACE_BALL_DELAY = 0.3 -- seconds between replacing destroyed balls
NEW_BALL_SPEED_INCREASE = 4
REPLACE_BALL_SPEED_INCREASE = 1
MAX_BALL_WAVE_START_SPEED = 60
MAX_BALL_SPEED = 150
POWERUP_FOR_NEXT_WEAPON = 5

INIT_WAVE_SIZE = 7
INITIAL_WAVE = 1 --use this to debug starting on other wave numbers

-- Quick global switches ---------------------------------------------

demoMode = false      -- in demo right now
--demoAvailable = true  -- demo is available
demoModeDebug = false --can still interact ir
DEMO_TIMEOUT = 10

director.isAlphaInherited = true -- the default in Quick 1.0 but not in Quick beta

pauseflag = false -- flag to work around Quick's pause-resume bug/quirkh

local platform = device:getInfo("platform")
local deviceId = device:getInfo("deviceID")

-- string of form "OS name majorversion.minor.revision.etc" Could have spaces in
-- OS name; could have arbitrary number of points in version; version might be
-- a string like "XP2"! Following will work for Android and iOS...
local version = device:getInfo("platformVersion")
local versionMajor = nil
local versionMinor = nil
versionMajor, versionMinor = string.match(version, '%s([^%.%s]+)%.(.+)')
if versionMajor and versionMinor then
    versionMajor = tonumber(versionMajor)
    local minorMatch = string.match(versionMinor, '([^%.]+)%..+')
    if minorMatch then
        versionMinor = minorMatch
    end
    versionMinor = tonumber(versionMinor)
end

-- Somewhat hacky at the moment! we know certain devices that run really fast
-- so on those we are upping some graphic features, notably the amount of stars
-- (more nodes=more work)
performanceLevel = 1
if platform == "OSX" or platform == "WINDOWS" or platform == "WS8" or platform == "WS81" or 
        string.startswith(deviceId, "iPad4") or string.startswith(deviceId, "iPhone6") then
    -- These IDs are retina iPads and iPhone 5s - only devices with new PowerVR G6430 GPUs.
    -- TODO: make this work with newer models (>=ipad4 etc)
    performanceLevel = 2
end

--local deviceIsAndroid = platform == "ANDROID"
--local deviceIsX86 = device:getInfo("architecture") == "X86"

deviceIsTouch = true -- TODO: for cotrollers set to false. For Windows Surface etc, need a switch in the game! Not yet used.

-- virtual coordinates
appWidth = 640
appHeight = 480

minX = -appWidth/2
maxX = appWidth/2
minY = -appHeight/2
maxY = appHeight/2

menuGreen = {150,255,150}
menuBlue = {150,150,255}

achieveCol = color.orange
achieveLockedCol = {100,50,50}

ballRadius = 8
sledExpandSize = 10
initSledHalfHeight = 21
initSledWidth = 8
maxSledExpand = 4
maxSledHalfHeight = initSledHalfHeight + sledExpandSize*maxSledExpand

-----------------

weapons = {"bullet", "ball", "air", "expander", "freezer", "heatseeker", "reverser"}
collidableColours = {powerup=color.green, cloak=color.yellow, health=color.red, bullet=color.purple, ball={180,180,255}, air=color.red, expander=color.green, freezer=color.aqua, heatseeker=color.grey, reverser=color.yellow}
collidableColours["expander-up"]=color.green
collidableColours["expander-down"]=color.green
    --including all variations of "expander" for easy look up in dfferent functions
dashboardColours = {powerup = color.green, bullet = color.fuchsia, ball = {180,180,255}, air = color.red, expander = color.green, freezer = color.aqua, heatseeker = color.white, reverser = color.yellow} --slightly different to matching objects for better visibility
weaponCount = table.getn(weapons)

colorIndex = {}
for k,v in pairs(color) do
    table.insert(colorIndex, k)
end
numColors = table.getn(colorIndex)

-----------------

--Need to get DPI or vague equivalent to scale touch controls - thumb vs screen size.
--Prototyped game on Nexus 7 1st gen (216 DPI), so using that as dpiScale = 1
local dpiScale = nil

local dpiScaler = dofile("PixelDensity.lua")
dpiScaler:setReferenceDpi(216)

--Gating factors for touch control. Must move faster than this for touch to cause movement
--In screen pixels, not user space, which makes sense as this shouldnt relate to visuals
MIN_TOUCH_MOVE_Y = dpiScaler:getSize(50)
MIN_TOUCH_MOVE_X = dpiScaler:getSize(100) --same for weapon change

-- How many pixels finger must move per weapon change in a swipe. First change happens with X > MIN_TOUCH_MOVE_X,
-- second happens when x > WEAPON_MOVE_AMOUNT_X, third on x > WEAPON_MOVE_AMOUNT_X*2, etc.
-- TODO: needs to be 1st=100, 2nd=90, 3rd=60, 4th+=30 so first two are hard and then progressively easier
WEAPON_MOVE_AMOUNT_X = dpiScaler:getSize(90)

--TODO: prob want to use pixel density on flick movement scaling too,
-- i.e. deceleration
-- currenlty moves faster/further on high res devices than low ones.
-- want relatively fast on all devices...

---------------------------------------------------------------------
-- Control which powerups appear in which waves and how often

ALLOWED_BALLS_IN_WAVE = {
    {}, --1
    {"powerup", "health"}, --2
    {"health", "cloak", "cloak", "heatseeker", "heatseeker"}, --3
    {"bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "bullet"}, --4
    {"powerup", "cloak", "heatseeker", "heatseeker"}, --5
    {"powerup", "health", "freezer"}, --6
    {"expander-up", "expander-up", "expander-up", "expander-up", "health"}, --7
    {"powerup", "heatseeker", "heatseeker", "heatseeker"}, --8
    {"health", "health", "heatseeker", "cloak", "cloak", "bullet", "bullet", "freezer", "freezer"}, --9
    {"reverser", "reverser", "reverser", "health"}, --10
    {"reverser", "heatseeker", "powerup", "heatseeker", "reverser"}, --11
    {"powerup", "health", "cloak", "bullet", "bullet", "heatseeker", "heatseeker", "expander-up", "expander-up","reverser", "freezer"} --12
}

MAX_MANAGED_WAVE = table.getn(ALLOWED_BALLS_IN_WAVE)

SURVIVAL_UNLOCKED_WAVE = MAX_MANAGED_WAVE + 1
BATTLE_UNLOCKED_STREAK = 25

BALL_PROBABILITY_IN_WAVE = { --effectively inserts this number of "ball" types into the tables above
    1, --1
    2, --2
    3, --3
    1, --4
    4, --5
    3, --6
    2, --7
    2, --8
    2, --9
    5, --10
    3, --11
    3  --12
}

POWERUP_PROBABILITY_IN_WAVE = {}
for k,v in pairs(ALLOWED_BALLS_IN_WAVE) do
    POWERUP_PROBABILITY_IN_WAVE[k] = table.getn(ALLOWED_BALLS_IN_WAVE[k])
end

---------------------------------------------------------------------

gameInfo = {}
gameInfo.playerColours = {}
gameInfo.score = 0
gameInfo.streak = 0
gameInfo.maxStreak = 0
gameInfo.mode = "waves"
gameInfo.soundOn = true
gameInfo.titleMusicPlaying = false

gameInfo.useFullscreenEffects = true --currently off due to crash bug with GC on RenderTexture nodes

gameInfo.achievementIndex = {
    "wave6",
    "survival",
    "wave15",
    "wave20",
    "streak20",
    "battle",
    "streak40",
    "streak50",
    "survival40",
    "survival50"}

gameInfo.achievements = {}
for k,v in ipairs(gameInfo.achievementIndex) do
    gameInfo.achievements[v] = false
end
-- uncomment to debug locked modes:
gameInfo.achievements.survival=true
gameInfo.achievements.battle=true

gameInfo.achievementPages = 0
local achCount = table.getn(gameInfo.achievementIndex) --NB, cant use .achievements as .tablegetn only works on arrays!
while achCount > 0 do
    gameInfo.achievementPages = gameInfo.achievementPages+1
    achCount = achCount-10
end

gameInfo.achievementNames = {}
gameInfo.achievementNames.survival = {SURVIVAL_UNLOCKED_WAVE-1 .. " waves cleared...", "survival mode unlocked"}
gameInfo.achievementNames.battle = {"30 bomb streak...", "battle mode unlocked"}
gameInfo.achievementNames.wave6 = {"6 waves cleared"}
for n=15, 25, 5 do
    gameInfo.achievementNames["wave" .. n] = {n .. " waves cleared"}
end
for n=20, 50, 10 do
    if n~=30 then
        gameInfo.achievementNames["streak" .. n] = {n .. " bomb streak"}
    end
end
for n=40, 50, 10 do
    gameInfo.achievementNames["survival" .. n] = {"survival mode:", "survived " .. n .. " bombs "}
end

fontMainLarge = "fonts/dosfont32.fnt"
fontMainSmall = "fonts/dosfont16.fnt"
fontDefault = "fonts/Default.fnt"

-------------------------------------------
--Music

--tries to play index matching current wave
--if nil, tries recursively matching value in previous set of 6 waves (e.g. 14 -> 8 -> 2)
--if false, or recursive search never finds a value, doesn't play (track from previous wave keeps playing)
waveMusic = {
    "explorers.mp3",
    false,
    false,
    "voyager.mp3",
    false,
    "air-sharks.mp3",
    
    nil, --back to explorers
    "voyager-long.mp3", --fancier version!
    false,
    "air-sharks.mp3",
    false,
    "slums-of-rage.mp3"
}

effectSprites = {
    "textures/asteroid.png",
    "testures/spaceinvader.png",
    "textures/satellite.png",
    "textures/astronaut.png"
}
effectSpriteCount = table.getn(effectSprites)

-------------------------------------------
--Services

useAdverts = nil

--if ads:isAvailable() or platform == "WINDOWS" then
--    useAdverts="leadbolt"
--    advertType = "banner"
--    advertId = "832221981"
----    If using native OS SDKs then would use these, but QAds uses pure HTML "webapp" ads
----    if platform == "ANDROID" then
----        advertId = "316253506"
----    elseif platform == "IPHONE" then
----        advertId ="283301009"
----    end
--end

--------
flurryApiKeyAndroid = "QHYQHZ65GJB448TSJCG3"
flurryApiKeyIos = "R94C95YB7FSY4VRHQ9PD"
--------
--
facebookAppId = "236640686544406"
facebookScret = "49f2a9700f5511daa111250a4166b088"
facebookUrl = "http://www.facebook.com/wrongapp"
--
twitterUrl = "http://twitter.com/nick_chops"
--
appId = "com.nickchops.wrong"
storeUrl = nil
storeName = nil
if platform == "ANDROID" then
    storeUrl = "market://details?id=" .. appId
    storeName = "google"
    -- else storeName = "amazon" etc
elseif platform == "IPHONE" then
    appId = "wrong!/id897361366"
    storeName = "apple"
    if versionMajor >= 7 then
        storeUrl = "itms-apps://itunes.apple.com/app/" .. appId
    else
        storeUrl = "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=" .. appId .. "&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
    end
end

blogUrl = "http://nickchops.github.io/wrong-prototype"
---------------------------------------------------------

sceneMainMenu = director:createScene()
sceneMainMenu.name = "MainMenu"
sceneBattle = director:createScene()
sceneBattle.name = "Battle"

