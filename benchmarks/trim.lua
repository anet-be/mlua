-- trim implementations -- used to check which algorithm is fastest to use in MLua benchmarking
-- taken and modified from: http://lua-users.org/wiki/StringTrim
-- selected trim7 (see modifications in its second definition below)

function trim1(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end
-- from PiL2 20.4

function trim2(s)
   return s:match "^%s*(.-)%s*$"
end
-- variant of trim1 (match)

function trim3(s)
   return s:gsub("^%s+", ""):gsub("%s+$", "")
end
-- two gsub's

function trim4(s)
   return s:match"^%s*(.*)":match"(.-)%s*$"
end
-- variant of trim3 (match)

function trim5(s)
   return s:match'^%s*(.*%S)' or ''
end
-- warning: has bad performance when s:match'^%s*$' and #s is large

function trim6(s)
   return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end
-- fixes performance problem in trim5.
-- note: the '()' avoids the overhead of default string capture.
-- This overhead is small, ~ 10% for successful whitespace match call
-- alone, and may not be noticeable in the overall benchmarks here,
-- but there's little harm either.  Instead replacing the first `match`
-- with a `find` has a similar effect, but that requires localizing
-- two functions in the trim7 variant below.

local match = string.match
function trim7(s)
   return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
end

-- Version of above trim7 that lets you specifiy and arbitrary list of chars to strip, defaulting to whitespace
-- This function takes about twice as long as pure whitespace removal using Lua's standard pattern %s (shown above)
function trim7(s, pattern)
   if pattern==nil then pattern=' \t\r\n\f\v' end
   -- for short s strings, getting rid of the following line ('%' replacement) removes 20-40% overhead (40% if '%' is in pattern; otherwise 20%)
   if string.find(pattern, '%', 1, true) then pattern = string.gsub(pattern, '%%', '%%%%') end
   return match(s,'^()['..pattern..']*$') and '' or match(s,'^['..pattern..']*(.*[^'..pattern..'])')
end
-- variant of trim6 (localize functions)

local find = string.find
local sub = string.sub
function trim8(s)
   local i1,i2 = find(s,'^%s*')
   if i2 >= i1 then
      s = sub(s,i2+1)
   end
   local i1,i2 = find(s,'%s*$')
   if i2 >= i1 then
      s = sub(s,1,i1-1)
   end
   return s
end
-- based on penlight 0.7.2

function trim9(s)
   local _, i1 = find(s,'^%s*')
   local i2 = find(s,'%s*$')
   return sub(s, i1 + 1, i2 - 1)
end
-- simplification of trim8

function trim10(s)
   local a = s:match('^%s*()')
   local b = s:match('()%s*$', a)
   return s:sub(a,b-1)
end
-- variant of trim9 (match)

function trim11(s)
   local n = s:find"%S"
   return n and s:match(".*%S", n) or ""
end
-- variant of trim6 (use n position)
-- http://lua-users.org/lists/lua-l/2009-12/msg00904.html

function trim12(s)
   local from = s:match"^%s*()"
   return from > #s and "" or s:match(".*%S", from)
end
-- variant of trim11 (performs better for all
-- whitespace string). See Roberto's comments
-- on ^%s*$" v.s. "%S" performance:
-- http://lua-users.org/lists/lua-l/2009-12/msg00921.html

--~ do
--~    local lpeg = require("lpeg")
--~    local space = lpeg.S' \t\n\v\f\r'
--~    local nospace = 1 - space
--~    local ptrim = space^0 * lpeg.C((space^0 * nospace^1)^0)
--~    local match = lpeg.match
--~    function trim13(s)
--~       return match(ptrim, s)
--~    end
--~ end
-- lpeg.  based on http://lua-users.org/lists/lua-l/2009-12/msg00921.html

--~ do
--~    local lpeg = require("lpeg")
--~    local re = require("re")
--~    local ptrim = re.compile"%s* {(%s* %S+)*}"
--~    local match = lpeg.match
--~    function trim14(s)
--~       return match(ptrim, s)
--~    end
--~ end
-- variant with re module.

--~ require 'trim'
--~ local trim15 = trim
-- C implementation (see separate trim.c file)


-- test utilities

local function trimtest(trim)
   assert(trim'' == '')
   assert(trim' ' == '')
   assert(trim'  ' == '')
   assert(trim'a' == 'a')
   assert(trim' a' == 'a')
   assert(trim'a ' == 'a')
   assert(trim' a ' == 'a')
   assert(trim'  a  ' == 'a')
   assert(trim'  ab cd  ' == 'ab cd')
   assert(trim' \t\r\n\f\va\000b \r\t\n\f\v' == 'a\000b')
end

local function _perftest(f, s, n)
   local time = os.clock  -- os.time or os.clock
   local t1 = time()
   for i=1,n do
      f(s)
      f(s)
      f(s)
      f(s)
      f(s)
      f(s)
      f(s)
      f(s)
      f(s)
      f(s)
   end
   local dt = time() - t1
   return dt
end

local function perftest(f, s, n)
    if n == nil then n=10000 end
    dt = _perftest(f, s, n)
    io.stdout:write(("%4.0f"):format(dt*1000) .. " ")
    return dt
end

local trims = {trim1, trim2, trim3, trim4, trim5, trim6, trim7,
               trim8, trim9, trim10, trim11, trim12, trim13, trim14, trim15}

-- correctness tests
for _,trim in ipairs(trims) do
   trimtest(trim)
end

rand=require'randomMB' rand.randomMB()

-- performance tests
for j = 1, 3 do
   for i,trim in ipairs(trims) do
      io.stdout:write(string.format("%2d",i) .. ": ")
      perftest(trim,  "")
      perftest(trim,  "abcdef")
      perftest(trim,  "   abcdef   ")
      perftest(trim,  "abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef")
      perftest(trim,  "  a b c d e f g h i j k l m n o p q r s t u v w x y z A B C ")
      perftest(trim,  "                               a                            ")
      perftest(trim,  "                                                            ")
      perftest(trim,  rand.randomMB(), 3)
      print()
   end
end
