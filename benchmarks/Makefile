# Makefile to build and run MLua benchmarks


# ~~~ Variables of interest to user

LUA := lua
YDB_DIST := $(shell pkg-config --variable=prefix yottadb)
YDB_INSTALL := $(YDB_DIST)/plugin


# first target is the default
test: lua_sha
	$(MAKE) cmumps go_brocr --no-print-directory || $(MAKE) bad_deps -s
	./benchmark.py

# alternative target for users who do not permission to access cmumps or qtechng -- though it won't have anything to compare against
test_lua_only: lua_sha
	./benchmark.py


# nicely handle cmumps or qtechng dependencies not available
bad_deps:
	@ ! [ -f build/cmumps/cstrlib.c -a -f brocr.go ] \
	&& echo \
	&& echo "This may have failed because you do not have access to (proprietary) cmumps or qtechng" \
	&& echo "(from https://www.uantwerpen.be/nl/projecten/anet/brocade/)." \
	&& echo "If that is the case, you can produce just the MLua benchmarks using 'make test_lua_only'," \
	&& echo "though you obviously won't be able to compare against those proprietary C and Go benchmarks" \
	&& echo \
	&& false

# ~~~ pure_lua_SHA: fetch

lua_sha: sha2.lua

build/pure_lua_SHA/sha2.lua:
	mkdir -p build
	cd build && git clone https://github.com/Egor-Skriptunoff/pure_lua_SHA.git
.PRECIOUS:	build/

sha2.lua: build/pure_lua_SHA/sha2.lua
	cp build/pure_lua_SHA/sha2.lua .

# ~~~ brocr: fetch and build it if it is accessible

go_brocr: brocr
	@: #noop
brocr: brocr.go
	go build -o brocr brocr.go
brocr.go:
	@echo "Fetching brocr.go with Brocade's qtechng tool"
	output=$$(qtechng source co /universe/os/brocr.go 2>&1); \
	  echo "$$output" | grep '"file":.*brocr.go' \
	  || (echo "$$output"; false)
.PRECIOUS: brocr.go

# ~~~ cmumps: fetch and build it if it is accessible

CC = gcc
CFLAGS = -std=c99 -pedantic -Wall -Wno-unknown-pragmas
GTM_INCLUDES=-I$(YDB_DIST) -L$(YDB_DIST) -lyottadb -Wl,-rpath,$(YDB_DIST)
UTF8PROC=utf8proc/utf8proc.c
MBEDTLS=mbedtls/sha1.c mbedtls/sha512.c mbedtls/aes.c mbedtls/base64.c

cmumps: cstrlib.so cstrlib.xc
	@: #noop
cstrlib.so cstrlib.xc: build/cmumps/cstrlib.c
	$(MAKE) -C build/cmumps
	cp build/cmumps/cstrlib.so .
	cp build/cmumps/cstrlib.xc .
	sed -i "1 s|.*/cstrlib.so|cstrlib.so|" cstrlib.xc
build/cmumps/cstrlib.c:
	mkdir -p build
	@echo "Fetching cmumps from its Brocade git repository"
	cd build && git clone git@bitbucket.org:anetbrocade/cmumps.git
.PRECIOUS: build/cmumps/cstrlib.c


# Debug: print out all variables defined in this makefile
# Warning: these don't work if a variable contains single quotes
vars:
	@echo -e $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), '\n$(v)=$(value $(v))') )


clean:
	rm -f *.time
	rm -f cstrlib.so cstrlib.xc
	rm -f brocr brocr.go
	$(MAKE) -C build/cmumps clean --no-print-directory
refresh: clean
	rm -rf build

.PHONY: test test_lua_only lua_sha cmumps bad_deps go_brocr
.PHONY: clean clean-cmumps
.SECONDARY: # Prevent deletion of targets -- and prevent rebuilding when phony target LUA_BUILD_VERSION is a dependency
.DELETE_ON_ERROR: # Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
