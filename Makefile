# Makefile to build MLua


# ~~~ Variables of interest to user

# Select which specific version of lua to download and build MLua against, eg: 5.4.4, 5.3.6, 5.2.4
# MLua works with lua >=5.2; older versions have not been tested
LUA_BUILD:=5.4.4

# Calculate just the Major.Minor and store in LUA_VERSION:
# first replace dots with spaces
tmp:=$(subst ., ,$(LUA_BUILD))
# then pick 1st number second number and put a dot between
LUA_VERSION:=$(word 1,$(tmp)).$(word 2,$(tmp))

# location to install mlua module to: .so and .lua files, respectively
LUA_LIB_INSTALL=/usr/local/lib/lua/$(LUA_VERSION)
LUA_MOD_INSTALL=/usr/local/share/lua/$(LUA_VERSION)
# Select which version tag of lua-yottadb to fetch
LUA_YOTTADB_VERSION=master
LUA_YOTTADB_SOURCE=https://github.com/anet-be/lua-yottadb.git
# Locate YDB install
ydb_dist?=$(shell pkg-config --variable=prefix yottadb --silence-errors)
ifeq ($(ydb_dist),)
  $(error Could not find $$ydb_dist; please install yottadb or set $$ydb_dist to your YDB install')
endif
YDB_INSTALL:=$(ydb_dist)/plugin



# ~~~  Internal variables

LIBLUA = build/lua-$(LUA_BUILD)/install/lib/liblua.a
YDB_INCLUDES = $(shell pkg-config --cflags yottadb)
LUA_INCLUDES = -Ibuild/lua-$(LUA_BUILD)/install/include
LUA_YOTTADB_INCLUDES = -I../lua-$(LUA_BUILD)/install/include
LUA_YOTTADB_CFLAGS = -fPIC -std=c11 -pedantic -Wall -Werror -Wno-unknown-pragmas -Wno-discarded-qualifiers $(YDB_INCLUDES) $(LUA_YOTTADB_INCLUDES)
CFLAGS = -O3 -fPIC -std=c11 -pedantic -Wall -Werror -Wno-unknown-pragmas  $(YDB_INCLUDES) $(LUA_INCLUDES)
LDFLAGS = -lm -ldl -lyottadb -L$(ydb_dist) -Wl,-rpath,$(ydb_dist),--library-path=build/lua-$(LUA_BUILD)/install/lib,-l:liblua.a
CC = gcc
# bash and GNU sort required for LUA_BUILD version comparison
# bash required for { command grouping }
SHELL=bash
$(if $(shell sort -V /dev/null 2>&1), $(error "GNU sort >= 7.0 required to get the -V option"))
# Define command to become root (sudo) only if we are not already root
BECOME_ROOT:=$(shell whoami | grep -q root || echo sudo)
# Decide command whether to use apt-get or yum to fetch readline lib
FETCH_LIBREADLINE = $(if $(shell which apt-get), $(BECOME_ROOT) apt-get install libreadline-dev, $(BECOME_ROOT) yum install readline-devel)


# Core build targets
all: fetch build
fetch: fetch-lua fetch-lua-yottadb			# Download files for build; no internet required after this
build: build-lua build-lua-yottadb build-mlua
update: update-mlua update-lua-yottadb

build-mlua: mlua.so
update-mlua:
	git pull --rebase
mlua.o: mlua.c .ARG~LUA_BUILD build-lua
	$(CC) -c $<  -o $@ $(CFLAGS) $(LDFLAGS)
mlua.so: mlua.o
	@# include entire liblua.a into mlua.so so we can call entire lua API
	$(CC) $< -o $@  -shared  -Wl,--whole-archive  $(LIBLUA)  -Wl,--no-whole-archive

%: %.c *.h mlua.so .ARG~LUA_BUILD build-lua			# Just to help build my own temporary test.c files
	$(CC) $< -o $@  $(CFLAGS) $(LDFLAGS)


# ~~~ Lua: fetch lua versions and build them

# Set LUA_BUILD_TARGET to 'linux' or if LUA_BUILD >= 5.4.0, build target is 'linux-readline'
LUA_BUILD_TARGET:=linux$(shell echo -e " 5.4.0 \n $(LUA_BUILD) " | sort -CV && echo -readline)
# Switch on -fPIC in the only way that works with Lua Makefiles 5.1 through 5.4
LUA_CC:=$(CC) -fPIC

fetch-lua: fetch-lua-$(LUA_BUILD) fetch-readline
build-lua: build-lua-$(LUA_BUILD)
fetch-lua-%: build/lua-%/Makefile ;
build-lua-%: build/lua-%/install/lib/liblua.a ;
build/lua-%/install/lib/liblua.a: build/lua-%/Makefile
	@echo Building $@
	@# tweak the standard Lua build with flags to make sure we can make a shared library (-fPIC)
	@# readline demanded only by lua <5.4 but override to included in all versions -- handy if we install this lua to the system
	$(MAKE) -C build/lua-$*  $(LUA_BUILD_TARGET)  CC="$(LUA_CC)"
	$(MAKE) -C build/lua-$*  install  INSTALL_TOP=../install
	@echo
build/lua-%/Makefile:
	@echo Fetching $(dir $@)
	wget --directory-prefix=build --no-verbose "https://www.lua.org/ftp/lua-$*.tar.gz" -O build/lua-$*.tar.gz
	mkdir -p $(dir $@)
	tar --directory=build -zxf build/lua-$*.tar.gz
	rm -f build/lua-$*.tar.gz
	@echo
.PRECIOUS: build/lua-%/Makefile

clean-luas: $(patsubst build/lua-%,clean-lua-%,$(wildcard build/lua-[0-9]*)) ;
clean-lua-%:
	[ ! -f build/lua-$*/Makefile ] || $(MAKE) -C build/lua-$* clean
	rm -rf build/lua-$*/install


# get readline (required by lua <5.4 Makefiles, though not included in the library we build; anyway, it's useful if the built lua gets installed to the system)
fetch-readline: /usr/include/readline/readline.h
/usr/include/readline/readline.h:
	@echo "Installing readline"
	$(FETCH_LIBREADLINE)
.PRECIOUS: /usr/include/readline/readline.h


# ~~~ Lua-yottadb: fetch lua-yottadb and build it

fetch-lua-yottadb: build/lua-yottadb/Makefile
build-lua-yottadb: _yottadb.so yottadb.lua
update-lua-yottadb: build/lua-yottadb/Makefile
	git -C build/lua-yottadb remote set-url origin $(LUA_YOTTADB_SOURCE)
	git -C build/lua-yottadb pull --rebase
build/lua-yottadb/_yottadb.so: build/lua-yottadb/Makefile $(wildcard build/lua-yottadb/*.[ch]) .ARG~LUA_BUILD build-lua                # Depends on lua build because CFLAGS includes lua's .h files
	@echo Building $@
	$(MAKE) -C build/lua-yottadb _yottadb.so CFLAGS="$(LUA_YOTTADB_CFLAGS)" lua=../lua-$(LUA_BUILD)/install/bin/lua --no-print-directory
_yottadb.so: build/lua-yottadb/_yottadb.so
	cp build/lua-yottadb/_yottadb.so .
yottadb.lua: build/lua-yottadb/yottadb.lua
	ln -sf build/lua-yottadb/yottadb.lua $@
.PRECIOUS: build/lua-yottadb/yottadb.lua
build/lua-yottadb/Makefile:
	@echo Fetching $(dir $@)
	git clone --branch "$(LUA_YOTTADB_VERSION)" "$(LUA_YOTTADB_SOURCE)" $(dir $@)
.PRECIOUS: build/lua-yottadb/Makefile
test-lua-yottadb: build-lua-yottadb
	$(MAKE) -C build/lua-yottadb clean test CFLAGS="$(LUA_YOTTADB_CFLAGS)" lua=../lua-$(LUA_BUILD)/install/bin/lua --no-print-directory
clean-lua-yottadb:
	rm -f _yottadb.so yottadb.lua
	$(MAKE) -C build/lua-yottadb clean


# ~~~ Make any variable name % become like a dependency so that when it $(%) changes, targets are rebuilt
# Used here to make .c files that depend on lua.h so they rebuild if $(LUA_BUILD) is changes
.PHONY: phony
.ARG~%: phony
	@if [[ `cat .ARG~$* 2>&1` != '$($*)' ]]; then echo -n $($*) >.ARG~$*; fi


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
clean: clean-lua-yottadb
	rm -f *.o *.so try tests/db.* tests/mlua.xc
	rm -rf deploy
	$(MAKE) -C benchmarks clean  --no-print-directory
# clean everything we've built
cleanall: clean clean-luas clean-lua-yottadb
# clean & wipe build directory, including external downloads -- as if we'd only just now checked out the mlua source for the first time
refresh: clean
	rm -rf build
	$(MAKE) -C benchmarks refresh  --no-print-directory


# ~~~ Test

LUA_TEST_BUILDS:=5.1.5 5.2.4 5.3.6 5.4.4

#Ensure tests use our own build of yottadb, not the system one
#Lua5.1 chokes on too many ending semicolons, so don't add them unless it's empty
LUA_PATH ?= ;;
LUA_CPATH ?= ;;
export LUA_PATH:=./?.lua;$(LUA_PATH)
export LUA_CPATH:=./?.so;$(LUA_CPATH)
export LUA_INIT:=
#used to check that MLUA_INIT works:
export MLUA_INIT:=inittest=1
export ydb_routines:=tests $(ydb_dist)/libyottadbutil.so
export ydb_xc_mlua:=tests/mlua.xc

TMPDIR ?= /tmp
tmpgld = $(TMPDIR)/mlua-test
export ydb_gbldir=$(tmpgld)/db.gld

#To run specific tests, do: make test TESTS="testBasics testReadme"
test: build tests/mlua.xc tests/db.gld
	rm $(tmpgld) -rf  &&  mkdir -p $(tmpgld)
	cp tests/db.* $(tmpgld)/
	@# pipe to cat below prevents yottadb mysteriously adding confusing linefeeds in the output
	set -o pipefail && $(ydb_dist)/yottadb -run run^unittest $(TESTS) | cat
tests/mlua.xc:
	sed -e 's|.*/mlua.so$$|mlua.so|' mlua.xc >tests/mlua.xc
tests/db.dat: tests/db.gld
tests/db.gld:
	@echo Creating Test Database
	rm -f tests/db.gld $(tmpgld)/db.dat
	ydb_gbldir=tests/db.gld   bash tests/createdb.sh $(ydb_dist) $(tmpgld)/db.dat  >/dev/null
	cp $(tmpgld)/db.dat tests/db.dat  # save it so later tests don't have to recreate it
benchmarks: benchmark
benchmark: build
	$(MAKE) -C benchmarks
benchmark-lua-only:
	$(MAKE) -C benchmarks benchmark-lua-only

#This also tests lua-yottadb with all Lua versions
testall:
	@echo
	@echo Testing mlua and lua-yottadb with all Lua versions: $(LUA_TEST_BUILDS)
	@for lua in $(LUA_TEST_BUILDS); do \
		echo ; \
		echo "*** Testing with Lua $$lua ***" ; \
		$(MAKE) clean-lua-yottadb LUA_BUILD=$$lua --no-print-directory || exit 1; \
		$(MAKE) test-lua-yottadb LUA_BUILD=$$lua --no-print-directory || exit 1; \
		$(MAKE) LUA_BUILD=$$lua all test || { rm -f _yottadb.so yottadb.lua; exit 1; }; \
	done
	$(MAKE) clean-lua-yottadb --no-print-directory  # ensure not built with any Lua version lest it confuse future builds with default Lua
	@echo Successfully tested with Lua versions $(LUA_TEST_BUILDS)


# ~~~ Install

YDB_DEPLOYMENTS=mlua.so mlua.xc
LUA_LIB_DEPLOYMENTS=_yottadb.so
LUA_MOD_DEPLOYMENTS=yottadb.lua
install: build
	@echo "Installing files to '$(YDB_INSTALL)', '$(LUA_LIB_INSTALL)', and '$(LUA_MOD_INSTALL)'"
	@echo "If you prefer to install to a local (non-system) deployment folder, run 'make install-local'"
	$(BECOME_ROOT) install -m644 -D $(YDB_DEPLOYMENTS) -t $(YDB_INSTALL)
	$(BECOME_ROOT) install -m644 -D $(LUA_LIB_DEPLOYMENTS) -t $(LUA_LIB_INSTALL)
	$(BECOME_ROOT) install -m644 -D $(LUA_MOD_DEPLOYMENTS) -t $(LUA_MOD_INSTALL)
install-local: build
	mkdir -p deploy/ydb deploy/lua-lib deploy/lua-mod
	install -m644 -D $(YDB_DEPLOYMENTS) -t deploy/ydb
	install -m644 -D $(LUA_LIB_DEPLOYMENTS) -t deploy/lua-lib
	install -m644 -D $(LUA_MOD_DEPLOYMENTS) -t deploy/lua-mod
install-lua: build-lua
	@echo Installing Lua $(LUA_BUILD) to your system
	$(BECOME_ROOT) $(MAKE) -C build/lua-$(LUA_BUILD)  install
	$(BECOME_ROOT) mv /usr/local/bin/lua /usr/local/bin/lua$(LUA_VERSION)
	$(BECOME_ROOT) mv /usr/local/bin/luac /usr/local/bin/luac$(LUA_VERSION)
	@echo
	@echo "*** Note ***: Lua is now installed as /usr/local/bin/lua$(LUA_VERSION)."
	@echo "If you want it as your main Lua, symlink it like this (assuming ~/bin is in your path):"
	@echo "  $(BECOME_ROOT) ln -s /usr/local/bin/lua$(LUA_VERSION) ~/bin/lua"
	@echo

$(shell mkdir -p build)			# So I don't need to do it in every target

#Prevent deletion of targets
.SECONDARY:
#Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
.DELETE_ON_ERROR:

#Note: do not list build-lua and fetch-lua as .PHONY: this allows them to be used as prerequisites of real targets
# (build-lua, at least, needs to be a prerequisite of anything that uses lua header files)
.PHONY: fetch fetch-lua-yottadb update-lua-yottadb update-mlua fetch-lua-%
.PHONY: build build-lua-yottadb build-lua-% build-mlua
.PHONY: benchmarks benchmark-lua-only
.PHONY: install install-lua
.PHONY: all test vars
.PHONY: clean clean-luas clean-lua-% clean-lua-yottadb refresh
