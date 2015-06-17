
require("Utility")
require("NodeUtility")
dofile("OnScreenDPad.lua")
dofile("OnScreenButton.lua")

startupFlag = true -- for initial menu animation

-----------------------------------------------------------
-- Simple helper to add more text to screen

function CreateTextDisplay(xLeft, yTop, width, height, strings, paragraphGapSize, colour, scale, font)
    local textOrigin = director:createNode({x=xLeft, y=yTop-height})
    textOrigin.xLeft = xLeft
    textOrigin.xRight = xLeft + width
    textOrigin.xTextRight = 0
    textOrigin.yTop = yTop
    textOrigin.yBottom = yTop - height
    textOrigin.yTextBottomWithParaGap = height
    
    font = font or fontMainSmall
    
    for k,v in pairs(strings) do
        local para = director:createLabel({x=0, y=0, w=width/scale, h=height/scale, hAlignment="left", vAlignment="bottom", color=colour, xScale=scale, yScale=scale, font=font,
        text=v})
        
        if textOrigin.xTextRight < para.wText then
            textOrigin.xTextRight = para.wText
        end

        para.y = textOrigin.yTextBottomWithParaGap - para.hText
        textOrigin.yTextBottom = para.y
        textOrigin.yTextBottomWithParaGap = para.y - paragraphGapSize

        textOrigin:addChild(para)
    end

    textOrigin.xTextRight = textOrigin.xTextRight + xLeft
    textOrigin.yTextBottom = textOrigin.yTextBottom + textOrigin.y
    textOrigin.yTextBottomWithParaGap = textOrigin.yTextBottomWithParaGap + textOrigin.y

    return textOrigin
end

function DestroyTextDisplay(textOrigin)
    for k,v in pairs(textOrigin.children) do
        v:removeFromParent()
    end
    textOrigin = textOrigin:removeFromParent()
end

------------------------------------------------------------------
-- "about" screen show/hide 

-- build info screen objects once. This was all quite slow due to font loading
-- and having to generate the text and then calaulate sizes between each paragraph.
-- So, to improve we only do the setup one and distroy on scene exit, plus animate
-- a chunk at a time which add to retro style anyway
function sceneMainMenu:DisplayInfoText()
    if not self.infoText then
        self.infoText = {}
        self.infoTextWait = 1.2 -- compensate for slowdown on very first load
        self.infoTextStage = 1 --function called recursively for each "stage" of text
    end
    
    local stage = self.infoTextStage
    
    if stage == 2 then
        self.infoTextWait = 0
    end
        
    if stage == 4 then
        self.infoTextStage = 1
        system:addTimer(menuAddAboutBackButton, 0.3, 1)
        return
    end
    
    if not self.infoText[stage] then
        local txtWidth = appWidth-60
        local txtStrings
        local txtColour = menuGreen
        local txtFont = nil
        local txtStartX = 30
        local startPos
        
        if stage == 1 then
            startPos = appHeight-25
        else
            startPos = self.infoText[stage-1].yTextBottomWithParaGap
        end
          
        if stage == 1 then
            txtStrings = {
                "WRONG: it's Weaponised Reverse xONG, of course!",
                "Marvel at the state of the art 1970s vector graphics, while playing (something that looks coincidentally a little like, but legally isn't) pong, against yourself, in reverse, with guns... Wrong!",
                "How to play: Don't try and bounce those explosive balls; score points by avoiding them. Build your ammo level over 5 for one weapon to unlock the next one. Unlock achievements to get new modes.",
                "This game was built by one guy in his spare time using Marmalade Quick, a 2D Lua-based engine. And it's free, 'cause I'm nice like that:"}
            
        elseif stage == 2 then
            txtColour = menuBlue
            
            if browser:isAvailable() then
                txtStrings = {"> BLOG & SOURCE CODE FOR WRONG"}
                txtFont = fontMainLarge
                txtStartX = 60
                txtWidth = appWidth-90
            else
                txtStrings = {blogUrl}
            end
        
        elseif stage == 3 then
            txtStrings = {"Please like, criticise, report bugs and request features on the Facebook page. The brilliant/annoying music is courtesy of playonloop.com"}
        end
        
        self.infoText[stage] = CreateTextDisplay(txtStartX, startPos, txtWidth, startPos-50, txtStrings, 20, txtColour, 1, txtFont)
    end
    
    if stage == 2 and browser:isAvailable() then
        sceneMainMenu.infoButtonUrl = director:createRectangle({x = self.infoText[stage].xLeft, y = self.infoText[stage].yTextBottom, w=self.infoText[stage].xTextRight - self.infoText[stage].xLeft, h = self.infoText[stage].yTop - self.infoText[stage].yTextBottom, alpha=0, strokeColor=color.blue, zOrder = 10, isVisible=showDebugTouchArea})
        sceneMainMenu.infoButtonUrl:addEventListener("touch", goToBlog)
    end
    
    self.infoText[stage].alpha = 0
    self.infoTextStage = self.infoTextStage+1
    tween:to(self.infoText[stage], {alpha=1, time=1, delay=self.infoTextWait, onComplete=menuDisplayAbout})
end

function menuDisplayAbout()
    sceneMainMenu.title.nextMenu = nil
    sceneMainMenu.title.menuTween = nil
    sceneMainMenu:restartFlicker()
    sceneMainMenu:DisplayInfoText()
end

function menuCloseAbout(event)
    if event.phase == "ended" then
        sceneMainMenu.subMenu = nil
        if sceneMainMenu.infoButtonUrl then
            sceneMainMenu.infoButtonUrl:removeEventListener("touch", goToBlog)
            sceneMainMenu.infoButtonUrl = sceneMainMenu.infoButtonUrl:removeFromParent()
        end
        removeArrowButton(sceneMainMenu, "down", menuCloseAbout, menuBackKeyListener)

        for k,v in pairs(sceneMainMenu.infoText) do
            tween:to(v, {alpha=0, time=0.5})
        end
        tween:to(sceneMainMenu.title, {y=sceneMainMenu.titleY, xScale=1, yScale=1, time=1.0, delay=0.3, onComplete=showMainMenu})
    end
end

function menuAddAboutBackButton(event)
    addArrowButton(sceneMainMenu, "down", menuCloseAbout, menuBackKeyListener)
end

function sceneMainMenu:DestroyInfoText()
    if self.infoText then
        for k,v in pairs(self.infoText) do
            DestroyTextDisplay(v)
        end
        self.infoText = nil
        self.infoTextStage = nil
    end
end
-------------------------------------------------------------
-- high scores screen show/hide 

function menuAddScore(event)
    local scoreNum = event.doneIterations
    local labelX = appWidth/2
    local labelY = appHeight/2+165-30 - scoreNum*20
    local scoreText = gameInfo.highScore[event.timer.mode][scoreNum].name .. "  " .. string.format("%08d", gameInfo.highScore[event.timer.mode][scoreNum].score)
    
    if event.timer.mode ~= sceneMainMenu.scoreMenuState then
        if event.timer.mode == "waves" or
                (event.timer.mode == "survival" and sceneMainMenu.scoreMenuState == "streak") then
            labelX = sceneMainMenu.screenMinX - 100
        else
            labelX = sceneMainMenu.screenMaxX + 100
        end
    end
    
    sceneMainMenu.scoreLabels[event.timer.mode][scoreNum] = director:createLabel({x=labelX, y=labelY, w=250, h=50, xAnchor=0.5, yAnchor=0, hAlignment="center", vAlignment="bottom", text=scoreText, color=menuBlue, font=fontMainSmall})
    
    --if not gameInfo.newHighScore then gameInfo.newHighScore = 3 end --for debugging
    
    if (event.timer.mode == sceneMainMenu.scoreMenuState and gameInfo.newHighScore == scoreNum) or
        (event.timer.mode == "streak" and gameInfo.newHighStreak == scoreNum) then
        sceneMainMenu.scoreLabels[event.timer.mode][scoreNum].color={200,200,255}
    end
    
    if scoreNum == 10 and event.timer.mode == sceneMainMenu.scoreMenuState then
        if gameInfo.newHighScore then
            sceneMainMenu:showNameEntry()
        else
            sceneMainMenu:activateScoreArrowButtons()
        end
    end
end

function sceneMainMenu:activateScoreArrowButtons()
    addArrowButton(self, "down", menuCloseHighScores, menuBackKeyListener)
    
    if gameInfo.achievements.survival then
        if self.scoreMenuState == "waves" then
            addArrowButton(self, "right", menuShowSurvivalScores)
        elseif self.scoreMenuState == "survival" then
            addArrowButton(self, "left", menuShowWavesScores)
            addArrowButton(self, "right", menuShowStreakScores)
        else --streak
            addArrowButton(self, "left", menuShowSurvivalScores)
        end
    else
        if self.scoreMenuState == "waves" then
            addArrowButton(self, "right", menuShowStreakScores)
        else --streak
            addArrowButton(self, "left", menuShowWavesScores)
        end
    end
end

