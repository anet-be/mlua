// Lua for MUMPS

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "gtmxc_types.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "mlua.h"

// For one Lua instance per process, this works, since each process gets new shared library globals.
// But to make MUMPS support multiple simultaneous Lua instances,
// we'd need to return this handle to the user instead of making it a global.
lua_State *Global_lua = NULL;


// like printf but fills gtm_string_t with up to maximum size
// do nothing and return -2 if output is NULL or output->address is NULL
// returns -1 if it had to truncate the output
// otherwise return 0
int outputf(gtm_string_t *output, int output_size, const char *fmt, ...) {
  if (!output || !output->address) return -2;
  va_list argp;
  va_start(argp, fmt);
  output->length = vsnprintf(output->address, output_size, fmt, argp);
  va_end(argp);
  if (output->length > output_size) {  // snprintf truncates but still returns full output size
    output->length = output_size-1;   // drop final null
    return -1;
  }
  return 0;
}

// Wrap luaL_openlibs to change it to type lua_CFunction so we can call it with protected pcall
static int luaL_openlibs_ret0(lua_State *L) {
  luaL_openlibs(L);
  return 0; // return no parameters
}

// Return version numbers for this module
gtm_int_t mlua_version_number(int _argc) {
  return MLUA_VERSION_NUMBER;
}

// Create new Lua_State, and initialize with default lua libs
//    and run the text in environment variable MLUA_INIT (or run the file if it starts with @)
// Flags is an optional bitfield, whose bitmasks are defined in mlua.h as follows:
//    MLUA_IGNORE_INIT: ignore MLUA_INIT
// return new lua_State handle or zero if there is an error
//    optional output returns empty on success or an error message on error
gtm_long_t mlua_open(int argc, gtm_string_t *output, gtm_int_t flags) {
  lua_State *L;
  if (argc<1) output=NULL; // don't return error string
  if (argc<2) flags=0;
  int output_size = output? output->length: 0; // ydb sets it to preallocated size

  // allocate new lua state
  L = luaL_newstate();
  if (!L) {
    outputf(output, output_size, "MLua: Could not allocate lua_State -- possible memory lack");
    return 0;
  }

  // Open default lua libs and add them to the new lua_State
  lua_pushcfunction(L, luaL_openlibs_ret0);
  int args=0, results=0, error_handler=0;
  int error = lua_pcall(L, args, results, error_handler);
  if (error) {
    outputf(output, output_size, "Lua: in init luaL_openlibs(), %s", lua_tostring(L, -1));
    lua_pop(L, 1);  // pop error message from the stack
    return 0;
  }

  // execute code in the environment variable MLUA_INIT (or in the file it specifies with @file)
  char *mlua_init=NULL;
  if (!(flags&MLUA_IGNORE_INIT))
    mlua_init = getenv("MLUA_INIT");
  if (mlua_init) {
    int error;
    if (mlua_init[0] == '@')
      error = luaL_loadfile(L, mlua_init+1);
    else
      error = luaL_loadbuffer(L, mlua_init, strlen(mlua_init), mlua_init);
    if (!error)
      error = lua_pcall(L, args, results, error_handler);
    if (error) {
      outputf(output, output_size, "Lua: MLUA_INIT, %s", lua_tostring(L, -1));
      lua_pop(L, 1);  // pop error message from the stack
      return 0;
    }
  }

  // clear error string & return handle
  outputf(output, output_size, "");
  return (gtm_long_t)L;
}

// Close the lua_State specified by luaState_handle or close the global lua_State if no handle provided
void mlua_close(int argc, gtm_long_t luaState_handle) {
  if (argc < 1) luaState_handle = 0;
  lua_State *L=(lua_State *)luaState_handle;
  if (!L) {
    L = Global_lua;
    Global_lua = NULL;  // ensure we don't crash by closing the same global lua next time
  }
  if (L) lua_close(L);
}


