# MLua Benchmarks

From the benchmarks directory, run:

```shell
make
```

Requirements for some benchmarks are installed by the Makefile. Others will require manual installation of certain Lua modules: for example `luarocks install hmac` to get a SHA library for lua. But running `make` will note these requirements for you.

For comparison, here are my benchmark results for calculation of SHA512:

```
REAL time measured
     data size:         1mB         1kB         10B  
goSHA           1,431,956us     3,271us     2,175us 
pureluaSHA        136,968us       158us        28us 
luaCLibSHA          3,279us         7us         3us 
cmumpsSHA           2,379us         6us         4us 

USER time measured
     data size:         1mB         1kB         10B  
goSHA              78,326us     1,921us     1,608us 
pureluaSHA        123,511us       144us        25us 
luaCLibSHA          3,152us         7us         3us 
cmumpsSHA           2,261us         6us         4us
```

These are the results of performing the operations many times each in a tight M loop, run from YDB.

- **cmumpsSHA***, as expected, is our fastest option. It is a SHA512 library written in C and integrated directly into YDB (without Lua).

- **luaCLibSHA** uses the [hmac Lua library](https://github.com/mah0x211/lua-hmac), which is one of the many SHA libraries for Lua written in C. It is invoked by YDB via MLua. Being C, it is comparable in speed to cmumpsSHA. Remarkably, this solution is actually the fastest option for small data sizes. This demonstrates that not only the algorithm, but also MLua, have a fast start-up time.
- **pureluaSHA*** is a [SHA512 library written in pure Lua](https://github.com/Egor-Skriptunoff/pure_lua_SHA/blob/master/sha2_test.lua). As expected, it is slower than the C version, but for a pure Lua implementation, it is actually quite fast.
- **goSHA*** is a SHA512 library written in Go as a command-line process. It is accessed from YDB by spawning a separate process and piping the data to it. That is why it is slow. Comparing its REAL and USER time, you can see that it spends most of its time performing system functions (presumably creating a process and piping).

These tests were run in Lua 5.4.4, on Linux kernel 5.4.0-117, with a 64-bit Intel© Core™ i7-8565U CPU @1.80GHz.

*Note: You may not be able to reproduce the goSHA and cmumpsSHA results unless you have access to proprietary [Brocade software](https://www.uantwerpen.be/nl/projecten/anet/brocade/). I have, nevertheless, shown their results here a a discussion point.

