// Lua for MUMPS header file

#ifndef MLUA_H
#define MLUA_H

#include "gtmxc_types.h"

// User functions
void mlua_open(int _argc);
gtm_status_t mlua(int _argc, const gtm_string_t *code, gtm_char_t *outstr);   // run Lua code, opening lua state if needed; returning status and outstr if error
void mlua_close(int _argc);

gtm_int_t mlua_version_number(int _argc);   // return version of this module as a decimal number AABBCC where AA=major; BB=minor; CC=release


#define OUTPUT_STRING_MAXIMUM_LENGTH 1000


// Define version: Maj,Min,Release
#define MLUA_VERSION 0,1,1
#define MLUA_VERSION_STRING   WRAP_PARAMETER(CREATE_VERSION_STRING, MLUA_VERSION)
#define MLUA_VERSION_NUMBER   WRAP_PARAMETER(CREATE_VERSION_NUMBER, MLUA_VERSION)

// Version creation helper macros
#define WRAP_PARAMETER(macro, param) macro(param)
#define CREATE_VERSION_STRING(major, minor, release) #major "." #minor "." #release
#define CREATE_VERSION_NUMBER(major, minor, release) ((major)*100*100 + (minor)*100 + (release))


#endif // MLUA_H
