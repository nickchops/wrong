config =
{
    debug =
    {
        general = true,
        traceGC = false,
        typeChecking = true,
        assertDialogs = true,
        
        makePrecompiledLua = true,
        usePrecompiledLua = false, -- may speed up both load and execution time
        useConcatenatedLua = false, -- speeds up *load* times
    }
}
