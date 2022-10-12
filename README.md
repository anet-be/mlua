# MLua - Lua for the MUMPS database

## Overview

MLua is a Lua language plugin the MUMPS database. It provides the means to call Lua from within M. Here is [more complete documentation](https://dev.anet.be/doc/brocade/mlua/html/index.html) of where this project is headed. MLua incorporates [lua-yottadb](https://github.com/orbitalquark/lua-yottadb/) so that Lua code written for that (per ydb's [Multi-Language Programmer's Guide](https://docs.yottadb.com/MultiLangProgGuide/luaprogram.html)) will also work with MLua.

Invoking a Lua command is easy:

```lua
$ ydb
YDB>do &mlua.lua("print('\nHello World!')")
Hello world!
```

Now let's access a ydb local. At the first print statement we'll intentionally create a Lua syntax error:

```lua
YDB>do &mlua.lua("ydb = require 'yottadb'")
YDB>set hello=$C(10)_"Hello World!"

YDB>write $&mlua.lua("print hello",.output)  ;print requires parentheses
-1
YDB>write output
Lua: [string "mlua(code)"]:1: syntax error near 'hello'

YDB>write $&mlua.lua("print(ydb.get('hello'))",.output)
Hello World!

0
YDB>write output

YDB>
```

Since all Lua code chunks are actually functions, you can also pass parameters and return values:

```lua
YDB>do &mlua.lua("print('\nparams:',...) return 'Done'",.out,,1,2)  w out
params:	1	2

Done
YDB>
```

For the sake of speed, it is also possible to pre-compile a function. If the string starts with '>', it is taken as the name of a global function to invoke, rather than a string to compile:

```lua
YDB>do &mlua.lua("function add(a,b) return a+b end")
YDB>do &mlua.lua(">add",.out,,3,4) w out
7
```



### Example Lua task

Let's use Lua to calculate the height of your neighbour's oak trees based on the length of their shadow and the angle of the sun. First we enter the raw data into ydb, then run Lua to fetch from ydb and calculate:

```lua
YDB>set ^oaks(1,"shadow")=10,^("angle")=30
YDB>set ^oaks(2,"shadow")=13,^("angle")=30
YDB>set ^oaks(3,"shadow")=15,^("angle")=45

YDB>do &mlua.lua("print() ydb.dump('^oaks')",.err) w err  ;NOTE: you will need to define ydb.dump() -- see the MLUA_INIT heading below
^oaks("1","angle")="30"
^oaks("1","shadow")="10"
^oaks("2","angle")="30"
^oaks("2","shadow")="13"
^oaks("3","angle")="45"
^oaks("3","shadow")="15"

YDB>do &mlua.lua("dofile 'tree_height.lua'",.err) w err  ;see file contents below
YDB>do &mlua.lua("print() show_oaks( ydb.key('^oaks') )",.err) w err
Oak 1 is 5.8m high
Oak 2 is 7.5m high
Oak 3 is 15.0m high

YDB>zwr ^oaks(,"height")
^oaks(1,"height")=5.7735026918963
^oaks(2,"height")=7.5055534994651
^oaks(3,"height")="15.0"
```

The function `show_oaks()` fetches data from ydb and calculates oak heights. It is defined in `oakheight.lua` as follows:

```lua
function show_oaks(oaks)
    for sub in oaks:subscripts() do
        oaktree=oaks(sub)
        height = oaktree('shadow').value * math.tan( math.rad(oaktree('angle').value) )

        print(string.format('Oak %s is %.1fm high', sub, height))
        oaktree('height').value = height  -- save back into ydb
    end
end
```

Further documentation of Lua's API for ydb is documented in ydb's [Multi-Language Programmer's Guide](https://docs.yottadb.com/MultiLangProgGuide/luaprogram.html), including locks and transactions.

### MLUA_INIT and ydb.dump()

You probably found that `ydb.dump()` doesn't work for you. That's because I cheated: I set up MLua to define that function on initialisation. This is a handy feature. Simply set environment variable `MLUA_INIT=@startup.lua` and it will run whenever &mlua creates a new lua_State -- it works just like Lua's standard LUA_INIT: set the variable to contain Lua code or a filepath starting with @.

My `startup.lua` file defines ydb.dump() as follows:

```lua
ydb = require 'yottadb'
function ydb.dump(glvn, ...)
  for node in ydb.nodes(tostring(glvn), ...) do
    print(string.format('%s("%s")=%q',
        glvn, table.concat(node, '","'), ydb.get(tostring(glvn), node)))
  end
end
```

You can add your own handy code at startup. For example, to avoid having to explicitly require the ydb library every time you run ydb+mlua, set `MLUA_INIT="ydb = require 'yottadb'"`

## API

Here is the list of supplied functions, [optional parameters in square brackets]:

- mlua.lua(code[,.output]\[,luaState]\[,param1]\[,...])
- mlua.open([.output])
- mlua.close(luaState)

**`mlua.lua()`** accepts a string of Lua code which it compiles and runs as a Lua 'chunk'. Note that Lua chunks are actually functions, so values may be returned and optional function parameters passed (param1, ...).

Be aware that all parameters are strings and are not automatically converted to Lua numbers. Parameters are currently limited to 8, but this may easily be increased in mlua.xc.

On success, `mlua.lua()` fills .output (if given) with the return value of the code chunk. If the return value is not a string, it is encoded as follows:

* nil ==> "" (empty string)
* boolean ==> "0" or "1"
* number ==> decimal string representation. Numbers >= 1e14 are coded as "1E+14": use M's unary + in front of them to force numeric interpretation
* string ==> a string which may contain NUL characters. It is truncated at 1048576 characters, the maximum YDB string length. This makes YDB allocate the whole 1MB for return data, but it's worth it since return strings this way is considerably faster than using ydb.set().
* other types ==> "(typename)"

If the luaState handle is missing or 0, mlua.lua() will run the code in the default global lua_State, automatically opening it the first time you call mlua.lua(). Alternatively, you can supply a luaState with a handle returned by mlua.open() (see below) to run code in a different lua_State.

On error, `mlua.lua()` returns nonzero and .output (if given) returns the error message. Note that the error value return is currently equal to -1. This may be enhanced in the future to also return positive integers equal to ERRNO or YDB errors whenever YDB functions called by Lua are the cause of the error. However, for now, all errors return -1 and any YDB error code is encoded into the error message just like any other Lua error (Lua 5.4 does not yet support coded or named errors).

**`mlua.open()`** creates a new 'lua_State' which contains a new Lua context, stack, and global variables, completely independent from other lua_States (see the Lua Reference Manual on the [Application Programmer Interface](https://www.lua.org/manual/5.4/manual.html#4)). `mlua.open()` returns a luaState handle which can be passed to mlua.lua(). On error, it returns zero and .output (if given) returns the error message.

**`mlua.close()`** can be called if you have finished using the lua_State, in order to free up any memory that a Lua_State has allocated, first calling any garbage-collection meta-methods you have introduced in Lua. It returns nothing, and cannot produce an error.



### Signals / Interrupts

MLua apps must treat signals with respect: a) apps mustn't use signals, and b) apps must handle the EINTR error by retrying when making [system calls that can return EINTR](https://stackoverflow.com/questions/25729901/system-calls-and-eintr-error-code). This is a fairly onerous requirement, but is necessary because ydb makes heavy use of signals. If you wish to buck this requirement, first read the ydb [Limitations on External Programs](https://docs.yottadb.com/ProgrammersGuide/extrout.html#limitations-on-the-external-program) and further notes on [Signals](https://docs.yottadb.com/MultiLangProgGuide/programmingnotes.html#signals).

The only systems functions that the Lua standard library calls which can return EINTR are (f)open/close/read/write. These affect only functions exposed by the io library. It would be worth adding MLua EINTR retry wrappers for all of these functions to prevent the user from having to retry every single I/O operation. This not been done yet.

### Thread Safety

Lua co-routines, are perfectly safe to use with ydb, since they are cooperative rather than preemptive.

However, multi-threaded applications must access ydb using [special C API functions](https://docs.yottadb.com/MultiLangProgGuide/programmingnotes.html#threads). MLua uses lua-yottadb which does not use these special functions, and so MLua must not be used in multi-threaded applications unless the application designer ensures that only one of the threads accesses the database. If there is keen demand, it would not be too much difficulty to upgrade lua-yottadb to use the thread-safe function calls, making MLua thread-safe. (Lua still requires, though, that each thread running Lua does so in a separate lua_State).

## Versions & Acknowledgements

MLua requires ydb 1.34 or higher and Lua 5.1 or higher.

MLua's primary author is Berwyn Hoyt. MLua incorporates [lua-yottadb](https://github.com/orbitalquark/lua-yottadb/) by [Mitchell](https://github.com/orbitalquark), which is based heavily on [YDBPython](https://gitlab.com/YottaDB/Lang/YDBPython). Both were sponsored by, and are copyright © 2022, [University of Antwerp Library](https://www.uantwerpen.be/en/library/). They are provided under the same license as YottaDB: the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.txt).

MLua also uses [Lua](https://www.lua.org/) (copyright © 1994–2021 Lua.org, PUC-Rio) and [YottaDB](https://yottadb.com/) (copyright © 2017-2019, YottaDB LLC). Both are available under open source licenses.

## Installation

Prerequisites: linux, gcc, yottadb
To run the benchmarks you also need: luarocks and python

1. Install YottaDB per the [Quick Start](https://docs.yottadb.com/MultiLangProgGuide/MultiLangProgGuide.html#quick-start) guide instructions or from [source](https://gitlab.com/YottaDB/DB/YDB).
2. git clone `<mlua repository>` mlua && cd mlua
3. make
4. sudo make install       # install MLua

If you also want to install the Lua version you just built into your system, do:

```shell
sudo make install-lua
```

You may also need to double-check that /usr/local/bin is in your path and/or run `hash lua` to refresh bash's cached PATH so it can find the new /usr/local/bin/lua.

If you need to use a different Lua version or install into a non-standard YDB directory, change the last line to something like:

```shell
sudo make install LUA_BUILD_VERSION=5.x.x YDB_DEST=<your_ydb_plugin_directory> LUA_LIB_INSTALL=/usr/local/lib/lua/x.x LUA_MOD_INSTALL=/usr/local/share/lua/x.x
```

MLua is implemented as a shared library mlua.so which also embeds Lua and the Lua library. There is no need to install Lua separately.

Instead of installing to the system, you can also install files into a local folder ready for deployment using `make install local`.

### Explanation

Here's what is going on in the installation.
Line 2 fetches the MLua code and makes it the working directory.
Line 3 downloads and then builds the Lua language, then it builds MLua.
Line 4 installs mlua.xc and mlua.so, typically into $ydb_dist/plugin, and _yottadb.so and yottadb.lua into the system lua folders

Check that everything is in the right place:

```shell
$ ls -1 `pkg-config --variable=prefix yottadb`/plugin/mlua.*
/usr/local/lib/yottadb/r134/plugin/mlua.so
/usr/local/lib/yottadb/r134/plugin/mlua.xc
$ ls -1 /usr/local/share/lua/*/yottadb.* /usr/local/lib/lua/*/_yottadb.*
/usr/local/lib/lua/5.4/_yottadb.so
/usr/local/share/lua/5.4/yottadb.lua
```

The ydb_env_set script provided by YDB, automatically provides the environment variables needed for YDB to access any plugin installed in the plugin directory shown here. For old releases of the database you may need to provide ydb_xc_mlua environment variable explicitly.

## TESTING

Simply type:

```shell
make test
```

To perform a set of speed tests, do:

```shell
make benchmarks
```

Some benchmarks are installed by the Makefile. Others will require manual installation of certain Lua modules: for example `luarocks install hmac` to get a SHA library for lua. But running `make benchmarks` will note these requirements for you. There is further comment on these benchmarks in the [benchmarks/README.md](benchmarks/README.md).

# Troubleshooting

### Trouble building MLua

1. Why can't it find <libyottadb.h>?

   Make sure you have the prerequisites installed, including the yottadb package.

### Trouble running MLua

1. Why do I get error: `ydb_xc_mlua/GTMXC_mlua not set`?

   This is an environment variable that is supposed to be set by `ydb_env_set` which is a script that is normally run when you type `ydb`. On my machine, `ydb` runs a bash script at /usr/local/lib/yottadb/r134/ydb which, in turn, sources `ydb_env_set`. That script is responsible to set the ydb_xc_mlua environment variables required for every ydb plugin in the ydb plugin directory. On my machine, for example, it sets: `ydb_xc_mlua=/usr/local/lib/yottadb/r134/plugin/mlua.xc`

   The fact that this is not being set for you may mean you're not running `ydb` the normal way. Perhaps you are running `yottadb` instead, without the `ydb` wrapper script. In that case you will need to create the `ydb_xc_mlua` environment variable yourself, to point to your mlua.xc file.

2. Why does running the example Lua code `ydb.dump('^oaks')` do nothing?

   Possibly because you have not defined the dump function, or have not done `ydb=require'yottadb'`. Check the documentation heading [MLUA_INIT and ydb.dump()](#mluainit-and-ydbdump).

   To see error messages, make sure you print the output variable like so: `do &mlua.lua("your_code",.out) w out`

