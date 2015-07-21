/*
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
 */

#include <string>
#include "stdio.h"

#include "QDefines.h"
#include "QDirector.h"
#include "QMain.h"
#include "QLuaHelpers.h"
#include "QPhysics.h"
#include "QSystem.h"

#include "cocos2d.h"

// Define this to run test code for Cocos2d-x
//#define COCOS2DX_TEST

#ifdef COCOS2DX_TEST
#include "cocos2d.h"
#include "QDirector.h"
USING_NS_CC;
#endif

#ifdef COCOS2DX_TEST
// Add includes for direct testing of COCOS2DX features
#include "CCScene.h"
#include "CCDirector.h"
#include "CCSprite.h"
#endif

// tolua stuff here, before namespace
#include "tolua++.h"
TOLUA_API int tolua_openquick_tolua_open(lua_State* tolua_S);

#ifdef MARMALADE
void MarmQuickInit();
void MarmQuickTerminate();
void MarmQuickUpdate();
void MarmQuickPrint(const char* pBuffer);
#endif

// Define this to run without "update" events being sent to Lua
//#define NO_UPDATE_EVENT

// Perform preprocessing of loaded Lua files
#define LUA_PREPROCESS

// Convert in-place "dbg." into "--g.".
static void LuaPreprocess_CommentDebug(char* buff)
{
#ifdef LUA_PREPROCESS
    char* pChar = buff;
    while((pChar = strstr(pChar, "dbg.")) != NULL)
    {
        pChar[0] = '-';
        pChar[1] = '-';
    }
#endif
}

USING_NS_CC;
QUICK_NAMESPACE_BEGIN;

luadbg g_Config = // map some stuff from Lua dbg table
{
    false,  // makePrecompiledLua
    false,  // usePrecompiledLua
    false,  // isDbgLoaded
    true,   // DEBUG
    false,  // ASSERTDIALOGS
};

MainCallback g_MainCallback = NULL;
std::string g_CurrentConcatFileFilename;
char* g_CurrentConcatFileData = NULL;
int g_CurrentConcatFileDataLen = 0;

static int MainBytecodeWriter(lua_State* L, const void* p, size_t size, void* u)
{
    return (fwrite(p,size,1,(FILE*)u)!=1) && (size!=0);
}

void startFileConcat(const char* filename)
{
    // Set filename and reset buffer
    g_CurrentConcatFileFilename = filename;
    g_CurrentConcatFileDataLen = 0;
    if (g_CurrentConcatFileData != NULL)
    {
        free(g_CurrentConcatFileData);
        g_CurrentConcatFileData = NULL;
    }
}

// Return current luacPrefix
const std::string& GetLuacPrefix()
{
    return luacPrefix;
}

// Check directory path to current luac directory. Will create missing directories
void CheckLuacDirPath(const std::string& guaranted_path, const std::string& out_filename)
{
    if (!guaranted_path.size()) return;
    std::string out = guaranted_path + out_filename;
    std::string tmp_path;
    int f = guaranted_path.size();
    do
    {
        f = out.find('/',f) + 1;
        if(!f) break;
        tmp_path = out.substr(0,f);
        if (!CheckDirectoryExists(tmp_path.c_str()))
            s3eFileMakeDirectory(tmp_path.c_str());
    }
    while(true);
}

// Checks is directory exists
s3eBool CheckDirectoryExists(const std::string& path)
{
    if (!path.size()) return true;
    s3eFileList* l = s3eFileListDirectory(path.c_str());
    if (!l)
        return false;
    s3eFileListClose(l);
    return true;
}

