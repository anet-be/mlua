// Lua for MUMPS

#include <stdio.h>
#include <stddef.h>

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

// Create new Lua_State, and initialize with default lua libs
// return new lua_State handle or zero if there is an error
// outstr returns empty on success or an error message on error
gtm_long_t mlua_open(int argc, gtm_char_t *outstr) {
  lua_State *lua;

  // allocate new lua state
  lua = luaL_newstate();
  if (!lua) {
    if (argc >= 1 && outstr) {
      snprintf(outstr, OUTPUT_STRING_MAXIMUM_LENGTH, "Could not allocate lua_State -- possible memory lack");
    }
    return 0;
  }

  // load lua state with default libs
  // note: since we pass #args to lua_pcall(), it ignores the return value of the function,
  // therefore it is possible to cast void luaL_openlibs() to lua_CFunction (which returns int #args)
  lua_pushcfunction(lua, (lua_CFunction)luaL_openlibs);
  int error = mlua_pcall(lua);
  if (error) {
    if (argc >= 1 && outstr) {
      snprintf(outstr, OUTPUT_STRING_MAXIMUM_LENGTH, "%s", lua_tostring(lua, -1));
    }
    lua_pop(lua, 1);  // pop error message from the stack
    return -2;
  }
  if (argc >= 1 && outstr) outstr[0] = '\0';   // clear error string
  return (gtm_long_t)lua;
}

// Run Lua code
// If lua_handle is 0, use the global lua_State (opening it if needed),
// but be aware that multiple ydb threads must not use the same lua_State
// return 0 on success with an empty outstr
// outstr returns an error message on error
gtm_status_t mlua(int argc, gtm_long_t lua_handle, const gtm_string_t *code, gtm_char_t *outstr) {
  if (argc<2) return -1;  // no code to run so return error status -- but can't return output string (not supplied)

  // open global lua state if necessary
  lua_State *lua=(lua_State *)lua_handle;
  if (!lua) lua = Global_lua;
  if (!lua) {
    lua = (lua_State *)mlua_open(argc>=3, outstr);
    if (!lua) return -2;  // could not open; outstr already filled by opener
    Global_lua = lua;
  }

  int error = luaL_loadbuffer(lua, code->address, code->length, "mlua(code)")
                || mlua_pcall(lua);
  if (error) {
    if (argc >= 3 && outstr) {
      snprintf(outstr, OUTPUT_STRING_MAXIMUM_LENGTH, "%s", lua_tostring(lua, -1));
    }
    lua_pop(lua, 1);  // pop error message from the stack
  }
  if (argc >= 3 && outstr) outstr[0] = '\0';   // clear error string
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
