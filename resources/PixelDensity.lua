

require("Utility")

--TODO: Should create and extension to expose Android DPI API but for now will
--hard code and guess. github/marmalade/dpi is old but on right track...
--Can easily hard code for iOS from the device type.
--Desktop (not Surface!) and tv not important as uses keyboard/pad

--Some useful DPI webpages:
--http://theiphonewiki.com/wiki/IPhone
--http://theiphonewiki.com/wiki/IPad
--http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density#Apple
--http://docs.madewithmarmalade.com/display/MD/iOS+specific+functionality+and+tips#id-iOSspecificfunctionalityandtips-DeviceIDvalues
--http://dpi.lv/

--Using Nexus 7 1st gen DPI as default. It's close to the Android 1x DPI
--reference (160) and I happen to have one to test!

local pixelDensity = {}
pixelDensity.dpi = 216
pixelDensity.refDpi = 216


local platform = device:getInfo("platform")
local deviceId = device:getInfo("deviceID")

if platform == "ANDROID" then
    if deviceId == "Nexus 7" then
        --1st and 2nd gen have same ID! 1st is 216ppi
        --Assume always 7 inch so scale for any future models too
        --Use width since on screen bar is at bottom on tablets
        --and size could change with future OS versions
        pixelDensity.dpi = 216/1280*director.displayWidth
    elseif deviceId == "Nexus 10" then --TODO: confirm this guess is correct ID!
        pixelDensity.dpi = 300/2560*director.displayWidth
    elseif devieId == "GT-P5210" then --Galaxy Tab 3 10"
        pixelDensity.dpi = 149
        
     -- some fallbacks
    elseif director.displayWidth <= 720 then
        pixelDensity.dpi = 316 --720p or lower res phone
    else
        pixelDensity.dpi = 445 --1080p or higher phones
    end
elseif platform == "IPHONE" then
    --iOS has lots of device IDs (different anenna etc) and numbering doesn't
    --match public names
    if director.displayWidth == 480 then
        --iPhone 1->3gs & matching iPods
        pixelDensity.dpi = 163
    elseif director.displayHeight == 640 then
        --iPhone/iPod Retina
        pixelDensity.dpi = 326
    elseif director.displayHeight == 768 then
        if string.startswith(deviceId, "iPad1") or deviceId == "iPad2,1" or deviceId == "iPad2,2"
                or deviceId == "iPad2,3" or deviceId == "iPad2,4" then --ipad 1&2
            pixelDensity.dpi = 132
        else -- 1st gen iPad Mini (iPad2,5 onwards)
            pixelDensity.dpi = 163
        end
    elseif deviceId == "iPad4,4" or deviceId == "iPad4,5" then --retina mini
        pixelDensity.dpi = 326
    elseif string.startswith(deviceId, "iPhone") or string.startswith(deviceId, "iPod") then
        --future proof guess! iPhone 6 likely same DPI as 5 but with larger screen
        --estimated screen size is 4.7 inch, maybe another larger version too
        --assuming f pixel count gets v high then DPI 
        if director.displayHeight < 1280 then
            pixelDensity.dpi = 326
        else
            pixelDensity.dpi = 456 -- = double iphone 5 resolution, on a 5 inch device!
        end
    else -- retina ipad
        pixelDensity.dpi = 264
    end
end

--set a reference DPI to work in and then allow other sizes to be scaled
--with getSize()
function pixelDensity:setReferenceDpi(dpi)
    self.refDpi = dpi
end

--pass size in reference dpi scale and get back for current device scale
function pixelDensity:getSize(x)
    return x/self.refDpi*self.dpi
end

return pixelDensity