function sceneMainMenu:showNameEntry()
    sceneMainMenu.inputAnim = tween:to(sceneMainMenu.scoreLabels[self.scoreMenuState][gameInfo.newHighScore], {time=0.3, alpha=0, mode="repeat"})
    
    -- input chars
    self.nameChars = {" ","_","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T",
                 "U","V","X","Y","Z","0","1","2","3","4","5","6","7","8","9","!","-","."}
    
    --make a reverse table to get index from character
    local nameCharLookup = {}
    for k,v in ipairs(self.nameChars) do
        nameCharLookup[v] = k
    end

    self.nameChars.size = table.getn(self.nameChars) --precalculate array size
    
    -- counter to hold char indices, refering to a index of nameChars
    self.nameInput = {nameCharLookup[gameInfo.name:sub(1,1)], nameCharLookup[gameInfo.name:sub(2,2)], nameCharLookup[gameInfo.name:sub(3,3)]}
    
    self.nameInput.size = table.getn(self.nameInput)
    self.nameIndex = 1
    setScoreLabel()
    
    -- controls
    self.joystick = OnScreenDPad.Create{x=self.screenMinX+90, y=180, padType="joystick", topRadius=45, baseRadius=120, resetOnRelease=true, moveRelative=true, relocate=false, debugCircles=false}
    self.scoreSaveButton = OnScreenButton.Create{x=self.screenMaxX-90, y=90, radius=40, topColor={0,200,0}, outline={0,170,0}, baseColor={0,130,0}, scale3d=0.4, depth3d=8, autoRelease=0.35}
    
    self.scoreSaveButton:setPressListener(menuSaveScoreName)
    
    tween:from(self.joystick.origin, {x=self.screenMinX-100, time=1.5})
    tween:from(self.scoreSaveButton.origin, {x=self.screenMaxX+100, onComplete=menuEnterNameForScore, time=1.5})
end

function menuEnterNameForScore()
    sceneMainMenu.joystick:activate()
    sceneMainMenu.scoreSaveButton:activate()
    
    sceneMainMenu.backKeyListener = menuSaveOnBackKey --alow android etc back key to press save button
    system:addEventListener("key", menuBackKeyListener)
    
    -- poll at intervals so stick position slowly changes selected character
    sceneMainMenu.joyTimer = system:addTimer(menuCheckNameInput, 0.25, 0)
end

function setScoreLabel()
    --set label and actual score here
    local name = sceneMainMenu.nameChars[sceneMainMenu.nameInput[1]] ..
        sceneMainMenu.nameChars[sceneMainMenu.nameInput[2]] ..
        sceneMainMenu.nameChars[sceneMainMenu.nameInput[3]]
    
    gameInfo.highScore[sceneMainMenu.scoreMenuState][gameInfo.newHighScore].name = name
    
    sceneMainMenu.scoreLabels[sceneMainMenu.scoreMenuState][gameInfo.newHighScore].text = name .. "  " .. string.format("%08d", gameInfo.highScore[sceneMainMenu.scoreMenuState][gameInfo.newHighScore].score)
    
    --set streak score if also got that at same time
    if sceneMainMenu.scoreMenuState ~= "streak" and gameInfo.newHighStreak then
        gameInfo.highScore["streak"][gameInfo.newHighStreak].name = name
        sceneMainMenu.scoreLabels["streak"][gameInfo.newHighStreak].text = name .. "  " .. string.format("%08d", gameInfo.highScore["streak"][gameInfo.newHighStreak].score)
    end
end

function menuCheckNameInput(event)
    local yChange = sceneMainMenu.joystick:getY()
    local xChange = sceneMainMenu.joystick:getX()
    
    -- cancel x change if would do nothing
    if (xChange > 0 and sceneMainMenu.nameIndex == sceneMainMenu.nameInput.size) or
            (xChange < 0 and sceneMainMenu.nameIndex == 1) then
        xChange = 0
    end
    
    if math.abs(yChange) > math.abs(xChange) then 
        xChange = 0
    else
        yChange = 0
    end
    
    if yChange ~=0 then -- cycle through values for currently selected char
        local incr = 1
        if yChange < 0 then
            incr = -1
        end
        local newCharId =
            circularIncrement(sceneMainMenu.nameInput[sceneMainMenu.nameIndex], sceneMainMenu.nameChars.size, incr)
        dbg.print("Cycle char at (" .. tostring(sceneMainMenu.nameIndex) .. ") to: #" .. newCharId ..
                " = '" .. sceneMainMenu.nameChars[newCharId] .."'")
        sceneMainMenu.nameInput[sceneMainMenu.nameIndex] = newCharId
        
    elseif xChange ~= 0 then --switch which character to change
        local incr = 1
        if xChange < 0 then
            incr = -1
        end
        sceneMainMenu.nameIndex = sceneMainMenu.nameIndex + incr
        dbg.print("Switch to char index: " .. tostring(sceneMainMenu.nameIndex))
        sceneMainMenu.nameInput[sceneMainMenu.nameIndex] = 2 -- reset to indicate column was selected
        for n=sceneMainMenu.nameIndex+1, sceneMainMenu.nameInput.size do
            sceneMainMenu.nameInput[n] = 1
        end
    end
    
    if xChange ~= 0 or yChange ~= 0 then
        setScoreLabel()
    end
end

function menuSaveOnBackKey(event)
    menuSaveScoreName(false)
end

function menuSaveScoreName(buttonDown)
    if not buttonDown then
        dbg.print("score save button released!")
        sceneMainMenu.joyTimer:cancel()
        sceneMainMenu.joyTimer=nil
        sceneMainMenu.joystick:deactivate()
        sceneMainMenu.scoreSaveButton:deactivate()
        system:removeEventListener("key", menuBackKeyListener)
        sceneMainMenu.backKeyListener = nil
        tween:to(sceneMainMenu.joystick.origin, {x=sceneMainMenu.screenMinX-100, time=1.0})
        sceneMainMenu.newDontClear = true -- flashy effects back on once controls done with
        tween:to(sceneMainMenu.scoreSaveButton.origin, {x=sceneMainMenu.screenMaxX+100, time=1.0, onComplete=menuRemoveScoreControls})
        tween:cancel(sceneMainMenu.inputAnim)
        sceneMainMenu.scoreLabels[sceneMainMenu.scoreMenuState][gameInfo.newHighScore].alpha=1
        gameInfo.name = gameInfo.highScore[sceneMainMenu.scoreMenuState][gameInfo.newHighScore].name -- store last name entered
        
        menuSaveData(true)
        analytics:logEvent("saveData", {scoreName=gameInfo.name})
        sceneMainMenu:activateScoreArrowButtons()
        sceneMainMenu.nameChars = nil
    else
        dbg.print("score save button pushed!")
    end
end

function menuRemoveScoreControls()
    sceneMainMenu.joystick:destroy()
    sceneMainMenu.scoreSaveButton:destroy()
    sceneMainMenu.joystick = nil
    sceneMainMenu.scoreSaveButton = nil
end

function menuDisplayHighScoreScreen(target)
    sceneMainMenu.title.nextMenu = nil
    sceneMainMenu.title.menuTween = nil
    
    if not sceneMainMenu.scoreMenuState then
        sceneMainMenu.scoreMenuState = gameInfo.mode
    end
    
    sceneMainMenu.scoreLabels = {waves={}, survival={}, streak={}}
    sceneMainMenu.scoreLabels.title = director:createLabel({x=appWidth/2, y=appHeight/2+165, w=250, h=50, xAnchor=0.5,
            yAnchor=0, hAlignment="center", vAlignment="bottom", text="HIGH SCORES", color=menuBlue, font=fontMainLarge})
    
    if sceneMainMenu.scoreMenuState == "survival" then
        sceneMainMenu.scoreLabels.title.text = "SURVIVAL MODE"
    elseif sceneMainMenu.scoreMenuState == "streak" then
        sceneMainMenu.scoreLabels.title.text = "LONGEST STREAK"
    end
    
    sceneMainMenu:restartFlicker()
    
    if sceneMainMenu.sceneShown then
        sceneMainMenu:displayHighScores()
    else
        dbg.print("sceneMainMenu.sceneShown is FALSE")
    end
end

function sceneMainMenu:displayHighScores()
    -- build list of scores for current mode - ie the one the user last played or the one they just got a high score with
    -- This can be "streak" if they got a streak high score but not a waves or survival one
    
    local scoreTimer = system:addTimer(menuAddScore, 0.15, 10, 0.3)
    scoreTimer.mode = self.scoreMenuState
    
    -- build other mode scores off screen
    
    scoreTimer = system:addTimer(menuAddScore, 0.1, 10, 0.3)
    if self.scoreMenuState == "waves" then
        scoreTimer.mode = "survival"
    else --survival or streak
        scoreTimer.mode = "waves"
    end
    
    scoreTimer = system:addTimer(menuAddScore, 0.1, 10, 0.3)
    if self.scoreMenuState == "streak" then
        scoreTimer.mode = "survival"
    else --waves or survival
        scoreTimer.mode = "streak"
    end

end
------

