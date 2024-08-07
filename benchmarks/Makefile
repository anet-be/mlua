# Makefile to build and run MLua benchmarks

# ~~~ Variables of interest to user

LUA := lua
ydb_dist ?= $(shell pkg-config --variable=prefix yottadb)
YDB_INSTALL := $(ydb_dist)/plugin
CC := gcc

#Set make HIDE_PROCESS_TIME=1 to benchmark with a cleaner output that only shows real time
HIDE_PROCESS_TIME= ?=

#Ensure tests use our own build of yottadb, not the system one
#Lua5.1 chokes on too many ending semicolons, so don't add them unless it's empty
LUA_PATH ?= ;;
LUA_CPATH ?= ;;
export LUA_PATH:=../?.lua;./?.lua;$(LUA_PATH)
export LUA_CPATH:=../?.so;./?.so;$(LUA_CPATH)
export LUA_INIT:=
export MLUA_INIT:=
export ydb_xc_cstrlib:=./cstrlib.xc
utf8:=$(if $(findstring -8,$(if $(ydb_chset),$(ydb_chset),$(gtm_chset))),/utf8)
export ydb_routines:=. $(ydb_dist)$(utf8)/libyottadbutil.so
export ydb_xc_mlua:=mlua.xc

#Location of temporary database for benchmarking
TMPDIR ?= /tmp
tmpgld = $(TMPDIR)/mlua-benchmark
export ydb_gbldir=$(tmpgld).gld

all: fetch benchmark
benchmarks benchmark: mlua.xc lua-tools
	rm -f $(tmpgld).gld $(tmpgld).dat
	bash ../tests/createdb.sh $(ydb_dist) $(tmpgld).dat >/dev/null 2>&1
	@# pipe to cat below prevents yottadb weirdly adding linefeeds into some lua stdout messages
	yottadb -run benchmark $(TESTS) | cat
# alternative target for users who have access to ANET tools cmumps and qtechng
anet-benchmarks anet: build-benchmark-extras
	$(MAKE) benchmarks
build-benchmark-extras: fetch-extras
	$(MAKE) cmumps build-brocr --no-print-directory || $(MAKE) bad-deps -s
fetch:
	$(MAKE) fetch-lua-tools  --no-print-directory
fetch-extras: fetch
	$(MAKE) fetch-brocr fetch-cmumps  --no-print-directory || $(MAKE) bad-deps -s
mlua.xc: ../mlua.xc
	sed "1 s|.*/mlua.so|../mlua.so|" ../mlua.xc >mlua.xc


# nicely handle cmumps or qtechng dependencies not available
bad-deps:
	@ ! [ -f build/cmumps/cstrlib.c -a -f brocr.go ] \
	&& echo \
	&& echo "This may have failed because you do not have ssh access to" \
	&& echo "(proprietary) cmumps and qtechng (from https://www.uantwerpen.be/nl/projecten/anet/brocade/)." \
	&& echo "If that is the case, you can produce just the standard MLua benchmarks using 'make benchmarks'," \
	&& echo "though you obviously won't be able to compare against those proprietary C and Go benchmarks" \
	&& echo \
	&& echo "Try: make benchmarks" \
	&& echo \
	&& false

# ~~~ pure_lua_SHA: fetch
fetch-lua-tools: build/pure_lua_SHA/sha2.lua
lua-tools: lua-sha
lua-sha: sha2.lua
sha2.lua: build/pure_lua_SHA/sha2.lua
	cp build/pure_lua_SHA/sha2.lua .
build/pure_lua_SHA/sha2.lua:
	@echo "Fetching lua-sha from github"
	cd build && git clone https://github.com/Egor-Skriptunoff/pure_lua_SHA.git


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
GTM_INCLUDES=-I$(ydb_dist) -L$(ydb_dist) -lyottadb -Wl,-rpath,$(ydb_dist)
UTF8PROC=utf8proc/utf8proc.c
MBEDTLS=mbedtls/sha1.c mbedtls/sha512.c mbedtls/aes.c mbedtls/base64.c

fetch-cmumps: build/cmumps/cstrlib.c
cmumps: cstrlib.so cstrlib.xc
	@: #noop
cstrlib.so cstrlib.xc: build/cmumps/cstrlib.c
	$(MAKE) -C build/cmumps
	cp build/cmumps/cstrlib.so .
	cp build/cmumps/cstrlib.xc .
	sed -i "1 s|.*/cstrlib.so|./cstrlib.so|" cstrlib.xc
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

.PHONY: fetch fetch-extras fetch-lua-tools fetch-brocr fetch-cmumps
.PHONY: all build-benchmark benchmarks benchmark anet-benchmarks anet benchmark.m benchmark.py
.PHONY: lua-sha cmumps bad-deps build-brocr lua-tools
.PHONY: clean clean-cmumps
.SECONDARY: # Prevent deletion of targets
.DELETE_ON_ERROR: # Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
