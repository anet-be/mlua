# Makefile to build MLua


# ~~~ Variables of interest to user

# Set this to create shared libluaX.Y.so instead of embedded in mlua.so
# Blank means 'no'. User can set to 'yes' to create liblua or use the system's preexisting shared libluaX.Y.so by setting to its full path
# A shared library version may be needed, for example, to build apache's mod_lua so that it uses the same libluaX.Y.so
SHARED_LUA:=

# Select which specific version of lua to download and build MLua against, eg: 5.4.4, 5.3.6, 5.2.4
# MLua works with lua >=5.2; older versions have not been tested
LUA_BUILD:=5.4.4

# Calculate just the Major.Minor and store in LUA_VERSION:
# first replace dots with spaces
tmp:=$(subst ., ,$(LUA_BUILD))
# then pick 1st number second number and put a dot between
LUA_VERSION:=$(word 1,$(tmp)).$(word 2,$(tmp))

# Select which version tag of lua-yottadb to fetch
LUA_YOTTADB_VERSION=master
LUA_YOTTADB_SOURCE=https://github.com/anet-be/lua-yottadb.git

# location to install mlua module to: .so and .lua files, respectively
# to change installation directory, do: 'make PREFIX=<dir> YDB_INSTALL=<ydb_dir>'
PREFIX=$(SYSTEM_PREFIX)
SYSTEM_PREFIX=/usr/local
LUA_LIB_INSTALL=$(PREFIX)/lib/lua/$(LUA_VERSION)
LUA_MOD_INSTALL=$(PREFIX)/share/lua/$(LUA_VERSION)
# LIB_INSTALL is only used if a libluaX.Y.so file is created
LIB_INSTALL=$(PREFIX)/lib

