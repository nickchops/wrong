config =
{
    debug =
    {
        general = false,
        traceGC = false,
        typeChecking = true,
        assertDialogs = true,
        
        makePrecompiledLua = false,
        usePrecompiledLua = true, -- may speed up both load and execution time
        useConcatenatedLua = false, -- speeds up *load* times
    }
}
