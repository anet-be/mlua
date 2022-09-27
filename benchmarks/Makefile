# Makefile to build and run MLua benchmarks


# ~~~ Variables of interest to user

LUA := lua
YDB_DIST := $(shell pkg-config --variable=prefix yottadb)
YDB_INSTALL := $(YDB_DIST)/plugin
CC := gcc

# first target is the default
test: lua_tools
	$(MAKE) cmumps go_brocr --no-print-directory || $(MAKE) bad_deps -s
	./benchmark.py

# alternative target for users who do not permission to access cmumps or qtechng -- though it won't have anything to compare against
test_lua_only: lua_tools
	./benchmark.py


# nicely handle cmumps or qtechng dependencies not available
bad_deps:
	@ ! [ -f build/cmumps/cstrlib.c -a -f brocr.go ] \
	&& echo \
	&& echo "This may have failed because you have not set up ssh to have access to" \
	&& echo "(proprietary) cmumps and qtechng (from https://www.uantwerpen.be/nl/projecten/anet/brocade/)." \
	&& echo "If that is the case, you can produce just the MLua benchmarks using 'make test_lua_only'," \
	&& echo "though you obviously won't be able to compare against those proprietary C and Go benchmarks" \
	&& echo \
	&& false

# ~~~ pure_lua_SHA: fetch
lua_tools: lua_sha lua_cputime
lua_sha: sha2.lua
sha2.lua: build/pure_lua_SHA/sha2.lua
	cp build/pure_lua_SHA/sha2.lua .
build/pure_lua_SHA/sha2.lua:
	@echo "Fetching lua-sha from github"
	cd build && git clone https://github.com/Egor-Skriptunoff/pure_lua_SHA.git


# ~~~ lua_cputime: fetch & build
lua_cputime: cputime.so
	@: #noop
cputime.so: build/lua-cputime/src/lua-cputime.c
	cd build/lua-cputime &&  $(CC) -O2 -fPIC -I/usr/local/include -c src/lua-cputime.c -o src/lua-cputime.o
	cd build/lua-cputime &&  $(CC) -shared -o cputime.so src/lua-cputime.o
	cp build/lua-cputime/cputime.so .
build/lua-cputime/src/lua-cputime.c:
	@echo "Fetching lua-cputime measuring tool from github"
	cd build && git clone --branch v0.1.0-0 https://github.com/moznion/lua-cputime.git


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


# ~~~ cmumps: fetch and build it if it is accessible
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
	@echo "Fetching cmumps from its Brocade git repository"
	cd build && git clone git@bitbucket.org:anetbrocade/cmumps.git


# Debug: print out all variables defined in this makefile
# Warning: these don't work if a variable contains single quotes
vars:
	@echo -e $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), '\n$(v)=$(value $(v))') )


$(shell mkdir -p build)		# So I don't need to do it in every target

clean:
	rm -f *.time *.so cstrlib.xc brocr
	$(MAKE) -C build/cmumps clean --no-print-directory
refresh: clean
	rm -f brocr.go
	rm -rf build

.PHONY: test test_lua_only lua_sha cmumps bad_deps go_brocr lua_tools
.PHONY: clean clean-cmumps
.SECONDARY: # Prevent deletion of targets
.DELETE_ON_ERROR: # Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
