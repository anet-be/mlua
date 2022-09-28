# Makefile to build MLua


# ~~~ Variables of interest to user

# Select which specific version of lua to download and build MLua against, eg: 5.4.4, 5.3.6, 5.2.4
# MLua works with lua >=5.2; older versions have not been tested
LUA_BUILD_VERSION:=5.4.4

# Select Lua binary and get its version
LUA:=lua
LUA_VERSION:=$(shell $(LUA) -e 'print(string.match(_VERSION, " ([0-9]+[.][0-9]+)"))')
# location to install mlua module to: .so and .lua files, respectively
LUA_LIB_INSTALL=/usr/local/lib/lua/$(LUA_VERSION)
LUA_MOD_INSTALL=/usr/local/share/lua/$(LUA_VERSION)

# Select which version tag of lua-yottadb to fetch
LUA_YOTTADB_VERSION=master
LUA_YOTTADB_SOURCE=https://github.com/berwynhoyt/lua-yottadb.git

YDB_DIST = $(shell pkg-config --variable=prefix yottadb)
YDB_INSTALL = $(YDB_DIST)/plugin

# ~~~  Internal variables

LIBLUA = build/lua-$(LUA_BUILD_VERSION)/install/lib/liblua.a
YDB_FLAGS = $(shell pkg-config --cflags yottadb)
LUA_FLAGS = -Ibuild/lua-$(LUA_BUILD_VERSION)/install/include -Wl,--library-path=build/lua-$(LUA_BUILD_VERSION)/install/lib -Wl,-l:liblua.a
LDFLAGS = -lm -ldl -lyottadb -L$(YDB_DIST)
CFLAGS = -fPIC -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS)

CC = gcc
# bash and GNU sort required for LUA_BUILD_VERSION comparison
SHELL=bash
$(if $(shell sort -V /dev/null 2>&1), $(error "GNU sort >= 7.0 required to get the -V option"))

# Decide command whether to use apt-get or yum to fetch readline lib
FETCH_LIBREADLINE = $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)

# Check validity of generated LUA_VERSION
ifeq ($(LUA_VERSION),)
 $(error LUA_VERSION string is empty: possibly could not generate it because Lua binary ($(LUA)) could not run?))
endif


#Prevent deletion of targets -- and prevent rebuilding when phony target LUA_BUILD_VERSION is a dependency
.SECONDARY:
#Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
.DELETE_ON_ERROR:


all: lua lua-yottadb build
build: mlua.so  # build our stuff only

%: %.c *.h mlua.so $(LIBLUA)
	$(CC) $< -o $@  $(CFLAGS) $(LDFLAGS)

mlua.o: mlua.c lua-$(LUA_BUILD_VERSION)
	$(CC) -c $<  -o $@ $(CFLAGS) $(LDFLAGS)

mlua.so: mlua.o $(LIBLUA)
	@# include entire liblua.a into mlua.so so we can call entire lua API
	$(CC) $< -o $@  -shared  -Wl,--whole-archive  $(LIBLUA)  -Wl,--no-whole-archive


# ~~~ Lua: fetch lua versions and build them

lua: lua-$(LUA_BUILD_VERSION)
lua-%: build/lua-%/install/lib/liblua.a ;

# Set LUA_BUILD_TARGET to 'linux' or if LUA_BUILD_VERSION >= 5.4.0, build target is 'linux-readline'
LUA_BUILD_TARGET:=linux$(shell echo -e " 5.4.0 \n $(LUA_BUILD_VERSION) " | sort -CV && echo -readline)

build/lua-%/install/lib/liblua.a: /usr/include/readline/readline.h  build/lua-%/Makefile
	@echo Building $@
	@# tweak the standard Lua build with flags to make sure we can make a shared library (-fPIC)
	@# readline demanded only by lua <5.4 but override to included in all versions -- handy if we install this lua to the system
	$(MAKE) -C build/lua-$*  $(LUA_BUILD_TARGET)  MYCFLAGS="-fPIC"  local
	@echo