bool endFileConcat()
{
    // Remove debug info
    // Assume this function is only ever called after dbg.lua has been loaded, and therefore dbg.DEBUG has been set from config
    if (g_Config.DEBUG == false)
    {
        LuaPreprocess_CommentDebug(g_CurrentConcatFileData);
    }
#ifdef LUA_CREATE_CONCATENTATED_LUA_FILE
    // Save concatenated none precompiled lua file (TEST)
    std::string out_filename2 = g_CurrentConcatFileFilename;
    FILE* out2 = fopen(out_filename2.c_str(), "wb");
    fwrite(g_CurrentConcatFileData, g_CurrentConcatFileDataLen, 1, out2);
    fclose(out2);
#endif

    // Load to stack
    int s = luaL_loadbuffer(g_L, g_CurrentConcatFileData, g_CurrentConcatFileDataLen, g_CurrentConcatFileFilename.c_str());
    if (s)
    {
        QWarning("Failed to create concatenated lua file %s", g_CurrentConcatFileFilename.c_str());
        LUA_REPORT_ERRORS(g_L, s);
        return false;
    }

    // Precompile and save buffer
    std::string out_filename =
                                LUAC_PREFIX +
                                g_CurrentConcatFileFilename + "c";
    FILE* out = fopen(out_filename.c_str(), "wb");
    if (out == NULL)
    {
        QWarning("Failed to write concatenated precompiled lua file %s", out_filename.c_str());
        return false;
    }
    int ret = lua_dump(g_L, MainBytecodeWriter, out);
    fclose(out);
    lua_pop(g_L, 1);

    // Reset
    g_CurrentConcatFileFilename = "";
    g_CurrentConcatFileDataLen = 0;
    if (g_CurrentConcatFileData != NULL)
    {
        free(g_CurrentConcatFileData);
        g_CurrentConcatFileData = NULL;
    }

    return true;
}

bool isFileConcatInProgress()
{
    return (!g_CurrentConcatFileFilename.empty());
}

bool concatenateLuaFile(const char* filename)
{
    int file_size = (int)s3eFileGetFileInt(filename, S3E_FILE_SIZE);
    if (file_size <= 0)
    {
        return false;
    }

    int new_buff_size = g_CurrentConcatFileDataLen + file_size + 1; // +1 for newline
    char* buff = (char*)realloc(g_CurrentConcatFileData, new_buff_size + 1); // +1 for terminating null
    if (buff == NULL)
        return false;

    s3eFile* pFile = s3eFileOpen(filename, "rb");
    file_size = s3eFileRead(buff + g_CurrentConcatFileDataLen, 1, file_size, pFile);
    s3eFileClose(pFile);

    if (file_size <= 0)
    {
        return false;
    }

    g_CurrentConcatFileDataLen = g_CurrentConcatFileDataLen + file_size + 1;
    g_CurrentConcatFileData = buff;
    buff[g_CurrentConcatFileDataLen - 1] = '\n'; // We append a newline in case file ends with comment and not newline
    buff[g_CurrentConcatFileDataLen]     = '\0'; // Make sure concatenated line has terminating null

    return true;
}

bool MainLuaPrecompileFile(const char* filename)
{
#if defined(_MSC_VER) || (defined(__APPLE__) && defined(__MACH__))

    // Check to see if we are concatenating all files before we precompile
    if (isFileConcatInProgress())
        return concatenateLuaFile(filename);

    std::string out_filename = filename;
    out_filename = LUAC_PREFIX + out_filename;

    // Read file into buffer
    int fileSize = (int)s3eFileGetFileInt(filename, S3E_FILE_SIZE);
    if (fileSize <= 0)
    {
        return false;
    }

    char* buff = (char*)malloc(fileSize + 1);
    if (buff == NULL)
    {
        return false;
    }

    s3eFile* pFile = s3eFileOpen(filename, "rb");
    fileSize = s3eFileRead(buff, 1, fileSize, pFile);
    s3eFileClose(pFile);
    if (fileSize <= 0)
    {
        free(buff);
        return false;
    }
    buff[fileSize] = '\0';

    // Assume this function is only ever called after dbg.lua has been loaded, and therefore dbg.DEBUG has been set from config
//    if (g_Config.DEBUG == false)
    {
        LuaPreprocess_CommentDebug(buff);
    }

    // Load to stack
    int s = luaL_loadbuffer(g_L, buff, fileSize, filename);
    if (s)
    {
        QWarning("Failed to load lua file %s", filename);
        return false;
    }

    out_filename += "c";
    FILE* out = fopen(out_filename.c_str(), "wb");
    if (out == NULL)
    {
        QWarning("Failed to write precompiled lua file %s", out_filename.c_str());
        return false;
    }

    // Dump file to bytecode
    int ret = lua_dump(g_L, MainBytecodeWriter, out);
    fclose(out);

    lua_pop(g_L, 1);
    free(buff);

    if (ret != 0)
        return false;
#endif

    return true;
}


