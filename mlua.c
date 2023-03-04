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

// Enable build against Lua older than 5.3
#include "compat-5.3.h"

#include "mlua.h"

#define DEFAULT_OUTPUT stdout

// Declare struct of header and array used to store list of open states
typedef struct state_array_t {
  int size;
  int used;
  lua_State *handles[];
} state_array_t;

#define STATE_ARRAY_LUMPS 10 /* increment the state array in lumps of this many states */
state_array_t *State_array = NULL;


// like printf but fills gtm_string_t with up to maximum size
// do nothing and return -2 if output is NULL or output->address is NULL
// returns -1 if it had to truncate the output
// otherwise return 0
int outputf(gtm_string_t *output, int output_size, const char *fmt, ...) {
  if (output && !output->address) output=NULL;
  va_list argp;
  va_start(argp, fmt);
  if (output) {
    output->length = vsnprintf(output->address, output_size, fmt, argp);
    if (output->length > output_size) {  // snprintf truncates but still returns full output size
      output->length = output_size-1;   // drop final NUL
      va_end(argp);
      return -1;
    }
  } else {
    vfprintf(DEFAULT_OUTPUT, fmt, argp);
    fflush(DEFAULT_OUTPUT);
  }
  va_end(argp);
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

// Initialize State_array if it hasn't already been initialized
// return 0 on allocation failure
int init_state_array(void) {
  if (State_array) return !0;
  // initially, allocate space for just the default handle
  State_array = malloc(sizeof(state_array_t) + sizeof(lua_State*));
  if (!State_array) return 0;
  // Mark state zero (default state) as already used so that when a user calls mlua_open()
  // without MLUA_OPEN_DEFAULT flag, it returns a non-zero handle
  State_array->size = State_array->used = 1;
  State_array->handles[0] = NULL;
  return !0;
}

// Create new Lua_State, and initialize with default lua libs
//    and run the text in environment variable MLUA_INIT (or run the file if it starts with @)
// Flags is an optional bitfield, whose bitmasks are defined in mlua.h as follows:
//    MLUA_IGNORE_INIT: ignore MLUA_INIT
// return new lua_State handle or zero if there is an error, with error message as follows:
//    optional output returns empty on success or an error message on error (or on stdout if output missing)
gtm_long_t mlua_open(int argc, gtm_string_t *output, gtm_int_t flags) {
  lua_State *L;
  if (argc<1) output=NULL; // don't return error string
  if (argc<2) flags=0;
  int output_size = output? output->length: 0; // ydb sets it to preallocated size

  if (!init_state_array())
    return outputf(output, output_size, "MLua: Could not allocate memory for lua_State"), 0;

  // allocate new lua state and add to array of state handles
  L = luaL_newstate();
  if (!L)
    return outputf(output, output_size, "MLua: Could not allocate memory for lua_State"), 0;
  int handle;
  if (flags & MLUA_OPEN_DEFAULT)
    handle = 0;
  else {
    if (State_array->used >= State_array->size) {
      State_array = realloc(State_array, sizeof(state_array_t) + (State_array->size+STATE_ARRAY_LUMPS) * sizeof(lua_State*));
      if (!State_array)
        return outputf(output, output_size, "MLua: Could not allocate memory for lua_State"), 0;
      State_array->size += STATE_ARRAY_LUMPS;
    }
    handle = State_array->used;
  }

  // Open default lua libs and add them to the new lua_State
  lua_pushcfunction(L, luaL_openlibs_ret0);
  int args=0, results=0, error_handler=0;
  int error = lua_pcall(L, args, results, error_handler);
  if (error) {
    outputf(output, output_size, "Lua: in init luaL_openlibs(), %s", lua_tostring(L, -1));
    lua_pop(L, 1);  // pop error message from the stack
    lua_close(L);  // We haven't successfully opened it fully, so close it
    return 0;
  }

  // execute code in the environment variable MLUA_INIT (or in the file it specifies with @file)
  char *mlua_init=NULL;
  if (!(flags&MLUA_IGNORE_INIT))
    mlua_init = getenv("MLUA_INIT");
  if (mlua_init) {
    if (mlua_init[0] == '@')
      error = luaL_loadfile(L, mlua_init+1);
    else
      error = luaL_loadbuffer(L, mlua_init, strlen(mlua_init), mlua_init);
    if (!error)
      error = lua_pcall(L, args, results, error_handler);
    if (error) {
      outputf(output, output_size, "MLua: MLUA_INIT, %s", lua_tostring(L, -1));
      lua_pop(L, 1);  // pop error message from the stack
      lua_close(L);   // We haven't successfully opened it fully, so close it
      return 0;
    }
  }

  // clear error string & return handle
  outputf(output, output_size, "");
  State_array->handles[handle] = L;
  if (handle)
    State_array->used = handle+1;
  return handle;
}

// Close the lua_State specified by luaState_handle
// if luaState_handle is 0, close the default lua_State
// if luaState_handle is not supplied, close all lua_States
// return 0 on success, -1 if the supplied handle is invalid, and -2 if the supplied handle is already closed
gtm_int_t mlua_close(int argc, gtm_long_t luaState_handle) {
  lua_State *L;

  if (!State_array) return -1;

  // close all handles
  if (argc < 1) {
    for (gtm_long_t i=0; i<State_array->used; i++)
      if (State_array->handles[i])
        mlua_close(1, i);
    return 0;
  }

  // close a specific handle
  if (luaState_handle<0 || luaState_handle>=State_array->used)
    return -1;
  L = State_array->handles[luaState_handle];
  if (!L)
    return -2;
  lua_close(L);
  State_array->handles[luaState_handle] = NULL; // ensure we don't close it twice

  // Mark any empy handles at the end of the array as unused.
  // Avoids constant array increase for programs that constantly create and kill Lua states
  // Leave state zero (default state) marked as 'used' because when someone calls mlua_open() it must always return a non-zero handle
  while (State_array->used > 1 && !State_array->handles[State_array->used-1])
    State_array->used--;
  return 0;
}


// mlua_lua() helper to translate code string into a function
// push function if it's a global function name (starting with '>'); allows '.' notation like, "math.abs"
// otherwise compile the code into a function and push that
// return 0 and the compiled function on top of the Lua stack
// on error, return 1 with the error message string on the top of the Lua stack
static int push_code(lua_State *L, const gtm_string_t *code_string) {
  // compile the code and push it
  if (!code_string->length || code_string->address[0] != '>')
    return luaL_loadbuffer(L, code_string->address, code_string->length, "mlua(code)");

  // otherwise look up function name in global (e.g. module) table and push it instead
  lua_pushglobaltable(L);
  char *end, *name = code_string->address + 1;
  int type, len, pathlen=code_string->length-1;
  do {
    end = memchr(name, '.', pathlen);
    len = pathlen;
    if (end)
      len = end-name, pathlen -= len+1;
    lua_pushlstring(L, name, len);
    type = lua_rawget(L, -2); // look up -2[-1] = globals[func_name]
    lua_remove(L, -2); // drop lookup table (second-to-top place on the stack)
    name = end+1;
  } while (end && type == LUA_TTABLE);

  // handle not-found error
  if (type != LUA_TFUNCTION) {
    lua_pop(L, 1);  // pop bad function from the stack
    // allocate space for NUL-terminated version of code_string function name
    char *zname = malloc(code_string->length+1-1);   // new size to include '\0' but not '>'
    if (zname) {
      memcpy(zname, code_string->address+1, code_string->length-1);
      zname[code_string->length-1] = '\0'; // NUL-terminate
    }
    if (type == LUA_TNIL)
      lua_pushfstring(L, "could not find function '%s'", zname);
    else
      lua_pushfstring(L, "tried to invoke '%s' as a function but it is of type: %s", zname, lua_typename(L, type));
    free(zname);
    return 1;
  }
  return 0;
}

// mlua_lua() helper to format result output data type for more natural interpretation by M
// the data type is passed in on the top of the Lua stack and is popped off before return
static void format_result(lua_State *L, gtm_string_t *output, int output_size) {
  size_t len;
  const char *s;
  if (output && !output->address) output=NULL;
  int output_type = lua_type(L, -1);
  switch (output_type) {
    case LUA_TNIL:
      if (!output) goto done;
      output->address[0] = '\0';
      output->length = 0;
      break;
    case LUA_TBOOLEAN:
      if (!output) {
        fprintf(DEFAULT_OUTPUT, "%d", lua_toboolean(L, -1));
        fflush(DEFAULT_OUTPUT);
        goto done;
      }
      output->address[0] = '0' + lua_toboolean(L, -1);
      output->address[1] = '\0';
      output->length = 1;
      break;
    case LUA_TNUMBER:
    case LUA_TSTRING:
      // return output string, ensuring that strings containing NULs are correctly returned in full
      s = lua_tolstring(L, -1, &len);
      if (!output) {
        if (output_type == LUA_TNUMBER) {
          // convert any exponential notation 'e' in a number to 'E' so YDB can understand it.
          char *e_position = memchr(s, 'e', len);
          if (e_position) {
            fwrite(s, 1, e_position-s, DEFAULT_OUTPUT);
            fwrite("E", 1, 1, DEFAULT_OUTPUT);
            s = e_position+1;
            len -= e_position - s + 1;
          }
        }
        fwrite(s, 1, len, DEFAULT_OUTPUT);
        fflush(DEFAULT_OUTPUT);
        goto done;
      }
      if (len > output_size)
        len = output_size;
      memcpy(output->address, s, len);
      output->length = len;
      if (output_type == LUA_TNUMBER) {
        // convert any exponential notation 'e' in a number to 'E' so YDB can understand it.
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
// If luaState_handle is 0 or not supplied, use the default lua_State (opening it if needed),
//    but be aware that any threaded app (e.g. a C app linked into to ydb)
//    must not call the same lua_State from multiple threads
// return 0 on success and return a string representation of the return value in .output (if supplied) or on stdout
// return <0 on error and return the error message in .output (if supplied) or on stdout
gtm_int_t mlua_lua(int argc, const gtm_string_t *code, gtm_string_t *output, gtm_long_t luaState_handle, ...) {
  if (argc<1) return MLUA_ERROR;  // no code to run so return error status -- but can't return output string (not supplied)
  if (argc<2 || !output || !output->address) output=NULL; // don't return output string
  int output_size = output? output->length: 0; // ydb sets it to preallocated size

  // check that luaState is valid
  if (!init_state_array())
    return outputf(output, output_size, "MLua: could not allocate space for luaState array"), MLUA_ERROR;
  if (argc<3) luaState_handle=0; // use default lua_State
  if (luaState_handle) {
    if (luaState_handle<0 || luaState_handle>=State_array->used)
      return outputf(output, output_size, "MLua: supplied luaState (%li) is invalid", luaState_handle), MLUA_ERROR;
    if (!State_array->handles[luaState_handle])
      return outputf(output, output_size, "MLua: supplied luaState (%li) has been closed", luaState_handle), MLUA_ERROR;
  }
  lua_State *L = State_array->handles[luaState_handle];

  // open default lua state if necessary
  if (!L) {
    luaState_handle = mlua_open(2, output, MLUA_OPEN_DEFAULT);
    L = State_array->handles[0];
    if (!L)
      return MLUA_ERROR;  // could not open; note: output already filled by opener
  }

  // push function if it's a function name; otherwise compile the code
  int error = push_code(L, code);
  if (!error) {
    // push any optional parameters as function parameters to Lua
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
