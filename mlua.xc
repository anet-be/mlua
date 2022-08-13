$ydb_dist/plugin/mlua.so

lua: gtm_int_t mlua( I:gtm_string_t*, O:gtm_char_t* [1000], I:gtm_long_t )
open: ydb_long_t mlua_open( O:gtm_char_t* [1000], I:gtm_int_t )
close: void mlua_close( I:gtm_long_t ) : sigsafe
version:  ydb_int_t mlua_version_number() : sigsafe
