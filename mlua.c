// Lua for MUMPS

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "gtmxc_types.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "mlua.h"

// For one Lua instance per process, this works, since each process gets new shared library globals.
// But to make MUMPS support multiple simultaneous Lua instances,
// we'd need to return this handle to the user instead of making it a global.
lua_State *Global_lua = NULL;

// Same as lua_pcall but sets args, results, error_handler as we wish
static int mlua_pcall(lua_State *lua) {
  int args=0, results=0;
  int error_handler=0;
  return lua_pcall(lua, args, results, error_handler);
}

// Wrap luaL_openlibs to change it to type lua_CFunction so we can call it with protected pcall
static int luaL_openlibs_ret0(lua_State *lua) {
  luaL_openlibs(lua);
  return 0; // return no parameters
}

// Create new Lua_State, and initialize with default lua libs
//    and run the text in environment variable MLUA_INIT (or run the file if it starts with @)
// Flags is an optional bitfield, whose bitmasks are defined in mlua.h as follows:
//    MLUA_IGNORE_INIT: ignore MLUA_INIT
// return new lua_State handle or zero if there is an error
//    optional errstr returns empty on success or an error message on error
gtm_long_t mlua_open(int argc, gtm_char_t *errstr, gtm_int_t flags) {
  lua_State *lua;

  if (argc<1) errstr=NULL;
  if (argc<2) flags=0;

  // allocate new lua state
  lua = luaL_newstate();
  if (!lua) {
    if (errstr)
      snprintf(errstr, OUTPUT_STRING_MAXIMUM_LENGTH, "Could not allocate lua_State -- possible memory lack");
    return 0;
  }

  // Open default lua libs and add them to the new lua_State
  lua_pushcfunction(lua, luaL_openlibs_ret0);
  int error = mlua_pcall(lua);
  if (error) {
    if (errstr)
      snprintf(errstr, OUTPUT_STRING_MAXIMUM_LENGTH, "%s", lua_tostring(lua, -1));
    lua_pop(lua, 1);  // pop error message from the stack
    return 0;
  }

  // execute code in the environment variable MLUA_INIT (or in the file it specifies with @file)
  char *mlua_init=NULL;
  if (!(flags&MLUA_IGNORE_INIT))
    mlua_init = getenv("MLUA_INIT");
  if (mlua_init) {
    int error;
    if (mlua_init[0] == '@')
      error = luaL_loadfile(lua, mlua_init+1);
    else
      error = luaL_loadbuffer(lua, mlua_init, strlen(mlua_init), "MLUA_INIT");
    error = error || mlua_pcall(lua);
    if (error) {
      if (errstr)
        snprintf(errstr, OUTPUT_STRING_MAXIMUM_LENGTH, "%s", lua_tostring(lua, -1));
      lua_pop(lua, 1);  // pop error message from the stack
      return 0;
    }
  }

  if (errstr) errstr[0] = '\0';   // clear error string
  return (gtm_long_t)lua;
}

// Run Lua code
// If lua_handle is 0, use the global lua_State (opening it if needed),
//    but be aware that multiple ydb threads must not use the same lua_State
// return 0 on success with an empty errstr, if specified
//    optional errstr returns an error message on error
gtm_status_t mlua(int argc, gtm_long_t lua_handle, const gtm_string_t *code, gtm_char_t *errstr) {
  if (argc<2) return -1;  // no code to run so return error status -- but can't return output string (not supplied)
  if (argc<3) errstr=NULL;

  // open global lua state if necessary
  lua_State *lua=(lua_State *)lua_handle;
  if (!lua) lua=Global_lua;
  if (!lua) {
    lua = (lua_State *)mlua_open(2, errstr, 0);
    if (!lua) return -2;  // could not open; note: errstr already filled by opener
    Global_lua = lua;
  }

  int error = luaL_loadbuffer(lua, code->address, code->length, "mlua(code)")
              || mlua_pcall(lua);
  if (error) {
    if (errstr)
      snprintf(errstr, OUTPUT_STRING_MAXIMUM_LENGTH, "%s", lua_tostring(lua, -1));
    lua_pop(lua, 1);  // pop error message from the stack
    return -3;
  }
  if (errstr) errstr[0] = '\0';   // clear error string
  return error!=LUA_OK;
}

// Close the lua state specified by lua_handle or close the global lua_State if no handle provided
void mlua_close(int argc, gtm_long_t lua_handle) {
  if (argc < 1) lua_handle = 0;
  lua_State *lua=(lua_State *)lua_handle;
  if (!lua) {
    lua = Global_lua;
    Global_lua = NULL;  // ensure we don't crash by closing the same global lua next time
  }
  if (lua) lua_close(lua);
}

// Return version numbers for this module
gtm_int_t mlua_version_number(int _argc) {
  return MLUA_VERSION_NUMBER;
}