function menuShowSurvivalScores(event)
    if event.phase == "ended" then
        sceneMainMenu.scoreMenuState = "survival"
        removeArrowButton(sceneMainMenu, "right", menuShowSurvivalScores)
        removeArrowButton(sceneMainMenu, "left", menuShowSurvivalScores)
        removeArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
        sceneMainMenu.scoreLabels.title.text = "SURVIVAL MODE"
        
        --lazily tween both to allow this funciton to be called from either left or right
        for k, v in pairs(sceneMainMenu.scoreLabels.waves) do
            tween:to(v, {x=sceneMainMenu.screenMinX - 100})
        end
        for k, v in pairs(sceneMainMenu.scoreLabels.streak) do
            tween:to(v, {x=sceneMainMenu.screenMaxX + 100})
        end
        
        for k, v in pairs(sceneMainMenu.scoreLabels.survival) do
            if k == 10 then
                tween:to(v, {x=appWidth/2, onComplete=menuShowSurvivalScoresDone})
            else
                tween:to(v, {x=appWidth/2})
            end
        end
    end
end

function menuShowSurvivalScoresDone()
    addArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
    addArrowButton(sceneMainMenu, "left", menuShowWavesScores)
    addArrowButton(sceneMainMenu, "right", menuShowStreakScores)
end
------

function menuShowStreakScores(event)
    if event.phase == "ended" then
        sceneMainMenu.scoreMenuState = "streak"
        removeArrowButton(sceneMainMenu, "left", menuShowWavesScores) --safe to try remove this if doesnt exist
        removeArrowButton(sceneMainMenu, "right", menuShowStreakScores)
        removeArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
        sceneMainMenu.scoreLabels.title.text = "LONGEST STREAK"
        
        for k, v in pairs(sceneMainMenu.scoreLabels.waves) do
            tween:to(v, {x=sceneMainMenu.screenMinX - 100})
        end
        if gameInfo.achievements.survival then
            for k, v in pairs(sceneMainMenu.scoreLabels.survival) do
                tween:to(v, {x=sceneMainMenu.screenMinX - 100})
            end
        end
        for k, v in pairs(sceneMainMenu.scoreLabels.streak) do
            if k == 10 then
                tween:to(v, {x=appWidth/2, onComplete=menuShowStreakScoresDone})
            else
                tween:to(v, {x=appWidth/2})
            end
        end
    end
end

function menuShowStreakScoresDone()
    addArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
    if gameInfo.achievements.survival then
        addArrowButton(sceneMainMenu, "left", menuShowSurvivalScores)
    else
        addArrowButton(sceneMainMenu, "left", menuShowWavesScores)
    end
end
------

function menuShowWavesScores(event)
    if event.phase == "ended" then
        sceneMainMenu.scoreMenuState = "waves"
        removeArrowButton(sceneMainMenu, "left", menuShowWavesScores)
        removeArrowButton(sceneMainMenu, "right", menuShowStreakScores)
        removeArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
        sceneMainMenu.scoreLabels.title.text = "HIGH SCORES"
        
        if gameInfo.achievements.survival then
            for k, v in pairs(sceneMainMenu.scoreLabels.survival) do
                tween:to(v, {x=sceneMainMenu.screenMaxX + 100})
            end
        end
        for k, v in pairs(sceneMainMenu.scoreLabels.streak) do
            tween:to(v, {x=sceneMainMenu.screenMaxX + 100})
        end
        for k, v in pairs(sceneMainMenu.scoreLabels.waves) do
            if k == 10 then
                tween:to(v, {x=appWidth/2, onComplete=menuShowWavesScoresDone})
            else
                tween:to(v, {x=appWidth/2})
            end
        end
    end
end

function menuShowWavesScoresDone()
    addArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
    if gameInfo.achievements.survival then
        addArrowButton(sceneMainMenu, "right", menuShowSurvivalScores)
    else
        addArrowButton(sceneMainMenu, "right", menuShowStreakScores)
    end
end

function menuCloseHighScores(event)
    if event.phase == "ended" then
        sceneMainMenu.subMenu = nil
        for kL, vL in pairs(sceneMainMenu.scoreLabels) do
            if kL == "title" then
                vL:removeFromParent()
            else
                for k,v in pairs(vL) do
                    v:removeFromParent()
                end
            end
        end
        sceneMainMenu.scoreLabels = nil
        removeArrowButton(sceneMainMenu, "down", menuCloseHighScores, menuBackKeyListener)
        
        if sceneMainMenu.scoreMenuState == "survival" then
            removeArrowButton(sceneMainMenu, "left", menuShowWavesScores)
            removeArrowButton(sceneMainMenu, "right", menuShowStreakScores)
        else
            removeArrowButton(sceneMainMenu, "left", menuShowSurvivalScores) -- streak screen
            removeArrowButton(sceneMainMenu, "right", menuShowSurvivalScores) -- waves screen
        end
        
        tween:to(sceneMainMenu.title, {y=sceneMainMenu.titleY, xScale=1, yScale=1, time=1.0, delay=0.3, onComplete=showMainMenu})
    end
end

-------------------------
-- Achievements. Largely similar code to scores, but simplified as there's no
-- name entry and "modes" are just numbered pages so code is more generic.

function menuDisplayAchievementsScreen()
    sceneMainMenu.title.nextMenu = nil
    sceneMainMenu.title.menuTween = nil
    
    -- simplified version of menuDisplayHighScoreScreen mixed with sceneMainMenu:displayHighScores
    sceneMainMenu.achieveLabels = {}
    local i = gameInfo.achievementPages
    while i > 0 do
        table.insert(sceneMainMenu.achieveLabels, {})
        i = i-1
    end
    
    sceneMainMenu.achieveLabels.title = director:createLabel({x=appWidth/2, y=appHeight/2+165, w=250, h=50, xAnchor=0.5,
            yAnchor=0, hAlignment="center", vAlignment="bottom", text="ACHIEVEMENTS", color=menuBlue, font=fontMainLarge})
    
    local achieveTimer = system:addTimer(menuAddAchievement, 0.15, 10, 0.3)
    
    achieveTimer.page = 1
    sceneMainMenu.achieveMenuState = 1
end

function menuAddAchievement(event)
    --similar to scores but simplified as pages are numbered and there's no name entry
    local i = event.doneIterations
    local labelX = appWidth/2
    local labelY = appHeight/2+165-30 - i*20
    local achievement = gameInfo.achievementIndex[(event.timer.page-1)*10 + i]
    local text = ""
    
    for k,v in pairs(gameInfo.achievementNames[achievement]) do
        text = text .. v .. " "
    end
    
    if event.timer.page > sceneMainMenu.achieveMenuState then
        labelX = sceneMainMenu.screenMinX + 100
    end
    
    local textCol
    if gameInfo.achievements[achievement] then
        textCol = achieveCol
    else
        textCol = achieveLockedCol
    end
    
    sceneMainMenu.achieveLabels[event.timer.page][i] = director:createLabel({x=labelX, y=labelY, w=350, h=50, xAnchor=0.5, yAnchor=0, hAlignment="left", vAlignment="bottom", text=text, color=textCol, font=fontMainSmall})
    
    if i == 10 and event.timer.page == sceneMainMenu.achieveMenuState then
        sceneMainMenu:activateAchievementArrowButtons()
    end
end

function sceneMainMenu:activateAchievementArrowButtons()
    addArrowButton(self, "down", menuCloseAchievements, menuBackKeyListener)
    
    if self.achieveMenuState < gameInfo.achievementPages then
        addArrowButton(self, "right", menuShowNextAchievements)
    end
    if self.achieveMenuState > 1 then
        addArrowButton(self, "left", menuShowPrevAchievements)
    end
end

function removeAchievementArrows()
    removeArrowButton(sceneMainMenu, "down", menuCloseAchievements, menuBackKeyListener)
    
    if sceneMainMenu.achieveMenuState < gameInfo.achievementPages then
        removeArrowButton(sceneMainMenu, "left", menuShowNextAchievements)
    end
    if sceneMainMenu.achieveMenuState > 0 then
        removeArrowButton(sceneMainMenu, "right", menuShowPrevAchievements)
    end
end

function menuShowNextAchievements()
    if event.phase == "ended" then
        removeAchievementArrows()
        
        for k, v in pairs(sceneMainMenu.achieveLabels[sceneMainMenu.achieveMenuState]) do
            tween:to(v, {x=sceneMainMenu.screenMinX - 100})
        end

        for k, v in pairs(sceneMainMenu.achieveLabels[sceneMainMenu.achieveMenuState+1]) do
            if k == 10 then
                tween:to(v, {x=appWidth/2, onComplete=activateAchievementArrowButtons})
            else
                tween:to(v, {x=appWidth/2})
            end
        end
    end
end

function menuShowPrevAchievements()
    if event.phase == "ended" then
        removeAchievementArrows()
        
        for k, v in pairs(sceneMainMenu.achieveLabels[sceneMainMenu.achieveMenuState]) do
            tween:to(v, {x=sceneMainMenu.screenMaxX + 100})
        end

        for k, v in pairs(sceneMainMenu.achieveLabels[sceneMainMenu.achieveMenuState-1]) do
            if k == 10 then
                tween:to(v, {x=appWidth/2, onComplete=activateAchievementArrowButtons})
            else
                tween:to(v, {x=appWidth/2})
            end
        end
    end
end

function menuCloseAchievements(event)
    if event.phase == "ended" then
        sceneMainMenu.subMenu = nil
        for kL, vL in pairs(sceneMainMenu.achieveLabels) do
            if kL == "title" then
                vL:removeFromParent()
            else
                for k,v in pairs(vL) do
                    v:removeFromParent()
                end
            end
        end
        sceneMainMenu.achieveLabels = nil
        
        removeAchievementArrows()
        
        tween:to(sceneMainMenu.title, {y=sceneMainMenu.titleY, xScale=1, yScale=1, time=1.0, delay=0.3, onComplete=showMainMenu})
    end
