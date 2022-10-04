# MLua Benchmarks

From the benchmarks directory, run:

```shell
make
```

Requirements for some benchmarks are installed by the Makefile. Others will require manual installation of certain Lua modules: for example `luarocks install hmac` to get a SHA library for lua. But running `make` will note these requirements for you.

## SHA512

For comparison purposes, here are my benchmark results for calculation of SHA512:

```
REAL time measured
        data size:           10B           1kB           1mB  
shellSHA               2,656.7us     2,271.9us 1,445,201.9us 
pureluaSHA                22.9us       135.2us   117,398.4us 
luaCLibSHA                 2.0us         4.8us     3,197.0us 
cmumpsSHA                  4.1us         6.2us     2,175.6us 

USER time measured
        data size:           10B           1kB           1mB  
shellSHA               1,753.1us     1,601.2us    90,861.9us 
pureluaSHA                22.7us       135.6us   117,182.4us 
luaCLibSHA                 1.9us         4.8us     3,196.0us 
cmumpsSHA                  4.1us         6.3us     2,247.2us 
```

These are the results of performing the operations many times each in a tight M loop, run from YDB.

- **cmumpsSHA***, as expected, is our fastest option. It is a SHA512 library written in C and integrated directly into YDB (without Lua).

- **luaCLibSHA** uses the [hmac Lua library](https://github.com/mah0x211/lua-hmac), which is one of the many SHA libraries available for Lua, but written in C. It is invoked by YDB via MLua. Being C, it is comparable in speed to cmumpsSHA. Remarkably, this solution is actually the fastest option for small data sizes. This demonstrates that not only the algorithm, but also MLua, have a fast start-up time.
- **pureluaSHA*** is a [SHA512 library written in pure Lua](https://github.com/Egor-Skriptunoff/pure_lua_SHA/blob/master/sha2_test.lua). As expected, it is slower than the C version, but for a pure Lua implementation, it is actually quite fast. This library really shines when using LuaJIT (but this would require m-LuaJIT -- which is an interesting possibility for the future).
- **shellSHA*** is a SHA512 library written in Go as a command-line process. It is accessed from YDB by spawning a separate process and piping the data to it. That is why it is slow. Comparing its REAL and USER time, you can see that it spends most of its time performing system functions (presumably creating a process and piping).

These tests were run in Lua 5.4.4, on Linux kernel 5.4.0-117, with a 64-bit Intel© Core™ i7-8565U CPU @1.80GHz.

*Note: You may not be able to reproduce the shellSHA and cmumpsSHA results unless you have access to proprietary [Brocade software](https://www.uantwerpen.be/nl/projecten/anet/brocade/). I have, nevertheless, shown their results here as a discussion point.

## String Strip

Here are the benchmark results for different functions to strip strings:

```
USER time measured
        data size:           10B           1kB           1mB  
luaStripCharsPrm           1.1us         3.1us     2,204.0us 
luaStripCharsDb            3.2us         6.0us     2,074.1us 
cmumpsStripChars           0.4us        20.2us    19,822.6us 
mStripChars                2.6us        10.4us     7,779.9us 
```

These show several more facts of interest:

- **luaStripCharsPrm** is a very simple string strip() function using Lua pattern matching, essentially equal to `match(string, '^[<chars>]*(.*[^<chars>])')` except with a minor tweak to improve speed on blank strings. The string is passed in and returned via MLua function call parameters. It should be noted that since this implementation uses Lua's built-in string matching, it is essentially a C implementation inside some pretty Lua wrapping paper.
- **luaStripCharsDb** is the same only the string is not passed/returned in the MLua function call parameters. Instead, the Lua function fetches the string from a YDB local using ydb.get('string') and returns it using ydb.set('result', value). It takes three times as long for small strings. This shows that parameter passing is considerably faster than ydb get/set, and suggests that the efficiency of ydb.get/set should be investigated for improvement.
- **cmumpsStripChars** is a C implementation of strip(), called directly by YDB (not via MLua). This is the fastest solution with small strings, showing, as we expect, that the function call overhead for C is very small. However, for larger strings this function is less efficient, which suggests it could benefit from an improved algorithm.
- **mStripChars** is Brocade's native M implementation of strip(). This shows that M is no sluggard, but in the case of small strings, Lua wins -- probably because the M implementation requires many complex setup steps.

