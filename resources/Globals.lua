-------------------------------------------------------------------
-- Debugging --

--DEBUG_OVERRIDE_TYPE = "cloak"
showDebugTouchArea = false --cant be nil, nil -> ignored!
--showFrameRate = true

--require("mobdebug").start() -- ZeroBrain IDE debuger support
                   
    -- note: seems you can only use breakpoints in code loaded *after* this,
    -- therefore breakpoints in engine code will be ignored. TODO: check this
    -- is true! may have just been issue with older ZB version...

--debugGoSlow = true -- flag to manually make changes during debugging for things we want/need
                     -- to run slowly...

----------------------------------------------------------------------

require("helpers/Utility")

DEFAULT_HEALTH_BATTLE = 13
DEFAULT_HEALTH_SURVIVAL = 8
DEFAULT_BULLETS_BATTLE = 5
DEFAULT_AMMO_BATTLE = 1
DEFAULT_AMMO_BATTLE_DEMO = 5
DEFAULT_AMMO_WAVES = 0
DEFAULT_AMMO_SURVIVAL = 3

SECOND_BALL_SPEED = 14 --pixels/second - subsequent balls increase by NEW_BALL_SPEED_INCREASE
FIRST_BALL_SPEED = 110 --first few balls should be fast to keep play interesting
INITIAL_BALL_QUEUE = 4
INITIAL_BALL_DELAY = 0.6
MAX_INIT_BALLS = 7
INTIAL_NEW_BALL_DELAY = 7.5 --seconds between adding balls
NEW_BALL_DELAY_STEP = 0.65 --delay increments by 0.7 seconds per wave
MAX_WAVE_SIZE = 18
MAX_NEW_BALL_DELAY = 12
--max time is couple of secs for first 7 balls + (18-7)*12 for rest. = about 134 seconds

FIGHT_NEW_BALL_DELAY = 12
REPLACE_BALL_DELAY = 0.3 -- seconds between replacing destroyed balls
NEW_BALL_SPEED_INCREASE = 4.5
REPLACE_BALL_SPEED_INCREASE = 1
MAX_BALL_WAVE_START_SPEED = 60
MAX_BALL_SPEED = 150
POWERUP_FOR_NEXT_WEAPON = 4

INIT_WAVE_SIZE = 7
INITIAL_WAVE = 1 --use to debug starting on other wave numbers

-- Quick global switches ---------------------------------------------

demoMode = false      -- in demo right now
demoAvailable = true  -- demo is available
demoModeDebug = false --can still interact ir
DEMO_TIMEOUT = 10

------------------
director.isAlphaInherited = true -- the default in Quick 1.0 but not in Quick beta
pauseflag = false -- flag to work around Quick's pause-resume bug/quirk
------------------

local platform = device:getInfo("platform")
local deviceId = device:getInfo("deviceID")

dofile("helpers/PlatformStoreInfo.lua")
local versionMajor,versionMinor = getPlatformVersion()

-- Somewhat hacky at the moment! Uping some graphic features, notably the amount of stars
-- (more nodes=more work) on faster devices
performanceLevel = 1
local iosIsNew = false
if platform == "IPHONE" then
    if string.startswith(deviceId, "iPad") then
        if tonumber(string.sub(deviceId, 5, 5)) > 3 then --ipad4,x (mini retina) or newer
            iosIsNew = true
        end
    elseif string.startswith(deviceId, "iPhone") then
        if tonumber(string.sub(deviceId, 5, 5)) > 5 then --iphone6,x (iphont 5s) or newer
            iosIsNew = true
        end
    end
    -- These are the first iOS devices with the new PowerVR G6430 GPUs.
end
if platform == "OSX" or platform == "WINDOWS" or platform == "WS8" or platform == "WS81" or iosIsNew then
    performanceLevel = 2
end

deviceIsTouch = true -- TODO: for controllers set to false. For Windows Surface etc, need both! Not yet used.

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

fontMainLarge = "fonts/dosfont32.fnt"
fontMainSmall = "fonts/dosfont16.fnt"
fontDefault = "fonts/Default.fnt"


ballRadius = 8
sledExpandSize = 10
initSledHalfHeight = 21
initSledWidth = 8
maxSledExpand = 4
maxSledHalfHeight = initSledHalfHeight + sledExpandSize*maxSledExpand

-----------------

weapons = {"bullet", "ball", "air", "expander", "freezer", "heatseeker", "reverser"}
collidableColours = {powerup=color.green, cloak=color.yellow, health=color.red, bullet={188,60,188}, ball={180,180,255}, air=color.red, expander=color.green, freezer=color.aqua, heatseeker=color.grey, reverser=color.yellow}
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

dpiScaler = dofile("helpers/PixelDensity.lua")
dpiScaler:setReferenceDpi(216)

--Gating factors for touch control. Must move faster than this for touch to cause movement
--In screen pixels, not user space, which makes sense as this shouldnt relate to visuals
MIN_TOUCH_MOVE_Y = dpiScaler:getSize(50)
MIN_TOUCH_MOVE_X = dpiScaler:getSize(100) --same for weapon change

-- How many pixels finger must move per weapon change in a swipe. First change happens with X > MIN_TOUCH_MOVE_X,
-- second happens when x > WEAPON_MOVE_AMOUNT_X, third on x > WEAPON_MOVE_AMOUNT_X*2, etc.
-- TODO: needs to be 1st=100, 2nd=90, 3rd=60, 4th+=30 so first two are hard and then progressively easier
WEAPON_MOVE_AMOUNT_X = dpiScaler:getSize(90)