end


-------------------------------------------------------------
-- buttons and handler to close sub-menu (high scores, about, etc)

function showMainMenu()
    sceneMainMenu:restoreButtonsAnim()
    sceneMainMenu:addMainMenuListeners()
    
    sceneMainMenu:titleFlash()
end


function menuBackKeyListener(event)
    if event.keyCode == 210 and event.phase == "pressed" then
        -- 210 is the C++ code for s3eKeyAbsBSK (abstract/mappable back soft key)
        -- 1) Quick doesnt expose that or any abs keys as a variable (ought to be "absBSK" in QEventX.h)
        -- 2) Our s3eAbs keys are a bit dated! We ought to have s3eKeyAbsBack/Home/Menu to match modern phones!
        -- "BSK"/"soft key" are old fashioned concepts...
        sceneMainMenu.backKeyListener({phase="ended"})
    end
end

--[[
function sceneMainMenu:addArrowButton(btnType, listener) --types are "back", "left", "right"
    local xPos
    local yPos
    local rotation
    local btnName = btnType .. "Btn"
    if btnType == "left" then
        xPos = self.screenMinX + 75
        yPos = appHeight*0.6
        rotation = 90
    elseif btnType == "right" then
        xPos = self.screenMaxX - 75
        yPos = appHeight*0.6
        rotation = 270
    elseif btnType == "back" then
        xPos = appWidth/2
        yPos = 80
        rotation = 0
        
        sceneMainMenu.backKeyListener = listener
        system:addEventListener("key", menuBackKeyListener)
    else
        dbg.assert(false, "invalid button type in addArrowButton")
    end

    self[btnName] = director:createLines({x=xPos, y=yPos, coords={-50,30, 0,0, 50, 30}, strokeColor=menuBlue, strokeWidth=2, alpha=0, rotation=rotation})
    local infoBack2 = director:createLines({y=-20, coords={-50,30, 0,0, 50, 30}, strokeColor=menuBlue, strokeWidth=2, alpha=0})
    
    self[btnName].button = director:createRectangle({x=-60, y=-30, w=120, h=70, alpha=0, strokeColor=color.blue, zOrder = 10, isVisible=showDebugTouchArea})
    
    self[btnName]:addChild(infoBack2)
    self[btnName]:addChild(self[btnName].button)
    self[btnName].button:addEventListener("touch", listener)
    tween:to(self[btnName], {strokeAlpha=0.1, xScale=1.5, yScale=1.5, time=1.0, mode="mirror"})
end

function sceneMainMenu:removeArrowButton(btnType, listener)
    local btnName = btnType .. "Btn"
    if not self[btnName] then
        dbg.print("Ignoring request to remove non existing arrow btn: " .. btnName)
        return
    end
    
    if btnType == "back" then
        system:removeEventListener("key", menuBackKeyListener)
        sceneMainMenu.backKeyListener = nil
    end
    
    self[btnName].button:removeEventListener("touch", listener)
    self[btnName] = self[btnName]:removeFromParent()
end
--]]

-------------------------------------------------------------

function menuSaveData(clearFlag)
    local saveStatePath = system:getFilePath("storage", "data.txt")
    local file = io.open(saveStatePath, "w")
    if not file then
        dbg.print("failed to open save-state file for saving: " .. saveStatePath)
    else
        file:write(json.encode({scores=gameInfo.highScore, lastName=gameInfo.name, achievements=gameInfo.achievements, soundOn=gameInfo.soundOn, vibrateOn=gameInfo.vibrateOn, portraitTopAlign=gameInfo.portraitTopAlign}))
        file:close()
        dbg.print("user data saved")
    end
    
    if clearFlag then
        gameInfo.newHighScore = nil
        gameInfo.newHighStreak = nil
    end
end

function menuCheckNewHighScoreAndSave()
    gameInfo.newHighScore = nil
    gameInfo.newHighStreak = nil
    for k,v in pairs(gameInfo.highScore[gameInfo.mode]) do
        if gameInfo.score > v.score then
            gameInfo.newHighScore = k
            sceneMainMenu.scoreMenuState = gameInfo.mode
            dbg.print("New high score")
            for n=10, k+1, -1 do
                gameInfo.highScore[gameInfo.mode][n].score = gameInfo.highScore[gameInfo.mode][n-1].score
                gameInfo.highScore[gameInfo.mode][n].name = gameInfo.highScore[gameInfo.mode][n-1].name
            end
            gameInfo.highScore[gameInfo.mode][k].score = gameInfo.score
            gameInfo.highScore[gameInfo.mode][k].name = gameInfo.name
            break
        end
    end
    
    for k,v in pairs(gameInfo.highScore["streak"]) do
        if gameInfo.streakMax > v.score then
            gameInfo.newHighStreak = k
            if not gameInfo.newHighScore then
                gameInfo.newHighScore = k
                sceneMainMenu.scoreMenuState = "streak"
                -- name entry will now show streak screen as there was no regular high score
            end
            dbg.print("New high streak")
            for n=10, k+1, -1 do
                gameInfo.highScore["streak"][n].score = gameInfo.highScore["streak"][n-1].score
                gameInfo.highScore["streak"][n].name = gameInfo.highScore["streak"][n-1].name
            end
            gameInfo.highScore["streak"][k].score = gameInfo.streakMax
            gameInfo.highScore["streak"][k].name = gameInfo.name
            break
        end
    end
    
    if gameInfo.newHighScore then
        menuSaveData()
    end
    
    return gameInfo.newHighScore -- allow quick checking if a score was set
end

function LoadUserData()
    -- load highscore from JSON encoded lua value
    -- Eventually integrate some onlne service (google play/game center/amazon/etc)
    local saveStatePath = system:getFilePath("storage", "data.txt")
    local file = io.open(saveStatePath, "r")
    if not file then
        dbg.print("save state file not found at: " .. saveStatePath)
    else        
        local success, loaded = pcall(json.decode, file:read("*a")) -- "*a" = read the entire file contents
        file:close()
        
        if not success then
            dbg.print("json error loading continue data - ignoring")
        else
            gameInfo.highScore = loaded.scores
            gameInfo.name = loaded.lastName
            gameInfo.achievements = loaded.achievements
            gameInfo.soundOn = loaded.soundOn
            gameInfo.vibrateOn = loaded.vibrateOn
            gameInfo.portraitTopAlign = loaded.portraitTopAlign
            analytics:logEvent("LoadUserData", {scoreName=gameInfo.name})
            dbg.print("highscore etc loaded")
        end
    end
    
    -- do "if nil then create" for all values so game can be updated and new settings get
    -- initialised when save games already exist
    if not gameInfo.highScore then
        gameInfo.highScore = {waves={}, survival={}, streak={}}
        local names = {"NIC", "MAR", "MAL", "ADE", "PAC", "JNR", "CRS", "I3D", "MRK", "FFS"}
        for k,v in pairs(gameInfo.highScore) do
            for n=1, 10 do
                local score = (11-n)*20 --20->200
                if k == "survival" then score = score/4 end --5->50
                if k == "streak" then score = score/2-50 end --10->50
                if score < 0 then score=0 end
                v[n] = {name=names[n], score=score}
                if score == 0 then v[n].name="XXX" end
            end
        end
    end
    
    if not gameInfo.name then gameInfo.name = "_P1" end --records last name entered to save re-entering
end

-- as above for restoring last game if game was killed before user explicitly exited
function LoadContinueData()
    local saveStatePath = system:getFilePath("storage", "continue.txt")
    local file = io.open(saveStatePath, "r")
    if not file then
        dbg.print("continue data from last run not found at: " .. saveStatePath)
        return nil
    end
    
    analytics:logEvent("LoadContineData")
    local success, continue = pcall(json.decode, file:read("*a")) -- "*a" = read the entire file contents
    file:close()
    
    if not success then
        dbg.print("json error loading continue data - ignoring")
        return nil
    end
    
    dbg.print("continue data loaded")
    
    if type(continue) ~= "table" or not continue.canContinue then
        dbg.print("valid continue data not found")
        return nil
    end
    
    return continue
end

function sceneMainMenu:wipeContinueFile()
    if not demoMode then
        dbg.print("Wiping continue.txt (game state save data)")
        local saveStatePath = system:getFilePath("storage", "continue.txt")
        local file = io.open(saveStatePath, "w")
        if file then
            file:write(json.encode({}))
            file:close()
        end
    end
end
------------------------------------------------------------
-- Button handlers

-- Reduce startup loading time by a small bit by loading the large-ish game
-- scene code only when its first needed
gameSceneLoadFlag = false

function MenuStartGame()
    
    -- Just in case! A good time to force re-hiding in case OS showed for some reason
    if androidFullscreen and androidFullscreen:isImmersiveSupported() then
        androidFullscreen:turnOn()
    end
    menuSaveData() -- save sound on/off option
    if not demoMode then
        audio:stopStream()
        gameInfo.titleMusicPlaying = false
    end
    if not gameSceneLoadFlag then
        dofile("GameScene.lua")
        --require("GameScene")
        gameSceneLoadFlag = true
    end
    director:moveToScene(sceneBattle, {transitionType="slideInT", transitionTime=0.8})