# Locate YDB install
ydb_dist?=$(shell pkg-config --variable=prefix yottadb --silence-errors)
ifeq ($(ydb_dist),)
  $(error Could not find $$ydb_dist; please install yottadb or set $$ydb_dist to your YDB install')
endif
YDB_INSTALL:=$(ydb_dist)/plugin

# Determine whether make was called from luarocks using the --local flag (or a prefix within user's $HOME directory)
# If so, put mlua.so and mlua.xc files into a local directory
local:=$(shell echo "$(LUAROCKS_PREFIX)" | grep -q "^$(HOME)" && echo 1)
ifeq ($(local),1)
  PREFIX:=$(LUAROCKS_PREFIX)
  YDB_INSTALL:=$(PREFIX)/.yottadb/plugin
endif

# LuaRocks upload flags. Set to LRFLAGS=--force to overwrite existing rock or LRFLAGS=--api-key=<key> as needed
LRFLAGS:=


# ~~~  Internal variables

# Flags for when liblua is embedded (then include entire liblua.a into mlua.so)
LIBLUA := build/lua-$(LUA_BUILD)/install/lib/liblua.a
EMBED_FLAGS := -Wl,--whole-archive  $(LIBLUA)  -Wl,--no-whole-archive
# Flags for when liblua is shared
LIBLUA_SO := liblua$(LUA_VERSION).so
ifneq ($(SHARED_LUA), yes)
 $(shell rm -f $(LIBLUA_SO))  # ensure old local build doesn't cause confusion
 ifdef SHARED_LUA
  SHARED_LUA_SUPPLIED := true
  LIBLUA_SO := $(SHARED_LUA)
  ifeq (,$(wildcard $(LIBLUA_SO)))
   $(error Specified liblua file not found: LIBLUA_SO=$(LIBLUA_SO))
  endif
 endif
endif
SHARED_FLAGS := -L "$(dir $(LIBLUA_SO))" -l:"$(notdir $(LIBLUA_SO))"
# Select embed/shared option
MLUA_FLAGS := $(if $(SHARED_LUA), $(SHARED_FLAGS), $(EMBED_FLAGS))

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
fetch: fetch-lua fetch-lua-yottadb
	@# Download files for build; no internet required after this
build: build-lua build-lua-yottadb build-mlua
update: update-mlua update-lua-yottadb

build-mlua: mlua.so
update-mlua:
	git pull --rebase
mlua.o: mlua.c .ARG~LUA_BUILD build-lua
	$(CC) -c $<  -o $@ $(CFLAGS) $(LDFLAGS)
mlua.so: mlua.o  $(if $(SHARED_LUA), $(LIBLUA_SO))
	$(CC) $< -o $@  -shared  $(MLUA_FLAGS)

%: %.c *.h mlua.so .ARG~LUA_BUILD build-lua			# Just to help build my own temporary test.c files
	$(CC) $< -o $@  $(CFLAGS) $(LDFLAGS)


# ~~~ Lua: fetch lua versions and build them

# Set LUA_BUILD_TARGET to 'linux' or if LUA_BUILD >= 5.4.0, build target is 'linux-readline'
# readline is demanded only by lua <5.4 but override to included in all versions -- handy if we install this lua to the system
LUA_BUILD_TARGET:=linux$(shell echo -e " 5.4.0 \n $(LUA_BUILD) " | sort -CV && echo -readline)
# Switch on -fPIC in the only way that works with Lua Makefiles 5.1 through 5.4
# Set -std=gnu99 for Lua versions >=5.3, matching Lua's own Makefile
LUA_CC:=$(CC) -fPIC  $(shell echo -e " 5.3 \n $(LUA_VERSION) " | sort -CV && echo -std=gnu99)

fetch-lua: fetch-lua-$(LUA_BUILD) fetch-readline
build-lua: build-lua-$(LUA_BUILD)
fetch-lua-%: build/lua-%/Makefile ;
build-lua-%: build/lua-%/install/lib/liblua.a  $(if $(SHARED_LUA), $(LIBLUA_SO)) ;

ifeq ($(SHARED_LUA), yes)
 $(LIBLUA_SO): build/lua-$(LUA_BUILD)/install/lib/$(LIBLUA_SO)
	cp $< $@
 build/lua-%/install/lib/$(LIBLUA_SO): build/lua-%/install/lib/liblua.a
	$(CC) -o $@  -shared  -Wl,--whole-archive  $<  -Wl,--no-whole-archive
endif

build/lua-%/install/lib/liblua.a: build/lua-%/Makefile
	@echo Building $@
	@# tweak the standard Lua build with flags to make sure we can make a shared library (-fPIC)
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
build/lua-yottadb/_yottadb.so: build/lua-yottadb/Makefile $(wildcard build/lua-yottadb/*.[ch]) .ARG~LUA_BUILD build-lua                # Depends on build-lua because CFLAGS includes lua's .h files
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

# Define a newline macro -- only way to use use \n in info output. Note: needs two newlines after 'define' line
define \n


endef

# Print out all variables defined in this makefile
vars:
	$(info $(foreach v,$(.VARIABLES),$(if $(filter file, $(origin $(v)) ), $(\n)$(v)=$(value $(v))) ))
# Print all vars including those defined by make itself and environment variables
allvars:
	$(info $(foreach v,$(.VARIABLES), $(\n)$(v)=$(value $(v)) ))


# ~~~ Clean

# clean just our own mlua build
clean: clean-lua-yottadb
	rm -f *.o *.so try tests/db.* tests/mlua.xc tests/*.o
	rm -rf deploy
	rm -f mlua-*.rock
	$(MAKE) -C benchmarks clean  --no-print-directory
# clean everything we've built
cleaner: clean clean-luas clean-lua-yottadb
# clean & wipe build directory, including external downloads -- as if we'd only just now cloned the mlua source for the first time
cleanest: clean
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
export ydb_xc_mlua:=tests/mlua.xc


utf8:=$(shell echo $(ydb_chset) | grep -qi UTF-8 && echo utf8/)
export ydb_routines:=tests $(ydb_dist)/$(utf8)libyottadbutil.so

TMPDIR ?= /tmp
tmpgld = $(TMPDIR)/mlua-test
export ydb_gbldir=$(tmpgld)/db.gld

# The following line is needed to run utf8 test in github's ubuntu runner
export ydb_icu_version ?= $(shell pkg-config --modversion icu-io)

#To run specific tests, do: make test TESTS="testBasics testReadme"
test: build test-build
	@# Ensure no M object files remain which were built with a different ydb_chset
	rm -f tests/*.o
	@# Remove temporary global directories created by previous tests
	rm $(tmpgld) -rf  &&  mkdir -p $(tmpgld)
	cp tests/db.* $(tmpgld)/
	@# pipe to cat below prevents yottadb mysteriously adding confusing linefeeds in the output
	set -o pipefail && $(ydb_dist)/yottadb -run run^unittest $(TESTS) | cat
test-build: tests/mlua.xc tests/db.gld
tests/mlua.xc:
	sed -e 's|.*/mlua.so$$|./mlua.so|' mlua.xc >tests/mlua.xc
tests/db.gld tests/db.dat:
	@echo Creating Test Database
	rm -f tests/db.gld $(tmpgld)/db.dat
	mkdir -p $(tmpgld)
	ydb_gbldir=tests/db.gld   bash tests/createdb.sh $(ydb_dist) $(tmpgld)/db.dat  >/dev/null
	cp $(tmpgld)/db.dat tests/db.dat  # save it so later tests don't have to recreate it
benchmarks benchmark: build test-build
	@# Ensure no M object files remain which were built with a different ydb_chset
	rm -f benchmarks/*.o
	$(MAKE) -C benchmarks
anet-benchmarks: build test-build
	$(MAKE) -C benchmarks anet-benchmarks

#This also tests lua-yottadb with all Lua versions
fetchall: fetch-lua-yottadb
	@echo Fetching supported Lua versions
	@for lua in $(LUA_TEST_BUILDS); do \
		$(MAKE) fetch LUA_BUILD=$$lua --no-print-directory || exit 1; \
	done
buildall: fetchall
	@echo Building supported Lua versions
	@for lua in $(LUA_TEST_BUILDS); do \
		$(MAKE) build-lua LUA_BUILD=$$lua --no-print-directory || exit 1; \
	done
testall: fetchall
	@echo
	@echo "Testing mlua with ydb_chset={M,UTF-8} and Lua versions: $(LUA_TEST_BUILDS)"
	@for ydb_chset in M UTF-8; do \
		export ydb_chset ; \
		for lua in $(LUA_TEST_BUILDS); do \
			echo ; \
			echo "*** Testing Lua $$lua and ydb_chset=$$ydb_chset ***" ; \
			$(MAKE) clean-lua-yottadb LUA_BUILD=$$lua --no-print-directory || exit 1; \
			$(MAKE) LUA_BUILD=$$lua  all test  || { rm -f _yottadb.so yottadb.lua; exit 1; }; \
		done \
	done
	$(MAKE) clean-lua-yottadb --no-print-directory  # ensure not built with any Lua version lest it confuse future builds with default Lua
	@echo Successfully tested with Lua versions $(LUA_TEST_BUILDS)


# ~~~ Install

YDB_DEPLOYMENTS=mlua.so mlua.xc
LUA_LIB_DEPLOYMENTS=_yottadb.so
LUA_MOD_DEPLOYMENTS=yottadb.lua
install: build
	@[ "$(PREFIX)" == "$(SYSTEM_PREFIX)" ] \
		&& echo "Installing files to '$(YDB_INSTALL)', '$(LUA_LIB_INSTALL)', and '$(LUA_MOD_INSTALL)'" \
		&& echo "If you prefer to install to a local (non-system) deployment folder, run 'make install-local'" \
		&& echo || true
	@echo PREFIX=$(PREFIX)
	install -m644 -D $(YDB_DEPLOYMENTS) -t $(YDB_INSTALL)
	install -m644 -D $(LUA_MOD_DEPLOYMENTS) -t $(LUA_MOD_INSTALL)
	install -m644 -D $(LUA_LIB_DEPLOYMENTS) -t $(LUA_LIB_INSTALL)
 ifneq (,$(wildcard $(notdir $(LIBLUA_SO))))  # copy only if $LIBLUA_SO file exists:
	install -m644 -D $(LIBLUA_SO) -t $(LIB_INSTALL) && ldconfig
 endif

install-local: PREFIX:=deploy
install-local: YDB_INSTALL:=$(PREFIX)/ydb
install-local: install
install-lua: build-lua
	@echo "Installing Lua $(LUA_BUILD) to your system at `realpath $(PREFIX)`"
	install -m755 -DT build/lua-$(LUA_BUILD)/install/bin/lua $(PREFIX)/bin/lua$(LUA_VERSION)
	install -m755 -DT build/lua-$(LUA_BUILD)/install/bin/luac $(PREFIX)/bin/luac$(LUA_VERSION)
	@echo
	@echo "*** Note ***: Lua is now installed as $(PREFIX)/bin/lua$(LUA_VERSION)."
	@echo "Be aware that it is built as Position Independent Code (PIC), so it may be ever so slightly"
	@echo "slower than any system lua, typically at /usr/bin/lua"
	@echo

remove:
	rm -f $(foreach i,$(YDB_DEPLOYMENTS),$(YDB_INSTALL)/$(i))
	rm -f $(foreach i,$(LUA_LIB_DEPLOYMENTS),$(LUA_LIB_INSTALL)/$(i))
	rm -f $(foreach i,$(LUA_MOD_DEPLOYMENTS),$(LUA_MOD_INSTALL)/$(i))
remove-lua:
	rm -f $(PREFIX)/bin/lua$(LUA_VERSION)/lua
	rm -f $(PREFIX)/bin/lua$(LUA_VERSION)/luac


# ~~~ Release a new version and create luarock

#Fetch MLua version from mlua.h. You can override this with "VERSION=x.y-z" to regenerate a specific rockspec
VERSION=$(shell sed -Ene 's/#define MLUA_VERSION ([0-9]+),([0-9]+),([0-9a-zA-Z_]+).*/\1.\2-\3/p' mlua.h)
tag=v$(shell echo $(VERSION) | grep -Eo '[0-9]+.[0-9]+')

# Prevent git from giving detachedHead warning during luarocks pack
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=advice.detachedHead
export GIT_CONFIG_VALUE_0=false

rockspec: rockspecs/mlua.rockspec.template
	@echo Creating MLua rockspec $(VERSION)
	sed -Ee "s/(version += +['\"]).*(['\"].*)/\1$(VERSION)\2/" rockspecs/mlua.rockspec.template >rockspecs/mlua-$(VERSION).rockspec
release: rockspec
	git add rockspecs/mlua-$(VERSION).rockspec
	@git diff --quiet || { echo "Commit changes to git first"; exit 1; }
	@echo
	@read -p "About to push MLua git tag $(tag) with rockspec $(VERSION). Continue (y/n)? " -n1 && echo && [ "$$REPLY" = "y" ]
	@git merge-base --is-ancestor HEAD master@{upstream} || { echo "Push changes to git first"; exit 1; }
	rm -f tests/*.o
	luarocks make --local  # test that basic make works first
	! git tag -n $(tag) | grep -q ".*" || { echo "Tag $(tag) already exists. Run 'make untag' to remove the git tag first"; exit 1; }
	git tag -a $(tag)
	git push origin $(tag)
	git remote -v | grep "^upstream" && git push upstream $(tag)
	luarocks pack rockspecs/mlua-$(VERSION).rockspec
	luarocks upload $(LRFLAGS) rockspecs/mlua-$(VERSION).rockspec \
		|| { echo "Try 'make release LRFLAGS=--api-key=<key>'"; exit 2; }
untag:
	git tag -d $(tag)
	git push -d origin $(tag)
	git remote -v | grep "^upstream" && git push -d upstream $(tag)

$(shell mkdir -p build)			# So I don't need to do it in every target

#Prevent deletion of targets
.SECONDARY:
#Prevent leaving previous targets lying around and thinking they're up to date if you don't notice a make error
.DELETE_ON_ERROR:

#Note: do not list build-lua and fetch-lua as .PHONY: this allows them to be used as prerequisites of real targets
# (build-lua, at least, needs to be a prerequisite of anything that uses lua header files)
.PHONY: fetch fetch-lua-yottadb update-lua-yottadb update-mlua fetch-lua-%
.PHONY: build build-lua-yottadb build-lua-% build-mlua
.PHONY: benchmarks anet-benchmarks
.PHONY: install install-lua
.PHONY: rockspec release untag
.PHONY: all test vars
.PHONY: clean clean-luas clean-lua-% clean-lua-yottadb refresh
