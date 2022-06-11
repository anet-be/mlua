$ydb_dist/plugin/mlua.so

lua: gtm_status_t mlua( I:gtm_string_t*, O:gtm_char_t* [1000] ) : sigsafe
luaOpen: void mlua_open( ) : sigsafe
luaClose: void mlua_close( ) : sigsafe
version:  ydb_int_t mlua_version_number() : sigsafe