end

function sceneMainMenu:buttonPressedAnim(touched)
    self:removeMainMenuListeners()
    for k,v in pairs(self.btns) do
        if k == touched then
            tween:to(v, {xScale=2, yScale=2, alpha=0, time=0.3})
        else
            tween:to(v, {yScale=0, time=0.3})
        end
    end 
    tween:to(self.labelScore, {alpha=0, time=0.3})
    tween:to(self.labelHighScore, {alpha=0, time=0.3})
end

-- set as if menu was acessed already
function sceneMainMenu:setMenuState(touched)
    for k,v in pairs(self.btns) do
        if k == touched then
            v.xScale=2
            v.yScale=2
            v.alpha=0
        else
            v.yScale=0
        end
    end 
    self.labelScore.alpha=0
    self.labelHighScore.alpha=0
    
    if touched == "highscores" then
        sceneMainMenu.title.y=self.screenMinY-170 --places "WRONG" off-screen, but hills on-screen
        menuDisplayHighScoreScreen()
    end
end

function sceneMainMenu:restoreButtonsAnim()
    for k,v in pairs(self.btns) do
        tween:to(v, {xScale=(v.defaultScale or 1), yScale=(v.defaultScale or 1), alpha=1, time=0.3})
    end
    tween:to(self.labelScore, {alpha=1, time=0.3})
    tween:to(self.labelHighScore, {alpha=1, time=0.3})
end

function sceneMainMenu:animateSceneOut()    
    if self.screenFxTimer then
        self.screenFxTimer:cancel()
        self.screenFxTimer = nil
    end
    fullscreenEffectsStop(self)
    --fullscreenEffectsOff(self)
    
    if self.screenFx then --may never have started
        self.screenFx:resumeTweens()
        tween:to(self.screenFx, {alpha=0, time=0.8})
    end
    tween:to(self.title, {y=self.screenMinY-280, time=0.5, delay=0.3, onComplete=MenuStartGame})
end

function touchContinue(self, event)
    if event.phase == "ended" then
        gameInfo.continue = sceneMainMenu.readyToContinue
        sceneMainMenu.readyToContinue = nil
        gameInfo.controlType = gameInfo.continue.controlType
        gameInfo.mode = gameInfo.continue.mode
        sceneMainMenu:buttonPressedAnim("continue")
        analytics:logEvent("startContinue")
        sceneMainMenu:animateSceneOut()
    end
end

function touch1pSurvival(self, event)
    if event.phase == "ended" then
        gameInfo.controlType = "onePlayer"
        gameInfo.mode = "waves"
        sceneMainMenu:buttonPressedAnim("1pSurvival")
        analytics:logEvent("startMain")
        sceneMainMenu:animateSceneOut()
    end
end

function touchSurvival(self, event)
    if event.phase == "ended" then
        gameInfo.controlType = "onePlayer"
        gameInfo.mode = "survival"
        sceneMainMenu:buttonPressedAnim("survival")
        analytics:logEvent("startSurvival")
        sceneMainMenu:animateSceneOut()
    end
end

function touch2pLocal(self, event)
    if event.phase == "ended" then
        gameInfo.controlType = "p1LocalVsP2Local"
        sceneMainMenu:buttonPressedAnim("2pLocal")
        analytics:logEvent("start2pLocal")
        sceneMainMenu:animateSceneOut()
    end
end

function touchAbout(self, event)
    if event.phase == "ended" then
        sceneMainMenu:buttonPressedAnim("about")
        analytics:logEvent("showAbout")
        sceneMainMenu.title.menuTween = tween:to(sceneMainMenu.title,
            {y=sceneMainMenu.screenMinY-350, xScale=3, yScale=2, time=1.0, delay=0.3, onComplete=menuDisplayAbout})
        sceneMainMenu.title.nextMenu = menuDisplayAbout
        sceneMainMenu.subMenu = "about"
    end
end

function touchHighScores(self, event)
    if event.phase == "ended" then
        sceneMainMenu:buttonPressedAnim("highscores")
        sceneMainMenu.title.menuTween = tween:to(sceneMainMenu.title, {y=sceneMainMenu.screenMinY-350, xScale=3, yScale=2, time=1.0, delay=0.3, onComplete=menuDisplayHighScoreScreen})
        sceneMainMenu.title.nextMenu = menuDisplayHighScoreScreen
        sceneMainMenu.subMenu = "highscores"
    end
    --dbg.print("NODE touch listener test - " .. event.phase .. " - x,y=" .. event.x .. "," .. event.y)
end

function touchAchievements(self, event)
    if event.phase == "ended" then
        sceneMainMenu:buttonPressedAnim("achievements")
        sceneMainMenu.title.menuTween = tween:to(sceneMainMenu.title, {y=sceneMainMenu.screenMinY-350, xScale=3, yScale=2, time=1.0, delay=0.3, onComplete=menuDisplayAchievementsScreen})
        sceneMainMenu.title.nextMenu = menuDisplayAchievementsScreen
        sceneMainMenu.subMenu = "achievements"
    end
end

function touchFacebook(self, event)
    if event.phase == "ended" then
        analytics:logEvent("gotoFacebook")
        browser:launchURL(facebookUrl)
    end
end

function touchTwitter(self, event)
    if event.phase == "ended" then
        analytics:logEvent("gotoTwitter")
        browser:launchURL(twitterUrl)
    end
end

function touchRate(self, event)
    if event.phase == "ended" then
        analytics:logEvent("gotoStoreRate")
        browser:launchURL(storeUrl)
    end
end

function touchSound(self, event)
    if event.phase == "ended" then
        if gameInfo.soundOn then
            analytics:logEvent("turnOffSound")
            audio:stopStream()
            gameInfo.titleMusicPlaying = false
            gameInfo.soundOn = false
            sceneMainMenu.btns.sound.color = {75,85,110}
        else
            analytics:logEvent("turnOnSound")
            audio:playStreamWithLoop("sounds/iron-suit.mp3", true)
            gameInfo.titleMusicPlaying = true
            gameInfo.soundOn = true
            sceneMainMenu.btns.sound.color = color.white
        end
    end
end

function touchVibrate(self, event)
    if event.phase == "ended" then
        if gameInfo.vibrateOn then
            device:disableVibration()
            gameInfo.vibrateOn = false
            sceneMainMenu.btns.vibrate.color = {75,85,110}
        else
            device:enableVibration()
            device:vibrate(100, 0.2)
            gameInfo.vibrateOn = true
            sceneMainMenu.btns.vibrate.color = color.white
        end
    end
end

function goToBlog(event)
    if event.phase == "ended" then
        analytics:logEvent("goToBlog")
        browser:launchURL(blogUrl)
    end
end

function createLabelTouchBox(label, touchEvent)
    local box = director:createRectangle({x=0, y=0, w=label.w, h=label.hText, alpha=0, strokeColor=color.blue, zOrder = 10, isVisible=showDebugTouchArea})
    label:addChild(box)
    label.touchArea = box
    label.touchArea.touch = touchEvent
end


function sceneMainMenu:createServicesButtonTouch(name, image, touchEvent, column)
    if not self.btnY then self.btnY = {} end
    local x = 0
    
    if column then -- columns start at and default to 1
        x = self.btnSize * (column-1) * 1.4
    else
        column = 1
    end
    
    if not self.btnY[column] then self.btnY[column] = 0 end
    
    local btn = director:createSprite({x=x, y=self.btnY[column], source="textures/" .. image .. "_button.png"})
    
    --note: we cant set size in pixels directly for sprites, but can scale
    btn.defaultScale = self.btnSize/btn.w --store in separate value to cache for anims
    btn.xScale = btn.defaultScale
    btn.yScale = btn.defaultScale
    
    self.btns[name] = btn
    self.servicesBtnsOrigin:addChild(btn)

    btn.touchArea = btn --match label style to reusue same code
    btn.touchArea.touch = touchEvent
    
    self.btnY[column] = self.btnY[column] - self.btnSize*1.4
    
    return btn
end

-------------------------------------------------------

function startDemo()
    local event = {phase="ended"}
    demoMode = true
    dbg.print("demo set true in startDemo")
    touch2pLocal(nil, event)
end

function enableMenu()
    sceneMainMenu:addMainMenuListeners()
end

-- demo timers and touch listener are added/removed on enabling/disabling main menu
-- controls. Guaranteed to be disabled on leaving the scene (via buttonPressedAnim)
function sceneMainMenu:removeMainMenuListeners()
    if self.screenFx then
        -- swap effect each time we open a menu
        dbg.print("!!!!")
        self.newDontClear = not self.newDontClear
    end
    if demoAvailable then
        self:removeEventListener({"touch"}, self)
        if self.demoTimer then
            self.demoTimer:cancel()
            self.demoTimer = nil
        end
    end
    for k,v in pairs(self.btns) do
        v.touchArea:removeEventListener("touch", v.touchArea)
    end
    
    if sceneMainMenu.backKeyListener then
        system:removeEventListener("key", menuBackKeyListener)
        sceneMainMenu.backKeyListener = nil
    end
end

