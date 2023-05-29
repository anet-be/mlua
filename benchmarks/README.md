# MLua Benchmarks

These benchmarks enable speed comparisons between [Lua and M](#comparison-with-m) and [different lua-yottadb versions](#lua-yottadb-v1.2-compared-with-v2.0). It also shows the [cost of signal blocking](#signal-blocking) and compares various implementations of [practical tasks](#practical-tasks).

From the benchmarks directory, run:

```shell
make fetch benchmark
```

Requirements for some benchmarks are installed by the Makefile. Others will require manual installation of certain Lua modules: for example `luarocks install hmac` to get a SHA library for lua. But running `make` will note these requirements for you.

# Comparison with M

Below is a comparison between M and lua-yottadb (v2.1) doing basic loops through the database:

```lua
M   ^BCAT("lvd") traversal of 10000 subscripts in     1.7ms
Lua ^BCAT("lvd") traversal of 10000 subscripts in     4.0ms
Lua ^BCAT("lvd") traversal of 10000 nodes      in     7.5ms
M   LBCAT("lvd") traversal of 10000 subscripts in     0.7ms
Lua LBCAT("lvd") traversal of 10000 subscripts in     3.2ms
Lua LBCAT("lvd") traversal of 10000 nodes      in     5.6ms
M   ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in     2.4ms
Lua ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in     5.3ms
Lua ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 nodes      in    10.2ms
M   lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in     1.4ms
Lua lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in     4.3ms
Lua lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 nodes      in     7.9ms
M   ^tree traversal of 3905 records in     9.4ms
Lua ^tree traversal of 3905 records in     6.1ms: faster than M, surprisingly
M   ltree traversal of 3905 records in     8.2ms
Lua ltree traversal of 3905 records in     4.7ms: faster than M, surprisingly
```

- 'subscripts' means traversal of the bare text subscript name
- 'node objs' is similar traversal of subscripts but where a node object is returned for each subscript
- 'tree' means traversal of an entire database tree, including all subscripts and their sub-nodes

# Lua-yottadb v1.2 compared with v2.1

Lua-yottadb v2.0/2.1 included a significant efficiency rewrite. First, let's take baseline results from lua-yottadb v1.2:

```lua
26 Node creations in   228.2us
Lua ^BCAT("lvd") traversal of 10000 subscripts in    14.4ms
Lua ^BCAT("lvd") traversal of 10000 nodes      in    50.8ms
Lua LBCAT("lvd") traversal of 10000 subscripts in    13.6ms
Lua LBCAT("lvd") traversal of 10000 nodes      in    49.5ms
Lua ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in    22.6ms
Lua ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 nodes      in   108.4ms
Lua lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in    21.2ms
Lua lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 nodes      in   106.8ms
Lua ^tree traversal of 3905 records in    50.6ms
Lua ltree traversal of 3905 records in    46.6ms
```

Now compare with the results from lua-yottadb v2.1 which includes efficiency improvements:

```lua
 47x faster:    26 Node creations in     4.9us
3.6x faster:   Lua ^BCAT("lvd") traversal of 10000 subscripts in     4.0ms
6.8x faster:   Lua ^BCAT("lvd") traversal of 10000 nodes      in     7.5ms
4.3x faster:   Lua LBCAT("lvd") traversal of 10000 subscripts in     3.2ms
8.8x faster:   Lua LBCAT("lvd") traversal of 10000 nodes      in     5.6ms
5.3x faster:   Lua ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in     4.3ms
 11x faster:   Lua ^var("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 nodes      in    10.7ms
4.9x faster:   Lua lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 subscripts in     4.3ms
 14x faster:   Lua lvar("this","is","a","fair","number","of","subscripts","on","a","glvn") traversal of 10000 nodes      in     7.9ms
8.3x faster:   Lua ^tree traversal of 3905 records in     6.1ms
9.9x faster:   Lua ltree traversal of 3905 records in     4.7ms
```

# Signal blocking

If it is required, signal blocking (see [docs](https://github.com/anet-be/mlua#signals--eintr-errors)) does slow down MLua calls to M routines as seen below:

```lua
MLua calling overhead without signal blocking:     1.7us
MLua calling overhead with    signal blocking:     3.1us
```

# Practical tasks

## SHA512

For comparison purposes, here are my benchmark results for calculation of SHA512:

```lua
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

```lua
USER time measured
        data size:           10B           1kB           1mB  
luaStripCharsPrm           1.1us         3.1us     2,204.0us 
luaStripCharsDb            3.2us         6.0us     2,074.1us 
cmumpsStripChars           0.4us        20.2us    19,822.6us 
mStripChars                2.6us        10.4us     7,779.9us 
```

These show several more facts of interest:

- **luaStripCharsPrm** is a very simple string strip() function using Lua pattern matching, essentially equal to `match(string, '^[<chars>]*(.*[^<chars>])')` except with a minor tweak to improve speed on blank strings. The string is passed in and returned via MLua function call parameters. It should be noted that since this implementation uses Lua's built-in string matching, it is essentially a C implementation inside some pretty Lua wrapping paper.
- **luaStripCharsDb** is the same only the string is not passed/returned in the MLua function call parameters. Instead, the Lua function fetches the string from a YDB local using ydb.get('string') and returns it using ydb.set('result', value). It takes three times as long for small strings (since the version 2.0 efficiency improvements, it is now only 1.4 times as long).
- **cmumpsStripChars** is a C implementation of strip(), called directly by YDB (not via MLua). This is the fastest solution with small strings, showing, as we expect, that the function call overhead for C is very small. However, for larger strings this function is less efficient, which suggests it could benefit from an improved algorithm.
- **mStripChars** is Brocade's native M implementation of strip(). This shows that M is no sluggard, but in the case of small strings, Lua wins -- probably because the M implementation requires many complex setup steps.

