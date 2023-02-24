;Test functions for MLua

;Invoke run() from command line: run^unittest <commands>
run()
 new allTests
 set allTests="testBasics testReadme testTreeHeight testInit testLuaState"
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

; Wrap mlua.lua() so that it handles errors, else returns the output
; Currently only handles up to 4 params for the sake of a shorter $select() function
lua(lua,a1,a2,a3,a4)
 new o,result
 set result=$select($data(a1)=0:$&mlua.lua(lua,.o),$data(a2)=0:$&mlua.lua(lua,.o,,a1),$data(a3)=0:$&mlua.lua(lua,.o,,a1,a2),$data(a4)=0:$&mlua.lua(lua,.o,,a1,a2,a3),0=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4))
 if result write o set $ecode=",U1,"
 quit:$quit o quit

; Assert both parameters are equal
assert(str1,str2)
 if str1'=str2 write "  Failed: '",str1,"' <> '",str2,"'",! set fail=1
 quit

testBasics()
 new output,result
 ;Run some very basic invokation tests first
 do &mlua.lua("string.lower('abc')")
 set result=$&mlua.lua("string.lower('abc')")
 if result'=0 zhalt 2
 set result=$&mlua.lua("string.lower('abc')",.output)
 if result'=0 zhalt 3
 if output'="" write "Error in print test: ",!,output,! zhalt 3
 set result=$&mlua.lua("print hello",.output)
 if result=0 zhalt 4
 if output'="Lua: [string ""mlua(code)""]:1: syntax error near 'hello'" zhalt 4
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
