// Lua for MUMPS header file

#ifndef MLUA_H
#define MLUA_H

#include "gtmxc_types.h"

// User functions
void mlua_open(int _argc);
gtm_status_t mlua(int _argc, const gtm_string_t *code, gtm_char_t *outstr);   // run Lua code, opening lua state if needed; returning status and outstr if error
void mlua_close(int _argc);

gtm_int_t mlua_version_number(int _argc);   // return version of this module as a decimal number AABBCC where AA=major; BB=minor; CC=release


// Version defines
#define MLUA_VERSION_MAJOR    0
#define MLUA_VERSION_MINOR    1
#define MLUA_VERSION_RELEASE  1
// Version number, encoded as two digits each AABBCC
#define MLUA_VERSION_NUMBER  (MLUA_VERSION_MAJOR *100*100 + MLUA_VERSION_MINOR *100 + MLUA_VERSION_RELEASE)
// Version number, encoded as a string A.B.C
#define _STRINGIFY(s) #s
#define STRINGIFY(s) _STRINGIFY(s)
#define MLUA_VERSION_STRING STRINGIFY(MLUA_VERSION_MAJOR) "." STRINGIFY(MLUA_VERSION_MINOR) "." STRINGIFY(MLUA_VERSION_RELEASE)

#define OUTPUT_STRING_MAXIMUM_LENGTH 1000


#endif // MLUA_H
