config =
{
    debug =
    {
        general = false,
        traceGC = false,
        typeChecking = true,
        assertDialogs = true,
        
        makePrecompiledLua = false,
        usePrecompiledLua = false, -- may speed up both load and execution time
        useConcatenatedLua = false, -- speeds up *load* times
    }
}
