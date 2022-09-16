# Makefile to build and run MLua benchmarks


# ~~~ Variables of interest to user

LUA := lua
YDB_DIST := $(shell pkg-config --variable=prefix yottadb)
YDB_INSTALL := $(YDB_DIST)/plugin


# first target is the default
test: cmumps test_without_cmumps

# alternative target for users who do not have cmumps available
test_without_cmumps: lua_sha
	./benchmark.py


# ~~~ pure_lua_SHA: fetch

lua_sha: sha2.lua

build/pure_lua_SHA/sha2.lua:
	mkdir -p build
	cd build && git clone https://github.com/Egor-Skriptunoff/pure_lua_SHA.git
.PRECIOUS:	build/

sha2.lua: build/pure_lua_SHA/sha2.lua
	cp build/pure_lua_SHA/sha2.lua .


# ~~~ cmumps: fetch and build it if it is accessible

CC = gcc
CFLAGS = -std=c99 -pedantic -Wall -Wno-unknown-pragmas
GTM_INCLUDES=-I$(YDB_DIST) -L$(YDB_DIST) -lyottadb -Wl,-rpath,$(YDB_DIST)
UTF8PROC=utf8proc/utf8proc.c
MBEDTLS=mbedtls/sha1.c mbedtls/sha512.c mbedtls/aes.c mbedtls/base64.c

cmumps: cstrlib.so cstrlib.xc

build/cmumps/cstrlib.c:
	mkdir -p build
	cd build && git clone git@bitbucket.org:anetbrocade/cmumps.git
.PRECIOUS: build/cmumps/cstrlib.c

cstrlib.so cstrlib.xc: build/cmumps/cstrlib.c
	$(MAKE) -C build/cmumps
	cp build/cmumps/cstrlib.so .
	cp build/cmumps/cstrlib.xc .
	sed -i "1 s|.*/cstrlib.so|cstrlib.so|" cstrlib.xc


# Debug: print out all variables defined in this makefile
# Warning: these don't work if a variable contains single quotes
vars:
	@echo -e $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), '\n$(v)=$(value $(v))') )


clean:
	rm *.time
	rm cstrlib.so cstrlib.xc
	$(MAKE) -C build/cmumps clean


.PHONY: test test_without_cmumps lua_sha cmumps
.PHONY: clean clean-cmumps
.SECONDARY: # Prevent deletion of targets -- and prevent rebuilding when phony target LUA_BUILD_VERSION is a dependency
.DELETE_ON_ERROR: # Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
