# MLua Compatibility

## Lua Versions

MLua is currently designed to be compatible with more than one Lua version as follows:

- 5.4 Compatible
- 5.3 Compatible
- <=5.2 Support would require changes:
  - Conversion of numbers to strings must stop using math.type for detection of integers and instead check for '.' in string rendering of float. Changes must be made to assert_strings_nums()
- <=5.1 Would need to change Makefile to know how to build this version of Lua

Older Lua versions are untested and would have to be built manually since the MLua Makefile does not know how to build them.

