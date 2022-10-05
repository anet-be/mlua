# Makefile to build and run MLua benchmarks


# ~~~ Variables of interest to user

LUA := lua
YDB_DIST := $(shell pkg-config --variable=prefix yottadb)
YDB_INSTALL := $(YDB_DIST)/plugin
CC := gcc

# first target is the default
test: lua-tools
	$(MAKE) cmumps build-brocr --no-print-directory || $(MAKE) bad-deps -s
	./benchmark.py
# alternative target for users who do not permission to access cmumps or qtechng -- though it won't have anything to compare against
test-lua-only: lua-tools
	./benchmark.py
fetch:
	$(MAKE) fetch-lua-tools fetch-brocr fetch-cmumps  --no-print-directory || $(MAKE) bad-deps -s


# nicely handle cmumps or qtechng dependencies not available
bad-deps:
	@ ! [ -f build/cmumps/cstrlib.c -a -f brocr.go ] \
	&& echo \
	&& echo "This may have failed because you do not have ssh access to" \
	&& echo "(proprietary) cmumps and qtechng (from https://www.uantwerpen.be/nl/projecten/anet/brocade/)." \
	&& echo "If that is the case, you can produce just the MLua benchmarks using 'make test-lua-only'," \
	&& echo "though you obviously won't be able to compare against those proprietary C and Go benchmarks" \
	&& echo \
	&& echo "Try: make test-lua-only" \
	&& echo \
	&& false

# ~~~ pure_lua_SHA: fetch
fetch-lua-tools: build/pure_lua_SHA/sha2.lua build/lua-cputime/src/lua-cputime.c lua.h
lua-tools: lua-sha lua-cputime
lua-sha: sha2.lua
sha2.lua: build/pure_lua_SHA/sha2.lua
	cp build/pure_lua_SHA/sha2.lua .
build/pure_lua_SHA/sha2.lua:
	@echo "Fetching lua-sha from github"
	cd build && git clone https://github.com/Egor-Skriptunoff/pure_lua_SHA.git


# ~~~ lua-cputime: fetch & build
lua-cputime: cputime.so
	@: #noop prevents make's "nothing to do for target" warning
cputime.so: build/lua-cputime/src/lua-cputime.c lua.h
	cd build/lua-cputime &&  $(CC) -O2 -fPIC -I/usr/local/include -c src/lua-cputime.c -o src/lua-cputime.o
	cd build/lua-cputime &&  $(CC) -shared -o cputime.so src/lua-cputime.o
	cp build/lua-cputime/cputime.so .
build/lua-cputime/src/lua-cputime.c:
	@echo "Fetching lua-cputime measuring tool from github"
	cd build && git clone --branch v0.1.0-0 https://github.com/moznion/lua-cputime.git -c advice.detachedHead=false
lua.h:
	@ # Check that lua.h is in the compiler path and warn the user appropriately if not
	@ echo '#include "lua.h"' | $(CC) -E - >/dev/null \
	|| ( echo \
	&& echo "Error: lua.h is not in the $(CC) path. Have you run 'make install-lua' from $(dir $(shell pwd))?" \
	&& echo \
	&& false )


# ~~~ brocr: fetch and build it if it is accessible
fetch-brocr: brocr.go
build-brocr: brocr
	@: #noop prevents make's "nothing to do for target" warning
brocr: brocr.go
	go build -o brocr brocr.go
brocr.go:
	@echo "Fetching brocr.go with Brocade's qtechng tool"
	output=$$(qtechng source co /universe/os/brocr.go 2>&1); \
	  echo "$$output" | grep '"file":.*brocr.go' \
	  || (echo "$$output"; false)


# ~~~ cmumps: fetch and build it if it is accessible
CFLAGS = -std=c99 -pedantic -Wall -Wno-unknown-pragmas
GTM_INCLUDES=-I$(YDB_DIST) -L$(YDB_DIST) -lyottadb -Wl,-rpath,$(YDB_DIST)
UTF8PROC=utf8proc/utf8proc.c
MBEDTLS=mbedtls/sha1.c mbedtls/sha512.c mbedtls/aes.c mbedtls/base64.c

fetch-cmumps: build/cmumps/cstrlib.c
cmumps: cstrlib.so cstrlib.xc
	@: #noop
cstrlib.so cstrlib.xc: build/cmumps/cstrlib.c
	$(MAKE) -C build/cmumps
	cp build/cmumps/cstrlib.so .
	cp build/cmumps/cstrlib.xc .
	sed -i "1 s|.*/cstrlib.so|cstrlib.so|" cstrlib.xc
build/cmumps/cstrlib.c:
	@echo "Fetching cmumps from its Brocade git repository"
	cd build && git clone git@bitbucket.org:anetbrocade/cmumps.git


# Debug: print out all variables defined in this makefile
# Warning: these don't work if a variable contains single quotes
vars:
	@echo -e $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), '\n$(v)=$(value $(v))') )


$(shell mkdir -p build)		# So I don't need to do it in every target

clean:
	rm -f *.time *.so cstrlib.xc brocr
	[ ! -f build/cmumps/Makefile ] || $(MAKE) -C build/cmumps clean --no-print-directory
refresh: clean
	rm -f brocr.go
	rm -rf build

.PHONY: fetch fetch-lua-tools fetch-brocr fetch-cmumps
.PHONY: test test-lua-only lua-sha cmumps bad-deps build-brocr lua-tools lua.h
.PHONY: clean clean-cmumps
.SECONDARY: # Prevent deletion of targets
.DELETE_ON_ERROR: # Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