//------------------------------------------------------------------------------
// MainInit... and MainTerminate... functions
//------------------------------------------------------------------------------
std::string MainLuaLoadFile(const char* filename)
{
    std::string result; // This should help compilers to apply NRVO.

    // Read file into buffer
    int fileSize = (int)s3eFileGetFileInt(filename, S3E_FILE_SIZE);
    if (fileSize <= 0)
    {
        return result;
    }

    // We want to ensure the string starts with a commented filename; so that runtime errors in this chunk
    // can subsequently be traced back
    // UPDATE: THIS IS NO LONGER REQUIRED, AS THE LUA CODE CAN USE loadstring(string, filename)
    int namelength = 0; //= strlen(filename) + strlen("f(''); ");
    result.resize(fileSize + namelength + 1);

//    sprintf(buff, "f('%s'); ", filename);
    s3eFile* pFile = s3eFileOpen(filename, "rb");
    fileSize = s3eFileRead(&result[namelength], 1, fileSize, pFile);
    s3eFileClose(pFile);

    if (fileSize <= 0)
    {
        return result;
    }

    // Assume this function is only ever called after dbg.lua has been loaded, and therefore dbg.DEBUG has been set from config
    if (g_Config.DEBUG == false)
    {
        LuaPreprocess_CommentDebug(&result[0]);
    }
    return result;
}
//------------------------------------------------------------------------------
void MainLuaDoFile(const char* filename)
{
    // This is only called when loading Lua files from within the C++ code, NOT from Lua dofile()
//    std::string buff = MainLuaLoadFile(filename);

    // Assume dbg.lua already loaded, so we've overridden dofile()
    lua_getglobal(g_L, "dofile");
    lua_pushstring(g_L, filename);
    int s = lua_pcall(g_L, 1, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);

    // Execute
/*    int s = luaL_loadstring(g_L, buff.c_str());
    if (s)
    {
        // Load error
        QTrace("Failed to load file '%s'", filename); // don't use QWarning, as we don't want to get the callstack
        if (s == LUA_ERRSYNTAX)
        {
            const char* error = lua_tostring(g_L, lua_gettop(g_L));
            const char* processed = MainGetProcessedLuaError(error);
            QTrace("Lua error: %s", processed);
        }
    }
    else
    {
        // No load error
        s = lua_pcall(g_L, 0, 0, 0);
        LUA_REPORT_ERRORS(g_L, s);
    }*/
}
//------------------------------------------------------------------------------
//s3eFile* outputFile = NULL;
void MainOutputFlush()
{
//    s3eFileFlush(outputFile);
}
//------------------------------------------------------------------------------
const char* MainGetProcessedLuaCallStack()
{
    // Formated Lua's callstack
    if (g_L)
    {
        string callback_result = "Lua callstack:\n";
        lua_Debug entry;
        int depth = 0;
        char buff[LUABUFFSIZE];
        string substr_tmp;
        while (lua_getstack(g_L, depth, &entry))
        {
            int status = lua_getinfo(g_L, "Sln", &entry);
            sprintf(buff, "%s(%d): %s\n", entry.short_src, entry.currentline, entry.name ? entry.name : "?");
            depth++;

            substr_tmp.assign(buff);
            if(substr_tmp.find("dbg.lua") != string::npos ||
                substr_tmp.find("tail call") != string::npos ||
                substr_tmp.find("[C]") != string::npos)
            {
                substr_tmp.clear();
            }
            else if(substr_tmp.find(".lua(") != string::npos)
            {
                int st = substr_tmp.find(".lua(");
                int fn = substr_tmp.find(")", st);
                substr_tmp = "(\'" + substr_tmp.substr(1, st + 3) + "\'), line " + substr_tmp.substr(st + 5, fn - (st + 5)) + ": in function " + substr_tmp.substr(fn + 1, substr_tmp.size() - (fn + 1));
            }
            if(substr_tmp.size() > 0)
            {
                callback_result.append("\t" + substr_tmp);
            }
        }
        strlcpy(bufferedLuaMessage, callback_result.c_str(), (callback_result.size() < LUABUFFSIZE) ? callback_result.size() : LUABUFFSIZE);
        return bufferedLuaMessage;
    }
    else
        return "";
}
//------------------------------------------------------------------------------
const char* MainGetProcessedLuaError(const char* error)
{
    if (g_L)
    {
        string error_str = error;
        if(error_str.find(".lua:") != string::npos)
        {
            int st = error_str.find(".lua:");
            error_str = "(\'" + error_str.substr(1, st + 3) + "\'), line " + error_str.substr(st + 5, error_str.size() - (st + 5));
        }
        strlcpy(bufferedLuaMessage, error_str.c_str(), (error_str.size() < LUABUFFSIZE) ? error_str.size() : LUABUFFSIZE);
        return bufferedLuaMessage;
    }
    else
        return "";
}
//------------------------------------------------------------------------------
#ifndef MAX_ASSERT_STRING_LEN
#define MAX_ASSERT_STRING_LEN 1024
#endif
void MainAssertAppendLuaCallStack(char* pBuffer)
{
    // Use this function to append the current Lua debug.traceback() string to
    // an input string.
    if (!pBuffer)
        return;
    int32 lenBuffer = strlen(pBuffer);

    const char* luastack = MainGetProcessedLuaCallStack();
    int32 lenLua = strlen(luastack);

    char* pChar = pBuffer + lenBuffer;
    const char* pLua = luastack;
    while(pChar < pBuffer + MAX_ASSERT_STRING_LEN - 7)
    {
        if (pLua >= luastack + lenLua)
            break;

        if (*pLua == '\t')
            *pChar++ = ' ';
        else
            *pChar++ = *pLua;
        pLua++;
    }
    *pChar++ = '\0';
    if (pLua < luastack + lenLua)
//        strlcat(pBuffer, "<...>", MAX_ASSERT_STRING_LEN);
        strcat(pBuffer, "<...>");
}
//------------------------------------------------------------------------------
void MainPrint(char* pBuffer)
{
    // NOTE: CURRENTLY THIS IS UNUSED, AS LUA PRINT DOES NOT CALL THROUGH TO HERE
#ifdef MARMALADE
    MarmQuickPrint(pBuffer);
#else
    // Print to stdout
    QTrace(pBuffer);
#endif
}
//------------------------------------------------------------------------------
void MainInitLuaSystem()
{
    int tmp = 0;
    s3eConfigGetInt("QUICK","DeferRenderingOnStart", &tmp);
    if(!tmp)
        CCDirector::sharedDirector()->startRendering();
    // Initialise Lua itself
    QLuaInit();
}
//------------------------------------------------------------------------------
void MainTerminateLuaSystem()
{
    // Initialise Lua itself
    QLuaTerminate();
}
//------------------------------------------------------------------------------
const char* MainGetVersionString()
{
    // This is updated manually for each formal Quick release
    return "1.1";
}
//------------------------------------------------------------------------------
void MainInitLuaMiddleware(const char* configFilename)
{
    // Initialise tolua packages
    // This will register all bound symbols with Lua
    int r = tolua_openquick_tolua_open(g_L);

    // Load Lua files
    int s;

    // Log some blank lines, so it's easier to see where the *real* log starts
    printf("\n\n");

    // Log "QUICKLOG CPP: Marmalade Quick <version>"
    QTrace("Marmalade Quick %s", MainGetVersionString());

    // Log "QUICKLOG CPP: Loading app configuration..."
    QTrace("Loading app configuration...");

    // Our app config
    s = luaL_loadfile(g_L, "quicklua/QConfig.lua");
    if (s)
        QWarning("Failed to load QConfig.lua file");
    s = lua_pcall(g_L, 0, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);

    // Allow non-existence of config.lua
    FILE* pFile = fopen(configFilename, "rt");
    fclose(pFile);
    if (!pFile)
        QWarning("Failed to load config lua file");
    else
    {
        s = luaL_loadfile(g_L, configFilename);
        if (s)
            QWarning("Failed to load config lua file");
        s = lua_pcall(g_L, 0, 0, 0);
        LUA_REPORT_ERRORS(g_L, s);
    }

    // Initialise configuration
    lua_getglobal(g_L, "initConfig");
    s = lua_pcall(g_L, 0, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);

    // Log "QUICKLOG CPP: Loading Quick engine..."
    QTrace("Loading Quick engine...");

    // dbg.lua
    s = luaL_loadfile(g_L, "quicklua/dbg.lua");
    if (s)
        QWarning("Failed to load dbg.lua file");
    else
        g_Config.isDbgLoaded = true;
    s = lua_pcall(g_L, 0, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);

    // Read stuff from Lua dbg
    lua_getglobal(g_L, "dbg");
    lua_getfield(g_L, -1, "DEBUG");
    g_Config.DEBUG = lua_toboolean(g_L, -1);
    lua_settop(g_L, 0);

    lua_getglobal(g_L, "dbg");
    lua_getfield(g_L, -1, "ASSERTDIALOGS");
    g_Config.ASSERTDIALOGS = lua_toboolean(g_L, -1);
    lua_settop(g_L, 0);

    lua_getglobal(g_L, "dbg");
    lua_getfield(g_L, -1, "MAKEPRECOMPILEDLUA");
    g_Config.makePrecompiledLua = lua_toboolean(g_L, -1);
    lua_settop(g_L, 0);

    lua_getglobal(g_L, "dbg");
    lua_getfield(g_L, -1, "USEPRECOMPILEDLUA");
    g_Config.usePrecompiledLua = lua_toboolean(g_L, -1);
    lua_settop(g_L, 0);

    lua_getglobal(g_L, "dbg");
    lua_getfield(g_L, -1, "USECONCATENATEDLUA");
    g_Config.useConcatenatedLua = lua_toboolean(g_L, -1);
    lua_settop(g_L, 0);
// Here we set perfix for write and read from folders resources-concatenated and resources-precompiled
// If it's not debug it will write and read from rom:// or ram://

#ifdef _DEBUG
    int32 deviceID = s3eDeviceGetInt(S3E_DEVICE_OS);
    if (deviceID == S3E_OS_ID_WINDOWS || deviceID == S3E_OS_ID_OSX)
    {
        char ramPath[S3E_FILE_MAX_PATH];
        strcpy(ramPath, "");
        s3eFileGetFileString("rom://", S3E_FILE_REAL_PATH, ramPath, S3E_FILE_MAX_PATH);
        std::string tmp_path = ramPath;
        if(tmp_path.size())
        {
            int f = tmp_path.find_last_of('\\');
            tmp_path = tmp_path.substr(0, f);
            std::replace(tmp_path.begin(), tmp_path.end(), '\\', '/');
            if (g_Config.useConcatenatedLua)
                luacPrefix = "raw://" + tmp_path + "/resources-concatenated/";
            else
                if(g_Config.makePrecompiledLua || g_Config.usePrecompiledLua)
                    luacPrefix = "raw://" + tmp_path + "/resources-precompiled/";
            if (!CheckDirectoryExists(luacPrefix.c_str()))
                s3eFileMakeDirectory(luacPrefix.c_str());
        }
    }
#endif

#ifdef LUA_PREPROCESS
    if (g_Config.DEBUG == false)
        printf("config.debug.general = false. All 'dbg.' lines will become comments...");
#endif

#ifdef USER_INIT_PRE_OPENQUICK
    extern void QuickUserInitPreOpenQuick();
    QuickUserInitPreOpenQuick();
#endif

    // Our OpenQuick init
    s = luaL_loadfile(g_L, "quicklua/openquick.lua");
    if (s)
        QWarning("Failed to load openquick lua file");
    s = lua_pcall(g_L, 0, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);

    // Create the Director's global scene
    lua_getglobal(g_L, "director");
    lua_getfield(g_L, -1, "_createDefaultScene");    // On stack: director.createDefaultScene()
    lua_getglobal(g_L, "director");
    s = lua_pcall(g_L, 1, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);
    lua_pop(g_L, 2);

    // Create some of the cocos singletons up front
    CCTextureCache::sharedTextureCache();
    CCConfiguration::sharedConfiguration();

#ifdef COCOS2DX_TEST
//  CCScene* pScene = new CCScene();
//  pScene->init();
//    CCDirector::sharedDirector()->runWithScene((CCScene*)pScene);

//  CCSize ds = CCDirector::sharedDirector()->getVisibleSize();
//  CCTexture2D* pTex = CCTextureCache::sharedTextureCache()->addImage("textures/beachball.png");

//    #include "CCParticleSystemQuad.h"
//    CCParticleSystemQuad* pPS = new CCParticleSystemQuad();
//    pPS->initWithFile("particles/BoilingFoam.plist");
#endif
}
//------------------------------------------------------------------------------
void MainResetLuaMiddleware()
{
    int s;

    // Purge Quick director
    lua_getglobal(g_L, "director");
    lua_getfield(g_L, -1, "_purge");    // On stack: director._purge()
    lua_getglobal(g_L, "director");     // On stack: director._purge(self)
    s = lua_pcall(g_L, 1, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);
    lua_pop(g_L, 1);

    // Purge Quick system
    lua_getglobal(g_L, "system");
    lua_getfield(g_L, -1, "_purge");    // On stack: system._purge()
    lua_getglobal(g_L, "system");       // On stack: system._purge(self)
    s = lua_pcall(g_L, 1, 0, 0);
    LUA_REPORT_ERRORS(g_L, s);
    lua_pop(g_L, 1);

    // Force GC
    lua_gc(g_L, LUA_GCCOLLECT, 0);
}
//------------------------------------------------------------------------------
void MainTerminateLuaMiddleware()
{
    MainResetLuaMiddleware();

    CCDirector::sharedDirector()->end();
    CCDirector::sharedDirector()->mainLoop(); // purges Cocos2d-x director data
}
//------------------------------------------------------------------------------
void MainInitLuaApp(const char* mainFilename)
{
#ifndef COCOS2DX_TEST
    // Log "QUICKLOG CPP: Loading Quick app..."
    QTrace("Loading app...");

    MainLuaDoFile(mainFilename);
#endif

    // For scripts that create objects on first parse, we should sync all nodes
    // to ensure transforms are reasonable before Cocos2d-x draws the first frame
    if (g_L)
    {
#ifndef NO_UPDATE_EVENT
        lua_getglobal(g_L, "director");
        lua_getfield(g_L, -1, "update");    // On stack: director, director.update
        lua_remove(g_L, -2);
        int s = lua_pcall(g_L, 0, 0, 0);
        LUA_REPORT_ERRORS(g_L, s);
#endif
    }
    //BUG FIXING
    //this removes the iPhone flickering issue
    //please leave this here
    glDisable(GL_DEPTH_TEST);
}
//------------------------------------------------------------------------------
void MainTerminateLuaApp()
{
    // SEND LUA EVENT
    LUA_EVENT_PREPARE("exit");
    LUA_EVENT_SET_NUMBER("system", 1);  // system event
    LUA_EVENT_SEND();
}

