$ydb_dist/plugin/mlua.so

lua: gtm_int_t mlua_lua( I:gtm_string_t*, O:gtm_string_t* [1048576], I:gtm_long_t, I:gtm_string_t*, I:gtm_string_t*, I:gtm_string_t*, I:gtm_string_t*, I:gtm_string_t*, I:gtm_string_t*, I:gtm_string_t*, I:gtm_string_t* )
open: gtm_long_t mlua_open( O:gtm_string_t* [2049], I:gtm_int_t )
close: gtm_int_t mlua_close( I:gtm_long_t ) : sigsafe
version:  gtm_int_t mlua_version_number() : sigsafe