function sceneMainMenu:addMainMenuListeners()
    for k,v in pairs(self.btns) do
        v.touchArea:addEventListener("touch", v.touchArea)
    end
    if demoAvailable then
        self.demoTimer = system:addTimer(startDemo, DEMO_TIMEOUT, 1)
        self:addEventListener({"touch"}, self)
    end
    if gameInfo.soundOn and not gameInfo.titleMusicPlaying then
        audio:playStreamWithLoop("sounds/iron-suit.mp3", true)
        gameInfo.titleMusicPlaying = true
    end
    
     --alow android etc back key to quit on main menu.
     --TODO: reuse in-game pause menu exit icons for user to confirm quit
    sceneMainMenu.backKeyListener = quitGameOnBackKey
    system:addEventListener("key", menuBackKeyListener)
end

function quitGameOnBackKey(event)
    system:removeEventListener("key", menuBackKeyListener)
    shutDownApp()
end

--------------------------------------------------------

function sceneMainMenu:suspend(event)
    dbg.print("suspending menus...")
    -- Quick itself pauses during app suspension, but on app resume it fires a queue of timer
    -- and tween events to mimic any of those having run. e.g. If a timer should fire evey 2
    -- seconds and the app was suspended for 10 seconds, the timer will fire 5 times quickly
    -- on app resume. We want to suspend, so pause all timers and tweens.
    if not pauseflag then
        system:pauseTimers()
        pauseNodesInTree(self) --pauses timers and tweens
    end
    analytics:endSession() --force upload logs to server
    analytics:startSessionWithKeys() --resume previous session
    menuSaveData()
    dbg.print("...menus suspended!")
end

function sceneMainMenu:resume(event)
    dbg.print("resuming menus...")
    -- bug/quirk workaround: Quick fires the queue of timer events *after* the "resume" event
    -- and before the first "update" event on app resume for all timers that were not paused.
    -- So, we flag here and then resume in update.
    pauseflag = true
    --system:resumeTimers()
    --resumeNodesInTree(self)
    dbg.print("...menus resumed")
end

function sceneMainMenu:update(event)
    if pauseflag then
        pauseflag = false
        system:resumeTimers()
        resumeNodesInTree(self)
    end
    
    fullscreenEffectsUpdate(self)
end

--------------------------------------------------------

local wrongColorDark={r=128,g=255,b=128}
local wrongColorMid={r=0,g=255,b=0}
local wrongColorBright={r=200,g=255,b=200}

function resizeCheck(event)
    -- need to wait till nav bar has hidden and then get fullscreen sizes
    -- need to re-call applyToScene to update transforms
    -- safe to call if user starts game before timer expires
    --virtualResolution:update()
    --virtualResolution:applyToScene(sceneMainMenu)
end

function sceneMainMenu:fullscreenEffect()
    dbg.print("!1")
    if not gameInfo.useFullscreenEffects then
        dbg.print("!2")
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
    self.screenFx.alpha=0.94
    
    -- have to scale to match VR
    self.screenFx.xScale = 1/virtualResolution.scale
    self.screenFx.x = virtualResolution.userWinMinX
    self.screenFx.yScale = -1/virtualResolution.scale
    self.screenFx.y = screenHeight + virtualResolution.userWinMinY --screenHeight is workaround for bug in renderTexture!
    
    -------- debugging --------------------
    --self.screenFx.xScale = self.screenFx.xScale / 2
    --self.screenFx.yScale = self.screenFx.yScale / 2
    --self.screenFx.x = self.screenFx.x + 100
    --self.screenFx.y = self.screenFx.y + 100
    ---------------------------------------
    
    self.screenFx.filter.name = "blur"
    self.screenFx.filter.x = 0
    self.screenFx.filter.y = 0
    
    local fxType = math.random(1,5)
    local x,y = 0,0
    if fxType == 1 then
        x = math.random(2,6)
    elseif fxType == 2 then
        y = math.random(2,6)
    else
        x = math.random(2,4)
        y = math.random(2,4)
    end
    
    --debugging
    --x = x*2
    --y = y*2
    
    dbg.print("tweening!")
    self.screenFx.tween = tween:to(self.screenFx, {filter={x=x,y=y}, time=2, mode="mirror",
        easing=ease.bounceInOut, onComplete=self.pauseResumeTween})
    
    self.screenFx.targX = x
    self.screenFx.targY = y
end


function sceneMainMenu:orientation(event, delayEffects)
    fullscreenEffectsReset(self)
    
    adaptToOrientation(event)
    
    -- User space coords for screen edges inc letterboxes
    -- Menu uses 0,0 is bottom left
    self.screenMinX = appWidth/2 - screenWidth/2
    self.screenMaxX = appWidth/2 + screenWidth/2
    self.screenMinY = appHeight/2 - screenHeight/2
    self.screenMaxY = appHeight/2 + screenHeight/2
    
    --realign UI that clamps to screen rather than virtual resolution
    if self.leftBtn then
        self.leftBtn.x = self.screenMinX + 75
    end
    if self.rightBtn then
        self.rightBtn.x = self.screenMaxX - 75
    end
    if self.downBtn then
        self.downBtn.y = (self.screenMinY+100 + 80) / 2
    end
    if self.upBtn then
        self.upBtn.y = (self.screenMinY+100 + 80) / 2
    end
    
    if sceneMainMenu.scoreLabels then
        local left, right
        if sceneMainMenu.scoreMenuState == "streak" then
            left = {"survival", "waves"}
        elseif sceneMainMenu.scoreMenuState == "survival" then
            left = {"waves"}
            right = {"streak"}
        else --waves
            right = {"survival", "streak"}
        end
        
        if left then
            for j, labels in pairs(left) do
                if self.scoreLabels[labels] then
                    for k, v in pairs(self.scoreLabels[labels]) do
                        cancelTweensOnNode(v)
                        v.x=self.screenMinX - 100
                    end
                end
            end
        end
        if right then
            for j, labels in pairs(right) do
                if self.scoreLabels[labels] then
                    for k, v in pairs(self.scoreLabels[labels]) do
                        cancelTweensOnNode(v)
                        v.x=self.screenMaxX + 100
                    end
                end
            end
        end
        -- note: middle/current item uses vr space position (centre!) not screen
    end
    
    -- jump to submenu if interrupting existing tween
    if sceneMainMenu.title and sceneMainMenu.title.nextMenu then
        if sceneMainMenu.title.menuTween then
            tween:cancel(sceneMainMenu.title.menuTween)
            sceneMainMenu.title.menuTween = nil
        end
        sceneMainMenu.title.nextMenu()
        sceneMainMenu.title.nextMenu = nil
    end
    
    -- fit WRONG title to bottom of screen
    if sceneMainMenu.subMenu then
        self.title.y = self.screenMinY-350
        self.title.xScale=3
        self.title.yScale=2
    end
    
    -- (re)setup screen burn filter effect...
    if not delayEffects then -- dont do when called form setUp() pre transition! Cant start tweens until transition is over.
        self:queueFullscreenEffect()
    end
end

function sceneMainMenu:queueFullscreenEffect()
    self.screenFxTimer = system:addTimer(self.startFullscreenEffect, 2, 1)
end

function sceneMainMenu.startFullscreenEffect()
    sceneMainMenu.screenFxTimer = nil
    dbg.print("effect startFullscreenEffect timer called")
    sceneMainMenu:fullscreenEffect()
end

function sceneMainMenu.resumeFxTween(event)
    if sceneMainMenu.pauseRt then
        return
    end
    
    dbg.print("resumeFxTween")
    -- allow previous style to run till tween restarts - allows to fade as much as possible
    if sceneMainMenu.newDontClear ~= sceneMainMenu.rtDontClear then
        dbg.print("switching effect style")
        tween:cancel(sceneMainMenu.screenFx.tween)

        if sceneMainMenu.rtDontClear then
            sceneMainMenu.screenFx.targX = sceneMainMenu.screenFx.targX*2
            sceneMainMenu.screenFx.targY = sceneMainMenu.screenFx.targY*2
            sceneMainMenu.rtDontClear = false
            sceneMainMenu.screenFx.alpha=1
        else
            sceneMainMenu.screenFx.targX = sceneMainMenu.screenFx.targX/2
            sceneMainMenu.screenFx.targY = sceneMainMenu.screenFx.targY/2
            sceneMainMenu.rtDontClear = true
            sceneMainMenu.screenFx.alpha=0.94
        end
        
        sceneMainMenu.screenFx.tween = tween:to(sceneMainMenu.screenFx,
            {filter={x=sceneMainMenu.screenFx.targX,y=sceneMainMenu.screenFx.targY}, time=1.6, mode="mirror",
            easing=ease.bounceInOut, onComplete=sceneMainMenu.pauseResumeTween})
    end
    
    event.target:resumeTweens()
end

function sceneMainMenu.pauseResumeTween(target)
    dbg.print("effects tween onComplete")
    if target.tween.numCycles % 2 == 0 then
        dbg.print("resume effects tween")
        if not sceneMainMenu.pauseRt then
            target:pauseTweens()
            target:addTimer(sceneMainMenu.resumeFxTween, 4.5, 1)
        end
    end
end

