#~ # Makefile to build MLua


# === Variable of interest to user

#Select which version of lua to build mlua against (all $(LUAS) are built)
WORKING_LUA = lua-5.4.4
#Select which version tag of lua-yottadb to fetch
LUA_YOTTADB_VERSION=master
LUA_YOTTADB_SOURCE=https://github.com/berwynhoyt/lua-yottadb.git

# List the latest Lua versions to download for later building against
# Works with lua >=5.2; older versions' makefiles differ enough that we'd have to change our invokation
LUAS := lua-5.4.4 lua-5.3.6 lua-5.2.4
LIBLUA = build/$(WORKING_LUA)/install/lib/liblua.a

YDB_DIST = $(shell pkg-config --variable=prefix yottadb)
INSTALL_DIR = $(ydb_dist)/plugin


# === Internal variables

# Make sure $(WORKING_LUA) is included in $(LUAS)
LUAS := $(filter-out $(WORKING_LUA), $(LUAS)) $(WORKING_LUA)

YDB_FLAGS = $(shell pkg-config --cflags yottadb)
LUA_FLAGS = -Ibuild/$(WORKING_LUA)/install/include -Wl,--library-path=build/$(WORKING_LUA)/install/lib -Wl,-l:liblua.a
LDFLAGS = -lm -ldl -lyottadb -L$(YDB_DIST)
CFLAGS = -fPIC -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS)

CC = gcc
# Decide command whether to use apt-get or yum to fetch readline lib
FETCH_LIBREADLINE = $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)

#Prevent deletion of targets -- and prevent rebuilding when phony target WORKING_LUA is a dependency
.SECONDARY:
#Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
.DELETE_ON_ERROR:


all: lua build
build: mlua.so

%: %.c *.h mlua.so $(LIBLUA)
	$(CC) $< -o $@  $(CFLAGS) $(LDFLAGS)

mlua.o: mlua.c $(WORKING_LUA)
	$(CC) -c $<  -o $@ $(CFLAGS) $(LDFLAGS)

mlua.so: mlua.o _yottadb.o $(LIBLUA)
	@# include entire liblua.a into mlua.so so we can call entire lua API
	$(CC) $< -o $@  -shared  -Wl,--whole-archive  $(LIBLUA)  -Wl,--no-whole-archive


# ~~~ Lua: fetch lua versions and build them

lua: $(WORKING_LUA)
luas: $(LUAS)
lua-%: build/lua-%/install/lib/liblua.a ;

build/lua-%/install/lib/liblua.a: /usr/include/readline/readline.h  build/lua-%/Makefile
	@echo Building $@
	@# tweak the standard Lua build with flags to make sure we can make a shared library (-fPIC)
	@# readline demanded only by lua <5.4 but override to included in all versions -- anticipating an interactive 'mlua' tool
	$(MAKE) --directory=build/lua-$*  linux  test local  MYCFLAGS="-fPIC"  MYLIBS="-Wl,-lreadline"  SYSCFLAGS="-DLUA_USE_LINUX -DLUA_USE_READLINE"
	@echo

build/lua-%/Makefile:
	@echo Fetching $(dir $@)
	mkdir -p $(dir $@)
	wget --directory-prefix=build --no-verbose "http://www.lua.org/ftp/lua-$*.tar.gz" -O build/lua-$*.tar.gz
	tar --directory=build -zxf build/lua-$*.tar.gz
	rm -f build/lua-$*.tar.gz
	@echo
.PRECIOUS: build/lua-%/Makefile

# get readline (required by lua 5.4 Makefiles, though not included in the library we build; anyway, it's useful if luac is used)
/usr/include/readline/readline.h:
	@echo "Installing readline"
	$(FETCH_LIBREADLINE)
.PRECIOUS: /usr/include/readline/readline.h

clean-luas: $(patsubst build/lua-%,clean-lua-%,$(wildcard build/lua-[0-9]*)) ;
clean-lua-%: build/lua-%/README
	$(MAKE) --directory=build/lua-$* clean
	rm -rf build/lua-$*/install
.PRECIOUS: build/lua-%/README


# ~~~ Lua-yottadb: fetch lua-yottadb and build it

lua-yottadb: _yottadb.o
_yottadb.o: build/lua-yottadb/_yottadb.c $(WORKING_LUA)
	@echo Building $@
	$(CC) -c $<  -o $@  $(CFLAGS) $(LDFLAGS)  -Wno-return-type -Wno-unused-but-set-variable -Wno-discarded-qualifiers

build/lua-yottadb/_yottadb.c:
	@echo Fetching $(dir $@)
	git clone --branch "$(LUA_YOTTADB_VERSION)" "$(LUA_YOTTADB_SOURCE)" $(dir $@)
.PRECIOUS: build/lua-yottadb/_yottadb.c


# ~~~ Debug

# Print out all variables defined in this makefile
vars:
	@echo -e $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), '\n$(v)=$(value $(v))' ) )

allvars:
	@echo -e $(foreach v,$(.VARIABLES), '\n$(v)=$(value $(v))' )


# ~~~ Clean

# clean just our own mlua build
clean:
	rm -f *.o *.so try
	rm -rf tests

# clean everything we've built
cleanall: clean clean-luas clean-lua-yottadb

# clean & wipe build directory, including external downloads -- as if we'd only just now checked out the mlua source for the first time
refresh: clean
	rm -rf build


# ~~~ Test

test:
	mkdir -p tests
	python3 test.py
	env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"


# ~~~ Install

install: install-$(WORKING_LUA) ;
install-lua-%: mlua.so mlua.xc
	sudo cp $^ $(INSTALL_DIR)


.PHONY: lua luas lua-%  lua-yottadb  all build test vars install install-lua-%
.PHONY: clean clean-luas clean-lua-% refresh
