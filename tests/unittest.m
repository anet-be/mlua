;Test functions for MLua

;Invoke run() from command line: run^unittest <commands>
run()
 new allTests
 set allTests="testBasics testParameters testReadme testTreeHeight testInit testLuaState"
 if $zcmdline'="" set allTests=$zcmdline
 do test(allTests)
 quit

;Invoke with list of tests separated by spaces
test(testList)
 new command
 set failures=0,tests=0
 for i=1:1:$length(testList," ") do
 .set fail=0
 .set tests=tests+1
 .set command=$piece(testList," ",i)
 .do
 ..new (command,fail)  ;delete all unnecessary locals before each test
 ..w command,!
 ..do @command^unittest()
 .set failures=failures+fail
 if failures=0 write tests,"/",tests," tests PASSED!",!
 else  write failures,"/",tests," tests FAILED!",!
 quit

; Wrap mlua.lua() so that it handles errors; otherwise returns the output
; Handles up to 8 params, which matches mlua.xc
lua(lua,a1,a2,a3,a4,a5,a6,a7,a8)
 new o,result,line
 set result=$select($data(a1)=0:$&mlua.lua(lua,.o),$data(a2)=0:$&mlua.lua(lua,.o,,a1),$data(a3)=0:$&mlua.lua(lua,.o,,a1,a2),$data(a4)=0:$&mlua.lua(lua,.o,,a1,a2,a3),$data(a5)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4),$data(a6)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5),$data(a7)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6),$data(a8)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6,a7),0=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6,a7,a8))
 if result do
 .new line
 .set line=$stack($stack(-1)-1,"PLACE")
 .write "  Failed ("_line_"): "_o,!
 .set fail=1
 quit:$quit o quit

; Assert both parameters are equal
assert(str1,str2)
 new line
 set line=$stack($stack(-1)-1,"PLACE")
 if str1'=str2 write "  Failed ("_line_"): '",str1,"' <> '",str2,"'",! set fail=1
 quit

testBasics()
 new output,result
 ;Run some very basic invokation tests first (string.lower() is used as a noop)
 do &mlua.lua("string.lower('abc')")
 do assert(0,$&mlua.lua("string.lower('abc')"))
 do assert(0,$&mlua.lua("string.lower('abc')",.output))
 do assert("",output)
 do assert(1,0'=$&mlua.lua("print hello",.output))
 do assert("Lua: [string ""mlua(code)""]:1: syntax error near 'hello'",output)
 do assert(1,0'=$&mlua.lua("junk",.output))
 do assert("Lua: [string ""mlua(code)""]:1: syntax error near <eof>",output)
 do assert("",$$lua(""))
 do assert(1,0'=$&mlua.lua(">",.output))
 do assert("Lua: could not find global function ''",output)
 do assert(1,0'=$&mlua.lua(">unknown_func",.output))
 do assert("Lua: could not find global function 'unknown_func'",output)
 quit

testParameters()
 ;test mlua invokation using 1 to 9 arguments (9 should fail)
 new output
 do lua("function cat(...) return table.concat({...}) end")
 do assert("",$$lua(">cat"))
 do assert("1",$$lua(">cat",1))
 do assert("12",$$lua(">cat",1,2))
 do assert("123",$$lua(">cat",1,2,3))
 do assert("1234",$$lua(">cat",1,2,3,4))
 do assert("12345",$$lua(">cat",1,2,3,4,5))
 do assert("123456",$$lua(">cat",1,2,3,4,5,6))
 do assert("1234567",$$lua(">cat",1,2,3,4,5,6,7))
 do assert("12345678",$$lua(">cat",1,2,3,4,5,6,7,8))
 do assert("",$$lua("return table.concat({...})"))
 do assert("1",$$lua("return table.concat({...})",1))
 do assert("12",$$lua("return table.concat({...})",1,2))
 do assert("123",$$lua("return table.concat({...})",1,2,3))
 do assert("1234",$$lua("return table.concat({...})",1,2,3,4))
 do assert("12345",$$lua("return table.concat({...})",1,2,3,4,5))
 do assert("123456",$$lua("return table.concat({...})",1,2,3,4,5,6))
 do assert("1234567",$$lua("return table.concat({...})",1,2,3,4,5,6,7))
 do assert("12345678",$$lua("return table.concat({...})",1,2,3,4,5,6,7,8))
 new $etrap,error
 set $etrap="set error=$ecode if error["",M58,Z150374226,"" set $ecode="""""
 set output=""
 do
 .do assert(0,$&mlua.lua("return table.concat({...})",.output,,1,2,3,4,5,6,7,8,9))
 do assert(",M58,Z150374226,",error)
 do assert("",output)
 set error=""
 do
 .do assert(0,$&mlua.lua(">cat",.output,,1,2,3,4,5,6,7,8,9))
 do assert(",M58,Z150374226,",error)
 do assert("",output)
 quit

testReadme()
 new hello
 set hello="Hello World!"
 do assert("table",$$lua("ydb = require 'yottadb' return type(ydb)"))
 do assert(hello,$$lua("return ydb.get('hello')"))
 do assert("params: 1 2",$$lua("return 'params: '..table.concat({...},' ')",1,2))
 do assert("",$$lua("function add(a,b) return a+b end"))
 do assert("7",$$lua(">add",3,4))
 quit

testTreeHeight()
 new expected
 set ^oaks(1,"shadow")=10,^("angle")=30
 set ^oaks(2,"shadow")=13,^("angle")=30
 set ^oaks(3,"shadow")=15,^("angle")=45
 set expected="^oaks('1','angle')='30'$^oaks('1','shadow')='10'$^oaks('2','angle')='30'$^oaks('2','shadow')='13'$^oaks('3','angle')='45'$^oaks('3','shadow')='15'"
 set expected=$translate(expected,"'$",$C(34)_$C(10)) ;convert ' to ", and $ to newline
 do assert(expected,$$lua("return ydb.dump('^oaks')"))
 do lua("dofile 'tree_height.lua'")
 do lua("show_oaks( ydb.key('^oaks') )")
 set expected="^oaks('1','angle')='30'$^oaks('1','height')='5.7735026918963'$^oaks('1','shadow')='10'$^oaks('2','angle')='30'$^oaks('2','height')='7.5055534994651'$^oaks('2','shadow')='13'$^oaks('3','angle')='45'$^oaks('3','height')='15.0'$^oaks('3','shadow')='15'"
 set expected=$translate(expected,"'$",$C(34)_$C(10)) ;convert ' to ", and $ to newline
 do assert(expected,$$lua("return ydb.dump('^oaks')"))
 quit

testInit()
 ;inittest is set by MLUA_INIT for this test
 do assert("1",$$lua("return inittest"))
 quit

testLuaState()
 new newState,output
 do lua("test=3")
 do assert("3",$$lua("return test"))
 set newState=$&mlua.open()
 do &mlua.lua("return test",.output,newState)
 do assert("",output)
 do &mlua.lua("return test",.output,0)
 do assert("3",output)
 do &mlua.close(newState)  ;Can't really test this function except to run it, as it returns nothing
 quit
