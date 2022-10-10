# Lua-yottadb Syntax Upgrade Proposal

MLua uses lua-yottadb for its ydb-lua bindings, under the covers. This is as it should be, since lua-yottadb implements the Lua interface specified in the ydb [Multi-language Programmer's Guide](https://docs.yottadb.com/MultiLangProgGuide/luaprogram.html). However, that specification is not particularly Lua-esque: partly because it piggybacks off of the YDBPython bindings and partly because it is a bare-minimum implementation.

One of the MLua requirements is to implement an efficient but Lua-esque data exchange mechanism between Lua and ydb. I believe this can be done with meta-methods to overload getter, setter, and other functions of Lua tables. Lua tables are remarkably similar in structure to ydb globals. It seems possible to make this backward compatible.

This is a proposal to make ydb globals act like Lua tables, when in Lua. It will retain the binary-format efficiency of lua-yottadb by lazily populating table entries. The current syntax is non-intuitive in several respects, and somewhat long-winded, resulting in less clear code that is discouragement for the developer. Below is an example.

Let's use Lua to calculate the height of 3 oak trees based on their shadow length and the angle of the sun. First let's see the data in Mumps code:

```lua
set ^oaks(1,"shadow")=10,^("angle")=30
set ^oaks(2,"shadow")=13,^("angle")=30
set ^oaks(3,"shadow")=15,^("angle")=45
```

## Problem

Now, let's calculate with the old syntax:

```lua
oakkey = ydb.key('^oaks')
for sub in oakkey:subscripts() do
    oaktree=oakkey(sub)
    height = oaktree('shadow').value * math.tan( math.rad(oaktree('angle').value) )
    print(string.format('Oak %s is %.1fm high', sub, height))
    oaktree('height').value = height  -- save back into ydb
end
```

The problems are that:

1. It is long-winded: oakkey has to be created explicitly, to avoid repeated effort every access.
2. Iterating string subscripts (`sub`) takes an extra lookup line: `oaktree=oakkey(sub)` but iterating dbase objects would be more intuitive.
3. Explicit access to .value fields feels like unnecessary noise.

## Solution

In the proposed syntax, this would become:

```lua
for index, oaktree in ipairs(ydb.key('^oaks')) do
    oaktree.height = oaktree.shadow * math.tan( math.rad(oaktree.angle) )
    print(string.format('Oak %s is %.1fm high', index, oaktree.height))
end
```

Essentially, the database table `oaks` can now be accessed more like a regular table in Lua -- with either dot .notation or bracket[notation], and the use of the Lua standard pairs() iterators. Yet this new syntax retains the underlying efficiency of the database because table values are still only populated when they're needed, and they remain in binary format.

The breakdown of changes needed to implement this solution includes the following:

1. make a `subscript_keys()` iterator like `subscripts()` -- this may be superseded by standard Lua `pairs()` below
2. make `key()` accept numeric subscripts, automatically converting them to strings like ydb does (integer only as floats will cause problems with rounding)
3. make key accept dot notation `key.subkey1.subkey2` -- this syntax has limitations on key name content which means the more general `key()` syntax must also be retained.
4. allow assignment to `key.subkey`
5. make `key()` and `key.subkey` return key or value if no subkey -- open to discuss
6. make `key[subscript]` return value (rather than a sub-key node that key() returns)
7. make `key()` and `[]` take a subscript list, not just a single value. Efficiency demands a matching update to the low-level `yottadb.get()` to accept two subarrays (rather than a single concatenated one).
8. make `key[""]` (and `key[]` also, if possible in Lua) return key.value for syntax consistency
9. make `pairs()` work as expected, and any other metamethods required to make it table-like. Also:
   - consider making `ipairs()`, as in Lua, to allow iteration of a sequence with order preservation.
   - but for `ipairs()` to work it will need to iterate natural number keys, as in Lua, even though all keys are strings in YDB -- this would be a variation from Lua tables which only iterates keys of type `number`. However, since we auto-convert number keys to strings (point 2 above), this will seem normal to the Lua user.
   - care needed to make it backward compatible with Lua 5.2 which works differently with its `__ipairs` metamethod that 5.3 lost.
10. define Lua `#` operator (which counts only sequential numeric keys) if there is a ydb-way to make it efficient. The main benefit would be to provide compatibility with Lua functions that operate on tables. It's use does not match a typical M way of structuring arrays.
11. populate a ydb database global using Lua table constructors: `oaktree:set( {shadow=5, angle=30} )`
12. improve efficiency of lua-yottadb keys by caching them in the form of ydb locals so that the entire subscript array does not need to be looked up every access as is currently the case.