// mlua_lua() helper to translate code string into a function
// push function if it's a global function name (starting with '>'); otherwise compile the code
// return 0 and the compiled function on top of the Lua stack
// on error, return 1 with the error message string on the top of the Lua stack
static int push_code(lua_State *L, const gtm_string_t *code_string) {
  // Compile the code and push it
  if (code_string->address[0] != '>')
    return luaL_loadbuffer(L, code_string->address, code_string->length, "mlua(code)");

  // Otherwise look up function name in global table and push it instead
  lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS); // push globals table
  lua_pushlstring(L, code_string->address+1, code_string->length-1);
  int type = lua_rawget(L, -2); // look up -2[-1] = globals[func_name]
  lua_remove(L, -2); // drop globals table (second-to-top place on the stack)
  if (type != LUA_TFUNCTION) {
    lua_pop(L, 1);  // pop bad function from the stack
    // allocate space for null-terminated version of code_string function name
    char *name = malloc(code_string->length-1+1);   // size for no '>' but add '\0'
    if (name) {
      memcpy(name, code_string->address+1, code_string->length-1);
      name[code_string->length-1] = '\0'; // null-terminate
    }
    if (type == LUA_TNIL)
      lua_pushfstring(L, "could not find global function '%s'", name);
    else
      lua_pushfstring(L, "tried to invoke global '%s' as a function but it is of type: %s", name, lua_typename(L, type));
    free(name);
    return 1;
  }
  return 0;
}

// mlua_lua() helper to format result output data type for more natural interpretation by M
// assume result is on top of the Lua stack & pop it off
static void format_result(lua_State *L, gtm_string_t *output, int output_size) {
  if (!output) goto done;
  size_t len;
  const char *s;
  int output_type = lua_type(L, -1);
  switch (output_type) {
    case LUA_TNIL:
      output->address[0] = '\0';
      output->length = 0;
      break;
    case LUA_TBOOLEAN:
      output->address[0] = '0' + lua_toboolean(L, -1);
      output->address[1] = '\0';
      output->length = 1;
      break;
    case LUA_TNUMBER:
    case LUA_TSTRING:
      // Return output string, ensuring that strings containing nulls are correctly returned in full
      s = lua_tolstring(L, -1, &len);
      if (len > output_size)
        len = output_size;
      memcpy(output->address, s, len);
      output->length = len;
      if (output_type == LUA_TNUMBER) {
        // Convert any exponential notation 'e' in a number to 'E' so YDB can understand it.
        char *e_position = memchr(output->address, 'e', len);
        if (e_position) *e_position = 'E';
      }
      break;
    default:
      outputf(output, output_size, "(%s)", lua_typename(L, output_type));
  }
done:
  lua_pop(L, 1);  // pop result from the Lua stack
}

// Run Lua code
// If luaState_handle is 0, use the global lua_State (opening it if needed),
//    but be aware that any threaded app (e.g. a C app linked into to ydb)
//    must not call the same lua_State from multiple threads
// return 0 on success and return a string representation of the return value in .output if .output was supplied
// return <0 on error and return the error message in .output if .output was supplied
gtm_int_t mlua_lua(int argc, const gtm_string_t *code, gtm_string_t *output, gtm_long_t luaState_handle, ...) {
  if (argc<1) return MLUA_ERROR;  // no code to run so return error status -- but can't return output string (not supplied)
  if (argc<2 || !output->address) output=NULL; // don't return output string
  if (argc<3) luaState_handle=0; // use global lua_State
  int output_size = output? output->length: 0; // ydb sets it to preallocated size

  // open global lua state if necessary
  lua_State *L=(lua_State *)luaState_handle;
  if (!L) L=Global_lua;
  if (!L) {
    L = (lua_State *)mlua_open(2, output, 0);
    if (!L) return MLUA_ERROR;  // could not open; note: output already filled by opener
    Global_lua = L;
  }

  // Push function if it's a function name; otherwise compile the code
  int error = push_code(L, code);
  if (!error) {
    // Push any optional parameters as function parameters to Lua
    int args = argc-3<0? 0: argc-3;
    if (args) {
      va_list ptr;
      va_start(ptr, luaState_handle);
      for (int i=0; i<args; i++) {
        gtm_string_t *s = va_arg(ptr, gtm_string_t*);
        lua_pushlstring(L, s->address, s->length);
      }
      va_end(ptr);
    }
    int results=1, error_handler=0;
    error = lua_pcall(L, args, results, error_handler);
  }
  if (error) {
    outputf(output, output_size, "Lua: %s", lua_tostring(L, -1));
    lua_pop(L, 1);  // pop error message from the stack
    return MLUA_ERROR;
  }
  format_result(L, output, output_size);
  return 0;
}
