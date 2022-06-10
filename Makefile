# Makefile to build MLua

CC = gcc

YDB_DIST = $(shell pkg-config --variable=prefix yottadb)

YDB_FLAGS = $(shell pkg-config --cflags yottadb)
LUA_FLAGS = -Ibuild/lua-5.4.4/install/include -Wl,--library-path=build/lua-5.4.4/install/lib -l:liblua.a
LIBS = -lm -ldl
CFLAGS = -fPIC -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS) $(LIBS)

# Define which Lua versions to download and build against
# Works with lua >=5.2; older versions' makefiles differ enough that we'd have to change our invokation.
LUAS = lua-5.4.4 lua-5.3.6 lua-5.2.4

# Decide whether to use apt-get or yum to get readline lib
FETCH_LIBREADLINE = $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)

all: try

build: mlua.so

%: %.c lua
	$(CC) $< -o $@  $(CFLAGS)

mlua.o: mlua.c
	$(CC) $<  -c -fPIC $(CFLAGS)

mlua.so: mlua.o
	$(CC) $< -o $@  -shared

# Fetch lua versions and build them
luas: $(LUAS)
lua-%: /usr/include/readline/readline.h  build/lua-%/install/lib/liblua.so  ;

build/lua-%/install/lib/liblua.so: build/lua-%/Makefile
	@echo Building $@
	# tweak the standard Lua build with flags to make sure we can make a shared library (-fPIC)
	# ensure readline is included for all versions (anticipating an 'mlua' tool which will be interactive lua connected to ydb)
	$(MAKE) --directory=build/lua-$*  linux  test local  MYCFLAGS="-fPIC"  MYLIBS="-Wl,-lreadline"  SYSCFLAGS="-DLUA_USE_LINUX -DLUA_USE_READLINE"
	cd build/lua-$*/install/lib  &&  $(CC) -shared -o liblua.so  -Wl,--whole-archive  liblua.a  -Wl,--no-whole-archive
	@echo
.PRECIOUS: build/lua-%/install/lib/liblua.so

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

install: mlua.so mlua.xc
	sudo cp mlua.so mlua.xc $(YDB_DIST)/plugin

.PHONY: luas build test install  clean clean-luas clean-luas-% refresh