function sceneMainMenu:setUp(event)
    --dbg.assert(false, "1")
    dbg.print("sceneMainMenu:setUp")
    
    system:addEventListener({"suspend", "resume", "update", "orientation"}, self)
    --system:addEventListener({"suspend", "resume", "update"}, self)
    
    math.randomseed(os.time())
    
    virtualResolution:applyToScene(self)
    self:orientation(nil, not startupFlag)
    self.rtDontClear = true
    self.newDontClear = true
    
    if showFrameRate and not frameRateOverlay.isShown() then
        frameRateOverlay.showFrameRate({x = virtualResolution.userWinMinX+5, y = virtualResolution.userWinMinY+5, zOrder = 100, width = 100}) --debugging
    end
    
    -- loads scores, last user name and achievements from local storage
    -- TODO: integrate these with online services...
    if not gameInfo.highScore then LoadUserData() end
    
    self.readyToContinue = LoadContinueData()
    gameInfo.continue = {} --needed for demo mode to not try to do continue logic
    
    --self.title = director:createSprite(0, 0, "textures/wrongtitle.png")
    ----self.title:getAtlas():setTextureParams("GL_NEAREST", "GL_NEAREST")
    --tween:to(self.title, {alpha=0.4, time=3.0, mode="mirror", delay=1.0})
    --self.title.alpha=0.3
    
    local wrongWidth=2
    local hillWidth=1
    local wrongColor = color.red
    local hillColor=color.white
    local titlePartsY = 80
    self.titleY = 0
    
    --[[
    if gameInfo.achievements.survival then
        self.titleY = self.titleY - 35
    end
    
    if gameInfo.achievements.battle then
        self.titleY = self.titleY - 35
    end
    ]]--
    
    --dbg.assert(false, "2")

    self.title = director:createNode({x=appWidth/2,y=self.titleY})
    self.title.origin = director:createNode({x=-appWidth/2,y=0})
    self.title:addChild(self.title.origin)
    self.title.letters = {}
    
    self.title.W = director:createLines({x=60, y=titlePartsY, coords={0,0, 56,80, 73,80, 38,32, 93,80, 111,80, 85,32, 132,80, 149,80, 74,0, 52,0, 92,66, 20,0, 0,0}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    table.insert(self.title.letters, self.title.W)
    
    self.title.R = director:createLines({x=175, y=titlePartsY, coords={0,0, 43,80, 89,80, 99,75, 94,54, 83,45, 91,34, 85,0, 63,0, 69,30, 66,38, 39,38, 21,0, 0,0}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    table.insert(self.title.letters, self.title.R)
    
    self.title.Ro = director:createLines({x=0, y=0, coords={45,51, 54,71, 76,71, 81,66, 78,55, 70,51, 45,51}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    self.title.R:addChild(self.title.Ro)

    self.title.O = director:createLines({x=275, y=titlePartsY, coords={4,22, 10,65, 32,80, 61,80, 82,65, 88,22, 70,0, 23,0, 4,22}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    table.insert(self.title.letters, self.title.O)
    
    self.title.Oo = director:createLines({x=0, y=0, coords={24,28, 26,60, 40,70, 54,70, 67,60, 70,28, 58,16, 35,16, 24,28}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    self.title.O:addChild(self.title.Oo)
    
    self.title.N = director:createLines({x=369, y=titlePartsY, coords={17,0, 0,80, 16,80, 63,36, 43,80, 58,80, 100,0, 80,0, 21,56, 38,0, 17,0}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    table.insert(self.title.letters, self.title.N)
    
    self.title.G = director:createLines({x=452, y=titlePartsY, coords={66,0, 30,14, 0,61, 8,80, 37,80, 57,72, 71,61, 55,61, 36,70, 24,70, 18,59, 41,26, 67,17, 93,17, 77,36, 59,36, 49,48, 84,48, 129,0, 65,0}, strokeWidth=wrongWidth, strokeColor=wrongColor, alpha=0})
    table.insert(self.title.letters, self.title.G)
    
    --dbg.assert(false, "3")
    
    self.hills = director:createLines({x=0, y=titlePartsY+111, coords={8,0, 632,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0})
    
    self.hills:addChild(director:createLines({x=0, y=0, coords={57,0, 95,22, 116,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={95,22, 113,53, 129,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={113,53, 153,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={139,20, 165,41, 243,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={211,17, 240,33, 253,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={240,33, 298,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={408,0, 449,18, 457,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={449,18, 558,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={518,7, 551,25, 569,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={551,25, 562,49, 569,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    self.hills:addChild(director:createLines({x=0, y=0, coords={562,49, 579,0}, strokeWidth=hillWidth, strokeColor=hillColor, alpha=0}))
    
    self.title.origin:addChild(self.title.W)
    self.title.origin:addChild(self.title.R)
    self.title.origin:addChild(self.title.O)
    self.title.origin:addChild(self.title.N)
    self.title.origin:addChild(self.title.G)
    self.title.origin:addChild(self.hills)
    
    --NB: Using manual touch boxes instead of relying on label's own touch area:
    --   Touch area vs visual area of labels don't perfectly match
    --   Nice to have full manual controll of padding
    --   hAlignment is broken atm and centres text around x pos not centre of box.
    --   xText and yText also seem to be broken when using left-bottom alignment.
    --   These may get/have been fixed by the time this is read!
    
    self.btns = {}
    self.btnsOrigin = director:createNode({x=appWidth/2-20, y=appHeight/2+120})
    local labelW = 250
    local labelY = 0
    local extraBtnCount = 0
    
    -- main menu buttons
    
    if self.readyToContinue then
        self.btns["continue"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Continue", color=menuBlue, font=fontMainLarge})
        createLabelTouchBox(self.btns["continue"], touchContinue)
        self.btnsOrigin:addChild(self.btns["continue"])
        labelY = labelY-40
        extraBtnCount = extraBtnCount + 1
    end
    
    self.btns["1pSurvival"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Start Game", color=menuBlue, font=fontMainLarge})
    createLabelTouchBox(self.btns["1pSurvival"], touch1pSurvival)
    self.btnsOrigin:addChild(self.btns["1pSurvival"])
    
    if gameInfo.achievements.survival then
        labelY = labelY-40
        self.btns["survival"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Survival Mode", color=menuBlue, font=fontMainLarge})
        createLabelTouchBox(self.btns["survival"], touchSurvival)
        self.btnsOrigin:addChild(self.btns["survival"])
        extraBtnCount = extraBtnCount + 1
    end

    if gameInfo.achievements.battle then
        labelY = labelY-40
        self.btns["2pLocal"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Battle", color=menuBlue, font=fontMainLarge})
        createLabelTouchBox(self.btns["2pLocal"], touch2pLocal)
        self.btnsOrigin:addChild(self.btns["2pLocal"])
        extraBtnCount = extraBtnCount + 1
    end
    
    if extraBtnCount < 2 then
        labelY = labelY-40
        self.btns["highscores"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="High Scores", color=menuBlue, font=fontMainLarge})
        createLabelTouchBox(self.btns["highscores"], touchHighScores)
        self.btnsOrigin:addChild(self.btns["highscores"])
        
        labelY = labelY-40
        self.btns["achievements"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Achievements", color=menuBlue, font=fontMainLarge})
        createLabelTouchBox(self.btns["achievements"], touchAchievements)
        self.btnsOrigin:addChild(self.btns["achievements"])
    end
    
    labelY = labelY-40
    self.btns["about"] = director:createLabel({x=0, y=labelY, w=labelW, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="[hack me]", color=menuBlue, font=fontMainLarge})
    createLabelTouchBox(self.btns["about"], touchAbout)
    self.btnsOrigin:addChild(self.btns["about"])
    
    -- score labels
    -- currently just show score and high scroe from last mode played. May want to show multiple modes.
    -- maybe have then on a rolling anim switching between modes
    self.labelScore = director:createLabel({x=appWidth-170, y=appHeight-35, w=190, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="SCORE    " .. gameInfo.score, color=menuGreen, font=fontDefault})
    self.labelHighScore = director:createLabel({x=appWidth-169, y=appHeight-50, w=250, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="HIGH SCORE     " .. gameInfo.highScore[gameInfo.mode][1].score, xScale=0.6, yScale=0.6, color=menuBlue, font=fontDefault})
    
    -- handy debug code to show screen size!
    --[[
    self.labelScore = director:createLabel({x=appWidth-170, y=appHeight-35, w=190, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Width: " .. director.displayWidth, color=menuGreen, font=fontDefault})
    self.labelHighScore = director:createLabel({x=appWidth-169, y=appHeight-50, w=250, h=50, xAnchor=0, yAnchor=0, hAlignment="left", vAlignment="bottom", text="Height: " .. director.displayHeight, xScale=0.6, yScale=0.6, color=menuBlue, font=fontDefault})
    ]]--
    
    -- buttons for facebook twitter etc
    self.btnSize = 38
    self.servicesBtnsOrigin = director:createNode({x=20, y=appHeight-14-self.btnSize})
    
    self:createServicesButtonTouch("facebook", "facebook", touchFacebook)
    self:createServicesButtonTouch("twitter", "twitter", touchTwitter)
    local extraServiceBtns = 0
    local column = 1
    
    if storeName then
        self:createServicesButtonTouch("rate", "rate_" .. storeName, touchRate)
        extraServiceBtns = extraServiceBtns + 1
    end
    
    if extraBtnCount >= 2 then
        -- _icon - need different names as self.btn contains both icon and text buttons
        -- and dont want to ovverwrite selb.btn.highscores, etc
        self:createServicesButtonTouch("highscores_icon", "highscores", touchHighScores)
        self:createServicesButtonTouch("achievements_icon", "achievements", touchAchievements)
        extraServiceBtns = extraServiceBtns + 2
    end
    
    if extraServiceBtns > 1 then
        column = 2
    end
    
    local soundBtn = self:createServicesButtonTouch("sound", "sound", touchSound, column)
    if not gameInfo.soundOn then
        soundBtn.color = {75,85,110}
    end
    
    if column == 2 then
        column = 3
    end
    
    if device:isVibrationAvailable() then
        local vibrateBtn = self:createServicesButtonTouch("vibrate", "vibrate", touchVibrate, column)
        if gameInfo.vibrateOn == nil then
            gameInfo.vibrateOn = true
        end
        if gameInfo.vibrateOn then
            device:enableVibration()
        else
            device:disableVibration()
            vibrateBtn.color = {75,85,110}
        end
    end
    
    -- position title to avoid buttons
    self.titleY = math.min(labelY + 110, self.btnY[1] + 240)
    self.title.y = self.titleY
    
    self.btnY = nil
    self.btnSize = nil
    
    -- start flickering effect but pause until menu is shown
    self:restartFlicker()
    
    if gameInfo.newHighScore then
        self.newDontClear = false --dont blur the high score controls (looks awful)
        self:setMenuState("highscores")
    else
        if startupFlag then
            startupFlag = false
            sceneMainMenu.sceneShown = true
            tween:from(self.title, {y=self.screenMinY-500, time=0.4, xScale=3, yScale=2, onComplete=enableMenu})
            system:addTimer(resizeCheck, 2, 1, 0)
        else
            tween:from(self.title, {y=self.screenMinY-500, time=0.4, onComplete=enableMenu})
        end
        
        for k,v in pairs(self.btns) do
            --tween:from(v, {yScale=0, time=0.3})
            v.yScale=0
        end
        
        local btnDelay = 0.2
        if self.btns["continue"] then
            tween:to(self.btns["continue"], {yScale=1, time=0.1, delay=btnDelay}) btnDelay=btnDelay+0.05
        end
        tween:to(self.btns["1pSurvival"], {yScale=1, time=0.1, delay=btnDelay}) btnDelay=btnDelay+0.05
        if self.btns["survival"] then
            tween:to(self.btns["survival"], {yScale=1, time=0.1, delay=btnDelay}) btnDelay=btnDelay+0.05
        end
        if self.btns["2pLocal"] then
            tween:to(self.btns["2pLocal"], {yScale=1, time=0.1, delay=btnDelay}) btnDelay=btnDelay+0.05
        end
        if self.btns["highscores"] then
            tween:to(self.btns["highscores"], {yScale=1, time=0.1, delay=btnDelay}) btnDelay=btnDelay+0.05
        end
        if self.btns["achievements"] then
            tween:to(self.btns["achievements"], {yScale=1, time=0.1, delay=btnDelay}) btnDelay=btnDelay+0.05
        end
        tween:to(self.btns["about"], {yScale=1, time=0.1, delay=btnDelay})
        
        tween:from(self.labelScore, {alpha=0, time=0.3})
        tween:from(self.labelHighScore, {alpha=0, time=0.3})
        
        tween:to(self.btns.facebook, {yScale=self.btns.facebook.defaultScale, time=0.1, delay=btnDelay})
        tween:to(self.btns.twitter, {yScale=self.btns.twitter.defaultScale, time=0.1, delay=btnDelay})
        
        if self.btns.rate then
            tween:to(self.btns.rate, {yScale=self.btns.rate.defaultScale, time=0.1, delay=btnDelay})
        end
        
        tween:to(self.btns.sound, {yScale=self.btns.sound.defaultScale, time=0.1, delay=btnDelay})
        
        if self.btns.vibrate then
            tween:to(self.btns.vibrate, {yScale=self.btns.vibrate.defaultScale, time=0.1, delay=btnDelay})
        end
        
        if self.btns.highscores_icon then
            tween:to(self.btns.highscores_icon, {yScale=self.btns.highscores_icon.defaultScale, time=0.1, delay=btnDelay})
        end
        
        if self.btns.achievements_icon then
            tween:to(self.btns.achievements_icon, {yScale=self.btns.achievements_icon.defaultScale, time=0.1, delay=btnDelay})
        end
        
        self:titleFlash()
    end
end

-- cancels any existing flicker animations, then sets up and pauses new ones,
-- waiting for titleFlash to resume them
function sceneMainMenu:restartFlicker()
    for k,v in pairs(self.title.letters) do
        cancelTimersOnNode(v)
        cancelTweensOnNode(v)
        if v.storeAlpha then --reset for safety
            v.alpha=v.storeAlpha
            v.strokeAlpha=v.storeStroke
            v.storeAlpha = nil
            v.storeStroke = nil
        end
        
        v.flickerMin = 50
        v.flickerMax = 150
        v.flickerStrokeAlpha = 0.3
        v:addTimer(FlickerFx, math.random(40,150)/10, 1)
        v:pauseTimers()
    end
end

function sceneMainMenu:titleFlash()
    local delay = 0.5
    self:flashEffect(self.title.letters, wrongColorBright, delay)
    delay = delay+0.2
    self:flashEffect(self.title.letters, wrongColorMid, delay)
    delay = delay+0.2
    self:flashEffect(self.title.letters, wrongColorDark, delay)
    delay = delay+0.2
    self:flashEffect(self.title.letters, wrongColorMid, delay)
    
    for k,v in pairs(self.title.letters) do
        v:resumeTimers()
    end
end

function sceneMainMenu:flashEffect(arrayOfNodes, color, delay)
    for k,v in ipairs(arrayOfNodes) do
        tween:to(v, {strokeColor=color, color=color, delay=delay, time=0.1})
        for kChild,vChild in pairs(v.children) do
            tween:to(vChild, {strokeColor=color, color=color, delay=delay+0.05, time=0.1})
        end
        delay = delay+0.1
    end
    return delay
end

function sceneMainMenu:enterPostTransition(event)
    dbg.print("sceneMainMenu:enterPostTransition")
    -- if we rest this in startUp or enterPreTransition, it would happen *before*
    -- battlescene's exitPreTransition!
    demoMode = false
    
    if not startupFlag then
        self:queueFullscreenEffect()
    end
    
    -- wait till now so isnt wiped instantly by pre scenes hide call!
    if showFrameRate and not frameRateOverlay.isShown() then
        dbg.print("showframe rate!")
        frameRateOverlay.showFrameRate({x = virtualResolution.userWinMinX+5, y = virtualResolution.userWinMinY+5, zOrder = 100, width = 100}) --debugging
    end
    
    -- show the sctual scores. menu title and state was set on setup but we wait for
    -- transiation over before showing scores
    if gameInfo.newHighScore then
        self:displayHighScores()
    elseif useAdverts and advertType == "banner" then
        system:addTimer(hideAdverts, 2, 1, 0)
    end

    sceneMainMenu.sceneShown = true
    
    -- Each "start" call may push data to flurry's server. Data is sent on
    -- start/pause/resume/exit dependign on platform - good to try to force
    -- push on re-entering menu.
    analytics:startSessionWithKeys()
end

function hideAdverts()
    ads:show(false)
end

function sceneMainMenu:exitPreTransition(event)
    dbg.print("sceneMainMenu:exitPreTransition")
    
    if showFrameRate then
        frameRateOverlay.hideFrameRate() --debugging
    end
    
    sceneMainMenu.sceneShown = false
    system:removeEventListener({"suspend", "resume", "update", "orientation"}, self)
    --system:removeEventListener({"suspend", "resume", "update"}, self)
end

function sceneMainMenu:exitPostTransition(event)
    dbg.print("sceneMainMenu:exitPostTransition")
    
    fullscreenEffectsOff(self)
    self.screenFxTimer = nil

    for k,v in pairs(self.btns) do
        v.touchArea = v.touchArea:removeFromParent()
    end
    self.btnsOrigin = destroyNodesInTree(self.btnsOrigin, true)
    self.btns = nil --members were just destroyed in tree above
    
    self.labelScore = destroyNode(self.labelScore)
    self.labelHighScore = destroyNode(self.labelHighScore)
    
    self.title = destroyNodesInTree(self.title, true)
    self.hills = nil --hills is child of title
    
    self:DestroyInfoText()
    self:releaseResources()
    collectgarbage("collect")
    director:cleanupTextures()
    
    dbg.print("sceneMainMenu:exitPostTransition done")
end

function sceneMainMenu:touch(event)
    if self.demoTimer and event.phase == "ended" then
        self.demoTimer:cancel()
        self.demoTimer = system:addTimer(startDemo, DEMO_TIMEOUT, 1)
    end
    --dbg.print("SYSTEM touch listener test - " .. event.phase .. " - x,y=" .. event.x .. "," .. event.y)
end

sceneMainMenu:addEventListener({"setUp", "enterPostTransition", "exitPreTransition", "exitPostTransition"}, sceneMainMenu)
