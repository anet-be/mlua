# MLua - Lua for the MUMPS database

## Overview

MLua is a Lua language plugin the MUMPS database. It provides the means to call Lua from whitin M. Here is [more complete documentation](https://dev.anet.be/doc/brocade/mlua/html/index.html) of where this project is headed. MLua is compatible with Lua versions >= 5.2. Older versions may work but are untested and would have to be built manually since the MLua Makefile does not know how to build them.

Basic operation is shown below:

```shell
$ ydb

YDB>do &mlua.lua("print('\nHello World!')",.output)
Hello world!


YDB>zwr
output=""

YDB>
```

Note that the optional .output parameter will contain any Lua error messages.

## License

MLua's primary author is Berwyn Hoyt. It was sponsored by, and is copyright © 2022, [University of Antwerp Library](https://www.uantwerpen.be/en/library/). It is provided under the same license as YottaDB: the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.txt).

MLua also uses [Lua](https://www.lua.org/) (copyright © 1994–2021 Lua.org, PUC-Rio) and [YottaDB](https://yottadb.com/) (copyright © 2017-2019, YottaDB LLC). Both are available under open source licenses.

## Installation

1. Install YottaDB per the
   [Quick Start](https://docs.yottadb.com/MultiLangProgGuide/MultiLangProgGuide.html#quick-start)
   guide instructions or from [source](https://gitlab.com/YottaDB/DB/YDB).
2. git clone `<mlua repository>` mlua && cd mlua
3. make
4. sudo make install       # install MLua
5. sudo make install-lua   # optional, if you also want to install the Lua version you built here into your system

If you need to use a different Lua version or install into a non-standard YDB directory, change the last line to something like:

```shell
sudo make install LUA_BUILD_VERSION=5.x.x YDB_DEST=<your_ydb_plugin_directory> LUA_LIB_INSTALL=/usr/local/lib/lua/x.x LUA_MOD_INSTALL=/usr/local/share/lua/x.x
```

MLua is implemented as a shared library mlua.so which also embeds Lua and the Lua library. There is no need to install Lua separately.

### Explanation

Here's what is going on in the installation.
Line 2 fetches the MLua code and makes it the working directory.
Line 3 downloads and then builds the Lua language, then it builds MLua.
Line 4 installs mlua.xc and mlua.so, typically into $ydb_dist/plugin, and _yottadb.so and yottadb.lua into the system lua folders

Check that everything is in the right place:

```shell
$ find `pkg-config --variable=prefix yottadb`/plugin -iname \*mlua\*
/usr/local/lib/yottadb/r134/plugin/mlua.so
/usr/local/lib/yottadb/r134/plugin/mlua.xc
```

The ydb_env_set script provided by YDB, automatically provides the environment
variables needed for YDB to access any plugin installed in the plugin directory shown here.
For old releases of the database you may need to provide
ydb_xc_mlua environment variable explicitly.

## TESTING

Simply type:

```shell
make test
```
