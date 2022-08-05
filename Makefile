#~ # Makefile to build MLua


# ~~~ Variables of interest to user

# Select which specific version of lua to build MLua against, eg: lua-5.4.4, lua-5.3.6, lua-5.2.4
# Works with lua >=5.2; older versions' makefiles differ enough that we'd have to change our invokation
LUA_REVISION:=lua-5.4.4
LIBLUA = build/$(LUA_REVISION)/install/lib/liblua.a

# Select Lua binary and location to install MLua module to
LUA:=lua
LUA_VERSION:=$(shell $(LUA) -e 'print(string.match(_VERSION, " ([0-9]+[.][0-9]+)"))')
LUA_LIB_INSTALL=/usr/local/lib/lua/$(LUA_VERSION)			# where .so file installs
LUA_MOD_INSTALL=/usr/local/share/lua/$(LUA_VERSION)	# where .lua file installs

# Select which version tag of lua-yottadb to fetch
LUA_YOTTADB_VERSION=master
LUA_YOTTADB_SOURCE=https://github.com/berwynhoyt/lua-yottadb.git

YDB_DIST = $(shell pkg-config --variable=prefix yottadb)


# ~~~  Internal variables

YDB_FLAGS = $(shell pkg-config --cflags yottadb)
LUA_FLAGS = -Ibuild/$(LUA_REVISION)/install/include -Wl,--library-path=build/$(LUA_REVISION)/install/lib -Wl,-l:liblua.a
LDFLAGS = -lm -ldl -lyottadb -L$(YDB_DIST)
CFLAGS = -fPIC -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS)

CC = gcc
# Decide command whether to use apt-get or yum to fetch readline lib
FETCH_LIBREADLINE = $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)

# Check validity of generated LUA_VERSION
ifeq ($(LUA_VERSION),)
 $(error Generated empty LUA_VERSION string: possibly because Lua binary ($(LUA)) could not run))
endif


#Prevent deletion of targets -- and prevent rebuilding when phony target LUA_REVISION is a dependency
.SECONDARY:
#Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
.DELETE_ON_ERROR:


all: lua build
build: mlua.so

%: %.c *.h mlua.so $(LIBLUA)
	$(CC) $< -o $@  $(CFLAGS) $(LDFLAGS)

mlua.o: mlua.c $(LUA_REVISION)
	$(CC) -c $<  -o $@ $(CFLAGS) $(LDFLAGS)

mlua.so: mlua.o $(LIBLUA)
	@# include entire liblua.a into mlua.so so we can call entire lua API
	$(CC) $< -o $@  -shared  -Wl,--whole-archive  $(LIBLUA)  -Wl,--no-whole-archive


# ~~~ Lua: fetch lua versions and build them

lua: $(LUA_REVISION)
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

lua-yottadb: _yottadb.so yottadb.lua
_yottadb.so: build/lua-yottadb/_yottadb.c $(LUA_REVISION)
	@echo Building $@
	$(CC) -c $<  -o $@  -shared  $(CFLAGS) $(LDFLAGS)  -Wno-return-type -Wno-unused-but-set-variable -Wno-discarded-qualifiers

yottadb.lua: build/lua-yottadb/_yottadb.c
	cp build/lua-yottadb/yottadb.lua $@

build/lua-yottadb/_yottadb.c:
	@echo Fetching $(dir $@)
	git clone --branch "$(LUA_YOTTADB_VERSION)" "$(LUA_YOTTADB_SOURCE)" $(dir $@)
.PRECIOUS: build/lua-yottadb/_yottadb.c


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
	env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"


# ~~~ Install

install: install-$(LUA_REVISION) ;
install-lua-%: mlua.so mlua.xc _yottadb.so yottadb.lua
	@test "`whoami`" = root || ( echo "You must run 'make install' as root" && false )
	@echo $(LUA_REVISION) | grep -q "\-$(LUA_VERSION)" || ( \
		echo "Cannot install MLua (which is built against $(LUA_REVISION)) into the target Lua (which is version $(LUA_VERSION))." && \
		echo "Either change your Lua install target in the Makefile or install the version of Lua that you have built against." && \
		false )
	install -D mlua.so mlua.xc $(YDB_DIST)/plugin
	install -D _yottadb.so $(LUA_LIB_INSTALL)
	install -D yottadb.lua $(LUA_MOD_INSTALL)


.PHONY: lua lua-%  lua-yottadb  all build test vars install install-lua-%
.PHONY: clean clean-luas clean-lua-% refresh
