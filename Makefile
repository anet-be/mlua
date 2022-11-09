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
LUA_YOTTADB_SOURCE=https://github.com/berwynhoyt/lua-yottadb.git
# Locate YDB install
YDB_DIST:=$(ydb_dist)
ifeq ($(YDB_DIST),)
 YDB_DIST:=$(shell pkg-config --variable=prefix yottadb)
 ifeq ($(YDB_DIST),)
   $(error please install yottadb or supply the path to your yottadb install with 'make YDB_INSTALL=/path/to/ydb')
 endif
endif
YDB_INSTALL:=$(YDB_DIST)/plugin



# ~~~  Internal variables

LIBLUA = build/lua-$(LUA_BUILD)/install/lib/liblua.a
YDB_FLAGS = $(shell pkg-config --cflags yottadb)
LUA_FLAGS = -Ibuild/lua-$(LUA_BUILD)/install/include -Wl,--library-path=build/lua-$(LUA_BUILD)/install/lib -Wl,-l:liblua.a
LDFLAGS = -lm -ldl -lyottadb -L$(YDB_DIST)
CFLAGS = -fPIC -std=c99 -pedantic -Wall -Wno-unknown-pragmas  $(YDB_FLAGS) $(LUA_FLAGS)
CC = gcc
# bash and GNU sort required for LUA_BUILD version comparison
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

build-mlua: mlua.so
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

fetch-lua-yottadb: build/lua-yottadb/_yottadb.c
build-lua-yottadb: _yottadb.so yottadb.lua
_yottadb.so: build/lua-yottadb/_yottadb.c .ARG~LUA_BUILD build-lua		# Depends on lua build because CFLAGS includes lua's .h files
	@echo Building $@
	$(CC) build/lua-yottadb/_yottadb.c  -o $@  -shared  $(CFLAGS) $(LDFLAGS)  -Wno-return-type -Wno-unused-but-set-variable -Wno-discarded-qualifiers
yottadb.lua: build/lua-yottadb/yottadb.lua
	cp build/lua-yottadb/yottadb.lua $@
.PRECIOUS: build/lua-yottadb/yottadb.lua
build/lua-yottadb/_yottadb.c:
	@echo Fetching $(dir $@)
	git clone --branch "$(LUA_YOTTADB_VERSION)" "$(LUA_YOTTADB_SOURCE)" $(dir $@)
.PRECIOUS: build/lua-yottadb/_yottadb.c

clean-lua-yottadb:
	rm -f _yottadb.so yottadb.lua


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
clean:
	rm -f *.o *.so try
	rm -rf tests
	rm -rf deploy
	$(MAKE) -C benchmarks clean  --no-print-directory
# clean everything we've built
cleanall: clean clean-luas clean-lua-yottadb
# clean & wipe build directory, including external downloads -- as if we'd only just now checked out the mlua source for the first time
refresh: clean
	rm -rf build
	$(MAKE) -C benchmarks refresh  --no-print-directory


# ~~~ Test

test:
	mkdir -p tests
	python3 test.py
	#env ydb_routines="./tests $(ydb_routines)" ydb -run "^tests"

benchmarks:
	$(MAKE) -C benchmarks
test-lua-only:
	$(MAKE) -C benchmarks test-lua-only


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
.PHONY: fetch fetch-lua-yottadb fetch-lua-%
.PHONY: build build-lua-yottadb build-lua-% build-mlua
.PHONY: benchmarks test-lua-only
.PHONY: install install-lua
.PHONY: all test vars
.PHONY: clean clean-luas clean-lua-% clean-lua-yottadb refresh
