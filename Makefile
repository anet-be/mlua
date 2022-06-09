# Makefile to build MLua

CC=gcc

YDB_DIST := $(shell pkg-config --variable=prefix yottadb)

YDB_FLAGS := $(shell pkg-config --cflags yottadb)
LUA_FLAGS := -Ibuild/lua-5.4.4/install/include -Wl,--library-path=build/lua-5.4.4/install/lib -Wl,-l:liblua.a
CFLAGS := -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS)

# Define which Lua versions to download and build against
LUAS := lua-5.4.4 #lua-5.3.6 lua-5.2.4

# Decide whether to use apt-get or yum to get readline lib
FETCH_LIBREADLINE := $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)

all: try

build: mlua.so

%: %.c lua
	$(CC) $< -o $@  $(CFLAGS)

mlua.o: mlua.c
	$(CC) $<  -c -fPIC $(CFLAGS)

mlua.so: mlua.o
	$(CC) $< -o $@  -shared

# Fetch lua builds if we haven't yet
lua: $(LUAS)
lua-5%: build/lua-5%/src/lua ;

# extra dependency for older versions of lua
lua-5.3.%: /usr/include/readline/readline.h build/lua-5.3.%/src/lua ;
lua-5.2.%: /usr/include/readline/readline.h build/lua-5.2.%/src/lua ;

build/lua-%/src/lua: build/lua-%/Makefile ;
	@echo Building $@
	make --directory=build/lua-$* linux test local
	@echo
.PRECIOUS: build/lua-%/src/lua

build/lua-%/Makefile:
	@echo Fetching $@
	mkdir -p $@
	wget --directory-prefix=build --no-verbose "http://www.lua.org/ftp/lua-$*.tar.gz" -O $@.tar.gz
	tar --directory=build -zxf $@.tar.gz
	rm -f $@.tar.gz
	@echo
.PRECIOUS: build/lua-%/Makefile

/usr/include/readline/readline.h:
	@echo "Installing readline development library required by builds of lua <5.4"
	$(FETCH_LIBREADLINE)
.PRECIOUS: /usr/include/readline/readline.h

# clean just our build
clean:
	rm -f *.o *.so try
	rm -rf tests

# clean build (e.g. lua), too
clean-all: clean
	rm -rf build

test:
	mkdir -p tests
	python3 test.py
	env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"

install: mlua.so mlua.xc
	sudo cp mlua.so mlua.xc $(YDB_DIST)/plugin

.PHONY: install test clean clean-all lua build
