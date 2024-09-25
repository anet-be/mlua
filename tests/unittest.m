;Test functions for MLua

;Invoke run() from command line: run^unittest <commands>
run()
 new allTests
 set allTests="testBasics testParameters testReadme testTreeHeight testLuaStates testInit testSignals"
 if $zcmdline'="" set allTests=$zcmdline
 w "Testing: ",allTests,!
 do test(allTests)
 quit

;Invoke with list of tests separated by spaces
test(testList)
 new command
 set luaVersion=$$lua("return _VERSION")
 set luayottadbVersion=$$lua("ydb = require 'yottadb' return ydb._VERSION")
 do assertFatal(""=luaVersion,0,"Lua returned nothing for global _VERSION!")
 set luaVersion=$piece(luaVersion," ",2)
 w "MLua is built using Lua ",luaVersion,!
 do assert(1,luaVersion>=5.1,"luaVersion is <5.1")
 set failures=0,tests=0,skipped=0
 for i=1:1:$length(testList," ") do
 .set fail=0
 .set tests=tests+1
 .set command=$piece(testList," ",i)
 .do
 ..new $etrap,error
 ..set $etrap="set error=$ecode  if error["",M13,Z150373194,"" set skipped=skipped+1,$ecode="""""  ; ignore invalid tests names
 ..new (command,fail,skipped,luaVersion,luayottadbVersion)  ;delete all unnecessary locals before each test
 ..w command,!
 ..do assert(0,$&mlua.close())  ;close all Lua states to make sure every test starts fresh
 ..do lua("ydb = require 'yottadb'")
 ..do @command^unittest()
 .set failures=failures+fail
 if skipped>0 write skipped,"/",tests," tests UNDEFINED; ",failures," FAILED",!
 else  if failures=0 write tests,"/",tests," tests PASSED!",!
 else  write failures,"/",tests," tests FAILED!",! zhalt 1
 quit

; Wrap mlua.lua() so that it handles errors; otherwise returns the output
; Handles up to 8 params, which matches mlua.xc
lua(lua,a1,a2,a3,a4,a5,a6,a7,a8)
 new o,result,line
 set result=$select($data(a1)=0:$&mlua.lua(lua,.o),$data(a2)=0:$&mlua.lua(lua,.o,,a1),$data(a3)=0:$&mlua.lua(lua,.o,,a1,a2),$data(a4)=0:$&mlua.lua(lua,.o,,a1,a2,a3),$data(a5)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4),$data(a6)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5),$data(a7)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6),$data(a8)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6,a7),1:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6,a7,a8))
 if result do
 .new line
 .set line=$stack($stack(-1)-1,"PLACE")
 .write "  Failed ("_line_"): "_o,!
 .set fail=1
 quit:$quit o quit

; Assert both parameters are equal
assert(str1,str2,msg)
 new line
 set msg=$select($data(msg)=0:"",1:msg_"; ")
 set line=$stack($stack(-1)-1,"PLACE")
 if str1'=str2 write "  Failed ("_line_"): "_msg_"'",str1,"' <> '",str2,"'",! set fail=1
 quit

; Assert both parameters are notequal
assertNot(str1,str2,msg)
 new line
 set msg=$select($data(msg)=0:"",1:msg_"; ")
 set line=$stack($stack(-1)-1,"PLACE")
 if str1=str2 write "  Failed ("_line_"): "_msg_"'",str1,"' = '",str2,"'",! set fail=1
 quit

; Assert both parameters are equal
assertFatal(str1,str2,msg)
 new line
 set msg=$select($data(msg)=0:"",1:msg_"; ")
 set line=$stack($stack(-1)-1,"PLACE")
 if str1'=str2 write "  Failed ("_line_"): "_msg_"'",str1,"' <> '",str2,"'",! set fail=1
 if str1'=str2 zhalt 2
 quit


;---- Actual tests from here on ----

testBasics()
 ;Run some very basic invokation tests first (string.lower() is used as a noop)
 new output,result,expected
 ;test output-less command works in a fresh lua_State -- in the past this has been a known failure point
 do assert(0,$&mlua.close())
 do &mlua.lua("string.lower('abc')")
 do assert(0,$&mlua.close())
 do assert(0,$&mlua.lua("string.lower('abc')"))
 ; same tests in an already-open lua_State
 do &mlua.lua("string.lower('abc')")
 do assert(0,$&mlua.lua("string.lower('abc')"))
 do assert(0,$&mlua.lua("string.lower('abc')",.output))
 do assert("",output)
 do assertNot(0,$&mlua.lua("print hello",.output))
 set expected=$select(luaVersion>5.1:"Lua: [string ""mlua(code)""]:1: syntax error near 'hello'",1:"Lua: [string ""mlua(code)""]:1: '=' expected near 'hello'")
 do assert(expected,output)
 do assertNot(0,$&mlua.lua("junk",.output))
 set expected=$select(luaVersion>5.1:"Lua: [string ""mlua(code)""]:1: syntax error near <eof>",1:"Lua: [string ""mlua(code)""]:1: '=' expected near '<eof>'")
 do assert(expected,output)
 do assert("",$$lua(""))
 do assertNot(0,$&mlua.lua(">",.output))
 do assert("Lua: could not find function ''",output)
 do assertNot(0,$&mlua.lua(">unknown_func",.output))
 do assert("Lua: could not find function 'unknown_func'",output)
 quit

;test mlua invokation using 1 to 9 arguments (9 should fail)
testParameters()
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

;test the basic code from the README.md
testReadme()
 new hello,expected
 set hello="Hello World!"
 do assert("table",$$lua("ydb = require 'yottadb' return type(ydb)"))
 do assert(hello,$$lua("return ydb.get('hello')"))
 do assert("params: 1 2",$$lua("return 'params: '..table.concat({...},' ')",1,2))
 do assert("",$$lua("function add(a,b) return a+b end"))

 ;Lua 5.3 adds strings representing integers to produce a float:
 set expected=$select(luaVersion=5.3:"7.0",1:7)
 do assert(expected,$$lua(">add",3,4))
 quit

;test the 'practical' example code from the README.md
testTreeHeight()
 new expected,expectedHeight
 set ^oaks(1,"shadow")=10,^("angle")=30
 set ^oaks(2,"shadow")=13,^("angle")=30
 set ^oaks(3,"shadow")=15,^("angle")=45

 set expected="^oaks(1,'angle')=30$^oaks(1,'shadow')=10$^oaks(2,'angle')=30$^oaks(2,'shadow')=13$^oaks(3,'angle')=45$^oaks(3,'shadow')=15"
 if luayottadbVersion>=3 set expected="^oaks$"_expected  ; Account for lua-yottadb version>3 dump prints varname first
 set expected=$translate(expected,"'$",$C(34)_$C(10)) ;convert ' to ", and $ to newline
 do assert(expected,$$lua("return ydb.dump('^oaks')"))
 do lua("dofile 'tree_height.lua'")
 do lua("calc_height( ydb.node('^oaks') )")
 ;Lua <5.3 displays height float 15.0 as 15:
 set expectedHeight=$select(luaVersion<5.3:"15",1:"15.0")
 set expected="^oaks(1,'angle')=30$^oaks(1,'height')=5.7735026918963$^oaks(1,'shadow')=10$^oaks(2,'angle')=30$^oaks(2,'height')=7.5055534994651$^oaks(2,'shadow')=13$^oaks(3,'angle')=45$^oaks(3,'height')="_expectedHeight_"$^oaks(3,'shadow')=15"
 if luayottadbVersion>=3 set expected="^oaks$"_expected  ; Account for lua-yottadb version>3 dump prints varname first
 set expected=$translate(expected,"'$",$C(34)_$C(10)) ;convert ' to ", and $ to newline
 do assert(expected,$$lua("return ydb.dump('^oaks')"))
 quit

;Test internal implementation details of mlua.c
testLuaStates()
 new newState,output

 ;Check that Lua handles are released in sequence
 for i=1:1:12 do
 .do assert(i,$&mlua.open())

 ;Check that if handles are freed, the handle_array shrinks to hold only the highest used one
 for i=5:1:12 do
 .do assert(0,$&mlua.close(i))
 do assert(5,$&mlua.open())

 ;Check that mlua.close() closes all states
 do assert(0,$&mlua.close())
 do assert(1,$&mlua.open())

 ;Check that globals are distinct between Lua states
 do lua("test=3")
 do assert("3",$$lua("return test"))
 set newState=$&mlua.open()
 do &mlua.lua("return test",.output,newState)
 do assert("",output)
 do assert("3",$$lua("return test"))

 ;Check that mlua.close() also closes default state
 do assert(0,$&mlua.close())
 do assert("",$$lua("return test"))

 ;Check expected failures if I supply an invalid state handle
 do assert(0,$&mlua.close())  ;close all to start things off
 do assert("",$$lua(""))  ;open default handle
 do assert(1,$&mlua.open())  ;open handle 1
 do assert(0,$&mlua.close(0))
 do assert(-2,$&mlua.close(0))  ;handle already cosed
 do assert(-1,$&mlua.close(100))  ;handle invalid
 do assert(-1,$&mlua.close(2))  ; handle invalid

 do assertNot(0,$&mlua.lua("return test",.output,2))
 do assert("MLua: supplied luaState (2) is invalid",output)
 do assertNot(0,$&mlua.lua("return test",.output,100))
 do assert("MLua: supplied luaState (100) is invalid",output)
 do assertNot(0,$&mlua.lua("return test",.output,-1))
 do assert("MLua: supplied luaState (-1) is invalid",output)
 quit

testInit()
 new newState,output

 ;inittest is set by MLUA_INIT for this test
 do assert("1",$$lua("return inittest"))

 ;test that MLUA_INIT does not run if we use the MLUA_IGNORE_INIT flag
 set newState=$&mlua.open(,1)
 do &mlua.lua("return inittest",.output,newState)
 do assert("",output)
 quit

;Test whether signals can interrupt Lua code
testSignals()
 new pid,cmd1,cmd2,signal,captureFunc,handle,output,MluaBlockSignals
 set pid=$$lua("local f=assert(io.open('/proc/self/stat'), 'Cannot open /proc/self/stat') local pid=assert(f:read('*n'), 'Cannot read PID from /proc/self/stat') f:close() return pid")
 set captureFunc="function capture(cmd) local f=assert(io.popen(cmd)) local s=assert(f:read('*a')) f:close() return s end"
 set cmd1="kill -s CONT "_pid_" && sleep 0.1 && echo -n Complete 2>/dev/null"
 set cmd2="kill -s ALRM "_pid_" && sleep 0.1 && echo -n Complete 2>/dev/null"

 ;first send ourselves a signal while Lua is doing slow IO
 ;make sure Lua returns early without MLUA_BLOCK_SIGNALS flag
 set handle=0
 do assert(0,$&mlua.lua(captureFunc,.output,handle))
 do assert("",output)
 do assertNot(0,$&mlua.lua("return capture('"_cmd1_"')",.output,handle))
 do assert("Lua: [string ""mlua(code)""]:1: Interrupted system call",output)
 ;do the same again with SIGALRM
 do assertNot(0,$&mlua.lua("return capture('"_cmd2_"')",.output,handle))
 do assert("Lua: [string ""mlua(code)""]:1: Interrupted system call",output)

 ;now do the same in a new lua state with MLUA_BLOCK_SIGNALS flag set
 ;it should complete the whole task properly
 set MluaBlockSignals=4  ;from mlua.h
 set handle=$&mlua.open(.output,MluaBlockSignals)
 do assert(0,$&mlua.lua(captureFunc,.output,handle))
 do assert("",output)
 do assert(0,$&mlua.lua("return capture('"_cmd1_"')",.output,handle))
 do assert("Complete",output)
 ;do the same again with SIGALRM
 do assert(0,$&mlua.lua("return capture('"_cmd2_"')",.output,handle))
 do assert("Complete",output)
 quit
