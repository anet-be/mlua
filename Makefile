# Makefile to build MLua

CC=gcc

YDB_DIST := $(shell pkg-config --variable=prefix yottadb)

YDB_FLAGS := $(shell pkg-config --cflags yottadb)
LUA_FLAGS := externals/lua
CFLAGS := -std=c99 -pedantic -Wall -Wno-unknown-pragmas -Iexternals/ $(YDB_FLAGS) $(LUA_FLAGS)

# Define which Lua versions to build against
LUAS := lua-5.4.4 lua-5.3.6 lua-5.2.4

# Decide whether to use apt-get or yum to get readline lib
FETCH_LIBREADLINE := $(if $(shell which apt-get), sudo apt-get install libreadline-dev, sudo yum install readline-devel)

all: try

build: mlua.so

%: %.c
	$(CC) $< -o $@  $(CFLAGS)

mlua.o: mlua.c
	$(CC) $<  -c -fPIC $(CFLAGS)

mlua.so: mlua.o
	$(CC) $< -o $@  -shared

# Fetch lua builds if we haven't yet
lua: $(LUAS)
lua-5%: externals/lua-5%/src/lua ;

# extra dependency for older versions of lua
lua-5.3.%: /usr/include/readline/readline.h externals/lua-5.3.%/src/lua ;
lua-5.2.%: /usr/include/readline/readline.h externals/lua-5.2.%/src/lua ;

externals/lua-%/src/lua: externals/lua-%/Makefile ;
	@echo Building $@
	make --directory=externals/lua-$* linux test
	@echo
.PRECIOUS: externals/lua-%/src/lua

externals/lua-%/Makefile:
	@echo Fetching $@
	mkdir -p $@
	wget --directory-prefix=externals --no-verbose "http://www.lua.org/ftp/lua-$*.tar.gz" -O $@.tar.gz
	tar --directory=externals -zxf $@.tar.gz
	rm -f $@.tar.gz
	@echo
.PRECIOUS: externals/lua-%/Makefile

/usr/include/readline/readline.h:
	@echo "Installing readline development library required by builds of lua <5.4"
	$(FETCH_LIBREADLINE)
.PRECIOUS: /usr/include/readline/readline.h

# clean just our build
clean:
	rm -f *.o *.so try
	rm -rf tests

# clean externals (e.g. lua), too
clean-all: clean
	rm -rf externals

test:
	mkdir -p tests
	python3 test.py
	env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"

install: mlua.so mlua.xc
	sudo cp mlua.so mlua.xc $(YDB_DIST)/plugin

.PHONY: install test clean clean-all lua build
