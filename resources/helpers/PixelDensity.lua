
-- This was written before dpi/PixelDensity existed.
-- Used to have hard coded values, adapted it to use new API.

require("helpers/Utility")

--Using Nexus 7 1st gen DPI as a reference... It's what I was using when I
--coded this, and its also close to the Android 1x DPI

pixelDensity = {}
pixelDensity.dpi = PixelDensity.GetScreenPPI()
if pixelDensity.dpi < 0 then
    PixelDensity.dpi = 216
end
pixelDensity.refDpi = 216

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