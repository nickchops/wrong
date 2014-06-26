config =
{
    debug =
    {
        general = false,
        traceGC = false,
        typeChecking = false,
        assertDialogs = false,
        
        makePrecompiledLua = false,
        usePrecompiledLua = true, -- may speed up both load and execution time
        useConcatenatedLua = true, -- speeds up *load* times
    }
}
