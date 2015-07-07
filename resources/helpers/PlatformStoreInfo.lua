
function getPlatformVersion()
    local platform = device:getInfo("platform")
    local deviceId = device:getInfo("deviceID")

    -- version string is of form "OS name majorversion.minor.revision.etc"
    -- Could have spaces in OS name; could have arbitrary number of points in version;
    -- version might be a string like "XP2"! Following will work for Android and iOS...
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

    return versionMajor, versionMinor
end

function getStoreUrl(platform, majorVersion, minorVersion, appId, iosId)
    local storeUrl = nil
    local storeName = nil
    if platform == "ANDROID" then
        storeUrl = "market://details?id=" .. appId
        storeName = "google"
        -- TODO: else storeName = "amazon" etc
    elseif platform == "IPHONE" then
        storeName = "apple"
        if versionMajor >= 7 then
            storeUrl = "itms-apps://itunes.apple.com/app/" .. iosId
        else
            storeUrl = "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=" .. iosId .. "&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
        end
    end
    return storeUrl, storeName
end

-- use browser:launchURL(storeUrl) to go to store
