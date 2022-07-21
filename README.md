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

MLua was written by Berwyn Hoyt and sponsored by the University of Antwerp Library. It is provided under the same license as YottaDB: the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.txt).

MLua uses Lua which is under the [MIT License](https://www.lua.org/license.html), and YottaDB which may be obtained under the  [License - YottaDB](https://yottadb.com/product/license/).

## Installation

1. Install YottaDB per the
   [Quick Start](https://docs.yottadb.com/MultiLangProgGuide/MultiLangProgGuide.html#quick-start)
   guide instructions or from [source](https://gitlab.com/YottaDB/DB/YDB).
2. git clone `<mlua repository>` mlua && cd mlua
3. make
4. sudo make install

If you need to use a different Lua version or install into a non-standard YDB directory, change the last line to:

```shell
    sudo make install WORKING_LUA=lua-5.x.x INSTALL_DIR=<your_ydb_plugin_directory>
```

MLua is implemented as a shared library mlua.so which also embeds Lua and the Lua library. There is no need to install Lua separately.

### Explanation

Here's what is going on in the installation.

Line 2 fetches the MLua code and makes it the working directory.

Line 3 downloads and then builds the Lua language, then it builds MLua.

Line 4 installs mlua.xc and mlua.so into $ydb_dist/plugin.

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
