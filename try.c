// Minimal code to try embedding Lua

#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "mlua.h"


int main (void) {
  char buff[256];
  int error;

  printf("MLua version %s (%06u)\n", MLUA_VERSION_STRING, MLUA_VERSION_NUMBER);

  lua_State *L = luaL_newstate();  // opens Lua
  luaL_openlibs(L);   // opens the basic library

  while (fgets(buff, sizeof(buff), stdin) != NULL) {
    error = luaL_loadbuffer(L, buff, strlen(buff), "line") ||
            lua_pcall(L, 0, 0, 0);
    if (error) {
      fprintf(stderr, "%s", lua_tostring(L, -1));
      lua_pop(L, 1);  /* pop error message from the stack */
    }
  }

  lua_close(L);
  return 0;
}
