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

1. Done: keys iterator -- see `pairs()` below

2. Done: subscripts may now be not only strings but also integers, automatically converted to strings like ydb does. 
   - integer only, since floats will cause problems with rounding.
   - in Lua < 5.3 a number is treated as an integer provided tostring(number) has no decimal point; this maintains source compatibility between Lua versions.

3. Done: make key accept dot notation `key.subkey1.subkey2` -- this syntax has limitations on key name content which means the more general `key()` syntax must also be retained.

4. Done: allow assignment to `key.subkey`, which is equivalent to assignment to key.subkey.value

5. Done: create more terse ways of fetching dbase key._value:
   - Omit: access key.subscript.value by referencing `key.subscript` or key[subscript] -- but it would only work when there is no key.subscript.sub_subscript in the dbase (in which case it returns new key(subscript). This makes pretty code but turns out to be dangerous because if sub_subscripts are later added to the dbase, code accessing the key.subscript value will stop working. Plus, it only works on key.subscript not on key.
   - Omit: Could make unary operators access the key.value: ~key (lua>=5.3), #key (lua>=5.2), -key (lua>=5.0). This would be pretty, but are not the usual usage of these operators.
   - `key()` with empty parentheses (on second thought, I'm not sure how valuable this is)
   - `key['']` (on second thought, I'm not sure how valuable this is)
   - key._ This seems the best path and won't clobber many subscript names.

6. Done: Rename key properties to start with `_`: `.value, .get, .data` become `._value, ._get, ._data`, etc., so they don't clobber common dbase subscript names.

7. Done: Allow multiple subscripts as parameter lists or as a table in the follows new situations:
   - `key(sub1, sub2, ...)` or `key({sub1, sub2})`
   - make ydb.key(glvn, sub1, sub2, ...) to become equivalent to ydb.key(glvn, {sub1, sub2, ...})
   - ydb.get(glvn, sub1, sub2, ...) to become equivalent to ydb.get(glvn, {sub1, sub2, ...})
   - possibly ydb.set(glvn, sub1, sub2, ..., value) to become equivalent to ydb.set(glvn, {sub1, sub2, ...}, value) for the sake of consistency with get() and key()
   - To make this work efficiently demands a matching update to the low-level `yottadb.get()` to accept two subarrays (rather than a single concatenated one).

8. Done: rename `key` to `node` but retain a deprecated `key` with the original syntax for backward compatibility.

9. Done: make `pairs()` work as expected

10. Skip: making nodes act like Lua list-tables because it would generate inefficient db code; also unlikely to be used:

   - considered making ipairs() work using `__index()` from Lua 5.2 but later Lua versions implement `ipairs()` by invoking `__index()`.  So that would require making node index by an *integer* to act differently than indexing a node by a *string* as follows:

     - `node['abc']`  => produces a new node so that `node.abc.def.ghi` works
     - but `node[1]`  => would have to produce value `note(1)._value` for ipairs() to work
       This integer/string distinction can easily be done, but creates an unexpected syntax inconsistency.

     Instead, use pairs() with numeric subscripts or a numeric `for` as follows:

     - `for k,v in pairs(node) do   if not tonumber(k) break end   <do_your_stuff with k,v>   end`
     - `for i=1,1/0 do   v=node[i]._  if not v break then   <do_your_stuff with k,v>   end`

   - Decided not to define Lua `#` operator, which counts only sequential numeric keys and is mostly used in Lua to append to a table (t[#t+1] = n). Its use seems unlikely since ipairs() is not implemented, and there is also no way ydb-way to make it efficient. It's use does not match a typical M way of structuring arrays.

   - The consequence of the above is that standard Lua list functions (that use tables as integer-indexed lists) do not work. Specifically: `table.concat, table.insert, table.move, table.pack, table.remove, table.sort`

11. populate a ydb database global using Lua table constructors: `oaktree:set( {shadow=5, angle=30} )`

12. add ability to cast a key to a node: key(node) and node(key)

13. improve efficiency of lua-yottadb keys by caching them in the form of ydb locals so that the entire subscript array does not need to be looked up every access as is currently the case.

14. programmer usage improvements:

    - Improve ydb.dump and add it to the standard library
    - Implement a standardized mlua_startup.lua to define more useful table printing with print()