---------------------------------------------------------------------
-- Control which ball types appear in which waves and how often

--non-bomb/blue types allowed
ALLOWED_BALLS_IN_WAVE = {
    {}, --1
    {"powerup", "powerup", "powerup", "health"}, --2
    {"cloak", "cloak", "heatseeker", "heatseeker", "heatseeker"}, --3
    {"bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "bullet", "health"}, --4
    {"powerup", "cloak", "heatseeker", "heatseeker", "heatseeker"}, --5
    {"powerup", "powerup", "health", "freezer", "freezer", "freezer"}, --6
    {"expander-up", "expander-up", "expander-up", "expander-up", "health", "powerup"}, --7
    {"powerup", "heatseeker", "heatseeker", "heatseeker"}, --8
    {"health", "heatseeker", "cloak", "cloak", "bullet", "bullet", "freezer", "freezer"}, --9
    {"reverser", "reverser", "reverser", "health"}, --10
    {"reverser", "heatseeker", "powerup", "heatseeker", "reverser"}, --11
    {"powerup", "health", "cloak", "bullet", "bullet", "heatseeker", "heatseeker", "expander-up", "expander-up","reverser", "freezer"} --12
}

MAX_MANAGED_WAVE = table.getn(ALLOWED_BALLS_IN_WAVE)

--also check sceneGame:setBallOverrides() where specific types are set for exact obj instances!

SURVIVAL_UNLOCKED_WAVE = MAX_MANAGED_WAVE + 1
BATTLE_UNLOCKED_STREAK = 25

BALL_PROBABILITY_IN_WAVE = { --effectively inserts this number of blue "ball" types into the tables above
    1, --1
    5, --2
    5, --3
    5, --4
    5, --5
    8, --6
    5, --7
    2, --8
    3, --9
    5, --10
    3, --11
    4  --12
}

POWERUP_PROBABILITY_IN_WAVE = {}
for k,v in pairs(ALLOWED_BALLS_IN_WAVE) do
    POWERUP_PROBABILITY_IN_WAVE[k] = table.getn(ALLOWED_BALLS_IN_WAVE[k])
end

---------------------------------------------------------------------

-- Global struct for most progress data
gameInfo = {}
gameInfo.playerColours = {}
gameInfo.score = 0
gameInfo.streak = 0
gameInfo.maxStreak = 0
gameInfo.mode = "waves"
gameInfo.soundOn = true
gameInfo.soundFxOn = true
gameInfo.titleMusicPlaying = false
gameInfo.shouldLogIntoGameServices = true

gameInfo.useFullscreenEffects = true

gameInfo.leaderboardsServiceIds = {
    waves =    {googlePlay = "CgkI37a3vLQYEAIQDA"},
    survival = {googlePlay = "CgkI37a3vLQYEAIQDQ"},
    streak =   {googlePlay = "CgkI37a3vLQYEAIQDg"} }

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

gameInfo.achievementServiceIds = {
    wave6 =      {googlePlay = "CgkI37a3vLQYEAIQAg", gameCircle=""},
    survival =   {googlePlay = "CgkI37a3vLQYEAIQAw", gameCircle=""},
    wave15 =     {googlePlay = "CgkI37a3vLQYEAIQBA", gameCircle=""},
    wave20 =     {googlePlay = "CgkI37a3vLQYEAIQBQ", gameCircle=""},
    streak20 =   {googlePlay = "CgkI37a3vLQYEAIQBg", gameCircle=""},
    battle =     {googlePlay = "CgkI37a3vLQYEAIQBw", gameCircle=""},
    streak40 =   {googlePlay = "CgkI37a3vLQYEAIQCA", gameCircle=""},
    streak50 =   {googlePlay = "CgkI37a3vLQYEAIQCQ", gameCircle=""},
    survival40 = {googlePlay = "CgkI37a3vLQYEAIQCg", gameCircle=""},
    survival50 = {googlePlay = "CgkI37a3vLQYEAIQCw", gameCircle=""}}

gameInfo.achievements = {}
for k,v in ipairs(gameInfo.achievementIndex) do
    gameInfo.achievements[v] = false
end

-- uncomment to debug locked modes:
--gameInfo.achievements.survival=true
--gameInfo.achievements.battle=true

gameInfo.achievementPages = 0
local achCount = table.getn(gameInfo.achievementIndex) --NB, cant use .achievements as table.getn only works on arrays!
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

useAdverts = nil -- not yet used

--------

flurryApiKeyAndroid = "12345678"
flurryApiKeyIos =     "12345678"

--------

facebookAppId =  "12345678" --not used yet
facebookSecret = "12345678" --not used yet

-- Private keys/secrets for services are overridden here (this file is not in github!)
local pvt_keys = io.open("Globals_pvt.lua","r")
if pvt_keys ~= nil then
    io.close(pvt_keys)
    dofile("Globals_pvt.lua")
end
pvt_keys = nil

facebookUrl = "http://www.facebook.com/wrongapp"
twitterUrl = "http://twitter.com/nick_chops"

-----------

appId = "com.nickchops.wrong"
local vMajor, vMinor = getPlatformVersion()
storeUrl, storeName = getStoreUrl(platform, vMajor, vMinor, appId, "wrong!/id897361366")
blogUrl = "http://nickchops.github.io/wrong"

---------------------------------------------------------

sceneMainMenu = director:createScene()
sceneMainMenu.name = "MainMenu"
sceneGame = director:createScene()
sceneGame.name = "Game"

