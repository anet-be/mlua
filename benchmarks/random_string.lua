#!/usr/bin/lua
-- Build a 1MB string of random characters
-- Must be fast (negligible) since it runs every benchmark speed test
-- Must be seeded so to be reproducable and compare 

twofifty = assert(load(
    'return string.char(' .. string.rep('math.random(0,255)', 250, ',') .. ')'
))

-- This takes about 46ms -- all characters random
function _randomMB()
    math.randomseed(1)
    t={}
    for i = 1,4000 do
        t[i] = twofifty()
    end
    return table.concat(t)
end

-- This takes about 0.15ms - repeats of a random sequence
function _randomMB_cheat()
    math.randomseed(1)
    return string.rep(twofifty(), 4000)
end

randomMB = _randomMB_cheat

function speed_test()
    for _ = 1,100 do
        randomMB()
    end
end
