// Lua for MUMPS header file

#ifndef MLUA_H
#define MLUA_H

#include "gtmxc_types.h"

// Bitfield of flags that may be passed to the optional flags parameter of mlua_open()
#define MLUA_IGNORE_INIT   0x01  /* Do not process code pointed to by MLUA_INIT environment variable */
#define MLUA_OPEN_DEFAULT  0x02  /* Used internally to specify opening the default Lua state */
#define MLUA_BLOCK_SIGNALS 0x04  /* Prevent signals from interrupting Lua (causing EINTR errors during 'slow' I/O) */

// use a value that is not used by YDB or ERRNO in case we decide to return those errors at some later point.
#define MLUA_ERROR -1

// User functions

// run Lua code, opening lua state if needed; returning nonzero on error (and filling optional errstr if supplied)
// optional lua_handle must be a lua_State handle returned by lua_open() or 0 to use the global lua_State
gtm_int_t mlua(int argc, const gtm_string_t *code, gtm_string_t *outstr, gtm_long_t luaState_handle, ...);

// open lua_State and return its luaState_handle
gtm_long_t mlua_open(int argc, gtm_string_t *outstr, gtm_int_t flags);

// close lua_State specified by lua_handle (which may be 0 for the global lua_State)
gtm_int_t mlua_close(int argc, gtm_long_t lua_handle);

// return MLUA_VERSION_NUMBER XXYYZZ where XX=major; YY=minor; ZZ=release
gtm_int_t mlua_version_number(int _argc);


// Define version: Maj,Min,Release
#define MLUA_VERSION 0,1,1
#define MLUA_VERSION_STRING   WRAP_PARAMETER(CREATE_VERSION_STRING, MLUA_VERSION)   /* "X.Y.Z" format */
#define MLUA_VERSION_NUMBER   WRAP_PARAMETER(CREATE_VERSION_NUMBER, MLUA_VERSION)   /* XXYYZZ numeric format */

// Version creation helper macros
#define WRAP_PARAMETER(macro, param) macro(param)
#define CREATE_VERSION_STRING(major, minor, release) #major "." #minor "." #release
#define CREATE_VERSION_NUMBER(major, minor, release) ((major)*100*100 + (minor)*100 + (release))


#endif // MLUA_H