build/lua-%/Makefile:
	@echo Fetching $(dir $@)
	mkdir -p $(dir $@)
	wget --directory-prefix=build --no-verbose "https://www.lua.org/ftp/lua-$*.tar.gz" -O build/lua-$*.tar.gz
	tar --directory=build -zxf build/lua-$*.tar.gz
	rm -f build/lua-$*.tar.gz
	@echo
.PRECIOUS: build/lua-%/Makefile

# get readline (required by lua <5.4 Makefiles, though not included in the library we build; anyway, it's useful if built lua gets installed to the system)
/usr/include/readline/readline.h:
	@echo "Installing readline"
	$(FETCH_LIBREADLINE)
.PRECIOUS: /usr/include/readline/readline.h

clean-luas: $(patsubst build/lua-%,clean-lua-%,$(wildcard build/lua-[0-9]*)) ;
clean-lua-%: build/lua-%/README
	$(MAKE) -C build/lua-$* clean
	rm -rf build/lua-$*/install
.PRECIOUS: build/lua-%/README


# ~~~ Lua-yottadb: fetch lua-yottadb and build it

lua-yottadb: _yottadb.so yottadb.lua
_yottadb.so: build/lua-yottadb/_yottadb.c lua-$(LUA_BUILD_VERSION)
	@echo Building $@
	$(CC) $<  -o $@  -shared  $(CFLAGS) $(LDFLAGS)  -Wno-return-type -Wno-unused-but-set-variable -Wno-discarded-qualifiers

yottadb.lua: build/lua-yottadb/_yottadb.c
	cp build/lua-yottadb/yottadb.lua $@

build/lua-yottadb/_yottadb.c:
	@echo Fetching $(dir $@)
	git clone --branch "$(LUA_YOTTADB_VERSION)" "$(LUA_YOTTADB_SOURCE)" $(dir $@)
.PRECIOUS: build/lua-yottadb/_yottadb.c

clean-lua-yottadb:
	rm -f _yottadb.so yottadb.lua

# ~~~ Debug

# Print out all variables defined in this makefile
# Warning: these don't work if a variable contains single quotes
vars:
	@echo -e $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), '\n$(v)=$(value $(v))') )
# Print all vars including those defined by make itself and environment variables
allvars:
	@echo -e $(foreach v,"$(.VARIABLES)", '\n$(v)=$(value $(v))' )


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
	#env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"

benchmarks:
	$(MAKE) -C benchmarks
test_lua_only:
	$(MAKE) -C benchmarks test_lua_only


# ~~~ Install

install: mlua.so mlua.xc _yottadb.so yottadb.lua
	@test "`whoami`" = root || ( echo "You must run 'make install' as root" && false )
	@echo lua-$(LUA_BUILD_VERSION) | grep -q "\-$(LUA_VERSION)" || ( \
		echo "Cannot install MLua (which is built against lua-$(LUA_BUILD_VERSION)) into the target Lua (which is version $(LUA_VERSION))." && \
		echo "Either change your Lua install target in the Makefile or install the version of Lua that you have built against, using 'make install-lua'." && \
		false )
	install -D mlua.so mlua.xc -t $(YDB_INSTALL)
	install -D _yottadb.so -t $(LUA_LIB_INSTALL)
	install -D yottadb.lua -t $(LUA_MOD_INSTALL)

install-lua: build/lua-$(LUA_BUILD_VERSION)/install/lib/liblua.a
	@echo Installing Lua $(LUA_BUILD_VERSION) to your system
	@test "`whoami`" = root || ( echo "You must run 'make install' as root" && false )
	$(MAKE) -C build/lua-$(LUA_BUILD_VERSION)  install


.PHONY: lua lua-%  lua-yottadb  all build test vars install install-lua-% benchmarks test_lua_only
.PHONY: clean clean-luas clean-lua-% clean-lua-yottadb refresh