//------------------------------------------------------------------------------
// Main update function
//------------------------------------------------------------------------------
void MainUpdate(float dt)
{
#ifdef COCOS2DX_TEST
    return;
#endif
    // Check Lua stack consistent
#ifdef _DEBUG
    static bool firstTop = true;
    static int firstVal = 0;
    if (g_L)
    {
        if (firstTop == true)
        {
            firstVal = lua_gettop(g_L);
            firstTop = false;
        }
        else
        {
            int ls = lua_gettop(g_L);
            QAssert(ls == firstVal, "Lua stack top is unexpected value: %d", ls);
        }
    }
#endif

    // Physics update
    if (physics::g_Sim)
        physics::g_Sim->Update(dt);

    // Call any externally-registered module, e.g. Quick
    if (g_MainCallback)
        g_MainCallback();

    // Schedule any scene switching before the next update
    if (g_QDirector != NULL)
        g_QDirector->RunScene();

    // Lua update
    if (g_L)
    {
#ifndef NO_UPDATE_EVENT
        lua_getglobal(g_L, "director");
        lua_getfield(g_L, -1, "update");    // Stack: director.update
        lua_getglobal(g_L, "director");     // Stack: director.update(self)
        LUA_REPORT_ERRORS(g_L, lua_pcall(g_L, 1, 0, 0));
        lua_pop(g_L, 1);

        // Throw update event
        LUA_EVENT_REUSE("update");
        LUA_EVENT_SEND();

        // IF USING EXPERIMENTAL EVENT QUEUE...
/*      lua_getglobal(g_L, "flushEvents");
        LUA_REPORT_ERRORS(g_L, lua_pcall(g_L, 0, 0, 0));*/
//        lua_pop(g_L, 1);
#endif
    }
}

QUICK_NAMESPACE_END;
