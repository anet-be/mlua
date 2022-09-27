#!/usr/bin/lua
-- Build a 1MB string of random characters
-- Must be fast (negligible) since it runs every benchmark speed test
-- Must be seeded so as to be reproducable and compare answers between runs -- can't use M which has no seed
-- Must be UTF-8 characters for brocr and M functions, so output ASCII only

local twofifty = assert(load(
    -- Should be able to include NUL chars but don't since current versions of yottalua don't support ydb.set() to a string with NULs
    'return string.char(' .. string.rep('math.random(1,127)', 250, ',') .. ')'
))

-- This takes about 46ms -- all characters random (takes 300ms in M)
local function _randomMB()
    math.randomseed(1)
    t={}
    for i = 1,4000 do
        t[i] = twofifty()
    end
    return table.concat(t)
end

-- This takes about 0.15ms - repeats of a random sequence (takes 0.3ms in M)
local function _randomMB_cheat()
    math.randomseed(1)
    return string.rep(twofifty(), 4000)
end

local randomMB = _randomMB_cheat

local function speed_test(func)
    if func==nil then func=randomMB end
    time = os.clock  -- os.time or os.clock
    t1 = time()
    for _ = 1,100 do
        func()
    end
    delta = (time() - t1) / 100
    print(delta .. ' seconds per iteration')
end

return {
    randomMB = randomMB,
    _randomMB = _randomMB,
    _randomMB_cheat = _randomMB_cheat,
    speed_test=speed_test,
}
