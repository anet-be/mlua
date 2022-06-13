// Lua for MUMPS

#include <stdio.h>
#include <stddef.h>

#include "gtmxc_types.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "mlua.h"

lua_State *Lua = NULL;

void mlua_open(int _argc) {
  Lua = luaL_newstate();
  luaL_openlibs(Lua);
}

// run Lua code, opening lua state if needed; returning status and outstr if error
gtm_status_t mlua(int argc, const gtm_string_t *code, gtm_char_t *outstr) {
  if (argc<1) {
    fprintf(stderr, "\nNo Lua code string supplied");
    return -1;
  }
  if (Lua == NULL)
    mlua_open(0);
  int error = luaL_loadbuffer(Lua, code->address, code->length, "line")
                || lua_pcall(Lua, 0, 0, 0);
  if (argc>=2)
    outstr[0] = '\0';   // in case there is no error, set outstr to empty string
  if (error) {
    if (argc>=2 && outstr) {
      snprintf(outstr, OUTPUT_STRING_MAXIMUM_LENGTH, "%s", lua_tostring(Lua, -1));
    }
    lua_pop(Lua, 1);  // pop error message from the stack
  }
  return error;
}

void mlua_close(int _argc) {
  lua_close(Lua);
}

// Return version numbers for this module
ydb_int_t mlua_version_number(int _argc) {
  return MLUA_VERSION_NUMBER;
}
