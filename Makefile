# Makefile to build MLua

# === Variable of interest to user

# Define which Lua versions to download and build against
# Works with lua >=5.2; older versions' makefiles differ enough that we'd have to change our invokation
LUAS = lua-5.4.4 lua-5.3.6 lua-5.2.4

#Select which lualib.so to install (all are built)
WORKING_LUA = lua-5.4.4
LIBLUA = build/$(WORKING_LUA)/install/lib/liblua.a

INSTALL_DIR = $(YDB_DIST)/plugin

# Decide command whether to use apt-get or yum to fetch readline lib
FETCH_LIBREADLINE = $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)


# === Internal variables

CC = gcc

YDB_DIST = $(shell pkg-config --variable=prefix yottadb)
YDB_FLAGS = $(shell pkg-config --cflags yottadb)
LUA_FLAGS = -Ibuild/$(WORKING_LUA)/install/include -Wl,--library-path=build/$(WORKING_LUA)/install/lib -Wl,-l:liblua.a
LIBS = -lm -ldl
CFLAGS = -fPIC -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS) $(LIBS)

all: luas build

build: mlua.so

%: %.c mlua.so $(LIBLUA)
	$(CC) $< -o $@  $(CFLAGS)

mlua.o: mlua.c $(WORKING_LUA)
	$(CC) -c $<  -o $@ $(CFLAGS)

mlua.so: mlua.o $(LIBLUA)
	@# include entire liblua.a into mlua.so so we can call entire lua API
	$(CC) $< -o $@  -shared  -Wl,--whole-archive  $(LIBLUA)  -Wl,--no-whole-archive


# Fetch lua versions and build them
luas: $(LUAS)
lua-%: build/lua-%/install/lib/liblua.a ;

build/lua-%/install/lib/liblua.a: /usr/include/readline/readline.h  build/lua-%/Makefile
	@echo Building $@
	@# tweak the standard Lua build with flags to make sure we can make a shared library (-fPIC)
	@# readline demanded only by lua <5.4 but override to included in all versions -- anticipating an interactive 'mlua' tool
	$(MAKE) --directory=build/lua-$*  linux  test local  MYCFLAGS="-fPIC"  MYLIBS="-Wl,-lreadline"  SYSCFLAGS="-DLUA_USE_LINUX -DLUA_USE_READLINE"
	@echo
.PRECIOUS: build/lua-%/install/lib/liblua.a

build/lua-%/Makefile:
	@echo Fetching $@
	mkdir -p $@
	wget --directory-prefix=build --no-verbose "http://www.lua.org/ftp/lua-$*.tar.gz" -O $@.tar.gz
	tar --directory=build -zxf $@.tar.gz
	rm -f $@.tar.gz
	@echo
.PRECIOUS: build/lua-%/Makefile

/usr/include/readline/readline.h:
	@echo "Installing readline"
	$(FETCH_LIBREADLINE)
.PRECIOUS: /usr/include/readline/readline.h

# clean just our build
clean:
	rm -f *.o *.so try
	rm -rf tests

clean-luas: $(patsubst lua-%,clean-lua-%,$(LUAS)) ;
clean-lua-%: build/lua-%/README
	$(MAKE) --directory=build/lua-$* clean
	rm -rf build/lua-$*/install
.PRECIOUS: build/lua-%/README

# clean whole build directory including external downloads as if we'd initially checked out the source
refresh: clean
	rm -rf build

test:
	mkdir -p tests
	python3 test.py
	env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"

install: install-$(WORKING_LUA) ;
install-lua-%: mlua.so mlua.xc
	sudo cp $^ $(INSTALL_DIR)

.PHONY: luas lua-%  all build test install install-lua-%
.PHONY: clean clean-luas clean-luas-% refresh
