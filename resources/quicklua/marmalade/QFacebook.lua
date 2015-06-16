--[[/*
 * (C) 2012-2013 Marmalade.
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */--]]

--------------------------------------------------------------------------------
-- Facebook singleton
--------------------------------------------------------------------------------
facebook = quick.QFacebook:new()

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
loginBehaviour = {
                "WithFallbackToWebView",     -- Attempt Facebook Login, ask user for credentials if necessary. Used by default.
                "WithNoFallbackToWebView",   -- Attempt Facebook Login, no direct request for credentials will be made.
                "ForcingWebView",            -- Only attempt WebView Login, ask user for credentials.
                "UseSystemAccountIfPresent", -- Attempt Facebook Login, preferring system account and falling back to fast app switch if necessary.
                "UseWebView"                 -- Similar to ForcingWebView but don't clear any token before opening.
                }
closeBehaviour = {
                "Simple",                   -- Merely close the session. Used by default
                "ClearToken"                -- On close, additionally clear any persisted token cache related to the session.
                }
--[[
/*!
*Shows facebook dialog with action and params
*
*/
]]
function facebook:showDialog(action, params)
    dbg.assertFuncVarType("string", action)
    dbg.assertFuncVarTypes({"table", "nil"}, params)

    -- Initialise the dialog
    if not facebook:_InitDialog(action) then
        return false
    end

    -- Set any parameters we were passed
    if params ~= nil then
        for i,v in pairs(params) do
            if type(v) == "string" then
                facebook:_AddDialogString( i, v)
            elseif type(v) == "number" then
                facebook:_AddDialogNumber( i, v)
            end
        end
    end

    -- do the dialog
    facebook:_ShowDialog()

    return true;

end

--[[
/*!
* Sends request
*/
]]
function facebook:request(methodorgraph, httpMethod, params)
    dbg.assertFuncVarType("string", methodorgraph)
    dbg.assertFuncVarTypes({"table", "nil"}, params)

    local retval
    if httpMethod == nil then
        httpMethod = "GET"
    end
    -- Initialise the request
    retval = facebook:_InitGraphRequest(methodorgraph, httpMethod)

    if not retval then
        return false
    end

    -- Set any parameters we were passed
    if params ~= nil then
        for i,v in pairs(params) do
            if type(v) == "string" then
                facebook:_AddRequestString( i, v)
            elseif type(v) == "number" then
                facebook:_AddRequestNumber( i, v)
            end
        end
    end

    -- do the dialog
    facebook:_SendRequest()

    return true
end

--------------------------------------------------------------------------------
-- Private API
--------------------------------------------------------------------------------
