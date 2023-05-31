; Benchmark comparison of SHA2 via M, Lua, and C

; Default function
benchmark()
 do init()
 ; if command line given, run only the specified functions
 if $zcmdline'="" w ! do  zhalt 0
 .new test
 .for test=1:1:$length($zcmdline," ") w $piece($zcmdline," ",test),":",! do @$piece($zcmdline," ",test)()
 ; otherwise run all benchmarks
 w ! do benchmarkNodeCreation()
 w ! do benchmarkTraverse()
 w ! do benchmarkSignals()
 w ! do benchmarkStringProcesses()
 quit

init(usertime)
 set hideProcess=$ztrnlnm("HIDE_PROCESS_TIME")'=""
 ; Create random 1MB string from Lua so we can have a reproducable one (fixed seed)
 ; Lua is faster, anyway (see notes in randomMB.lua)
 do lua(" ydb=require'yottadb' rand=require'randomMB' ")
 do lua(" function isfile(name) local f=io.open(name) return f ~= nil and io.close(f)  end ")
 ; the following time functions are unused since mlua introduced &mlua.nanoseconds(), but kept for posterity
 ;do lua(" cputime=require'cputime' ")
 ; time measurement options below: uptime() takes 2us but nanoseconds() takes 2000us! So use uptime().
 ;do lua(" proc_uptime=assert(io.open('/proc/uptime'), 'Can\'t open /proc/uptime') ")
 ;do lua(" function uptime()  proc_uptime:seek('set') proc_uptime:flush() return proc_uptime:read('*n') end ")
 ;do lua(" function nanoseconds()  local f=io.popen('date +%S.%N') local t=f:read('*n') f:close() return t end ")
 ; the following processtime measurements require Lua module lua-cputime v0.1.0-0: https://github.com/moznion/lua-cputime/tree/v0.1.0-0
 ;do lua(" function start() realtime=uptime()  start_child=cputime.get_children_process_cputime() start_time=cputime.get_process_cputime()  end ")
 ;do lua(" function stop() local cputime=cputime.get_process_cputime()-start_time+cputime.get_children_process_cputime()-start_child realtime=uptime()-realtime  return cputime  end ")
 set randomMB=$$lua(" return rand.randomMB() ")
 quit

benchmarkNodeCreation()
 new lua,iterations
 set iterations=50
 set lua="for i=1, "_iterations_" do  local n = ydb.node('a').b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z  end"
 do minIterate(100,"do &mlua.lua("""_lua_""")")
 w 26," Node creations in ",$select(hideProcess:"",1:$justify($fn(processtime/iterations,",",1),7)),$select(hideProcess:"",1:"us (process CPU time) "),$justify($fn(realtime/iterations,",",1),7),"us",$select(hideProcess:"",1:" (real time)"),!
 quit

benchmarkTraverse()
 do benchmarkLinear1()
 do benchmarkLinear2()
 do benchmarkTree()
 quit

benchmarkLinear1()
 do linearTraverse($name(^BCAT("lvd")),10000)
 do linearTraverse($name(LBCAT("lvd")),10000)
 quit

benchmarkLinear2()
 do linearTraverse($name(^var("this","is","a","fair","number","of","subscripts","on","a","glvn")),10000)
 do linearTraverse($name(lvar("this","is","a","fair","number","of","subscripts","on","a","glvn")),10000)
 quit

benchmarkTree()
 do treeTraverse("^tree",5,5)
 do treeTraverse("ltree",5,5)
 quit

linearTraverse(subs,records)
 ; Given subscripts list `sub`, create a counted table of `records` entries at that subscript
 new cnt,name,code,i
 for i=1:1:records do
 .set @subs@(i)=$random(2147483646)

 ; in M
 ; the following accesses @subs@(node) but using faster direct access: ^BCAT("lvd",node)
 ; for this to work, we must pass iterate() the full inline code to run rather than calling mLinear()
 set name=$extract(subs,1,$length(subs)-1)_",node)"
 set code="new node set node="""",cnt=0 for  set node=$order("_name_") quit:node=""""  set cnt=cnt+1"
 do minIterate(10,code)
 do assert(cnt,records,"Not all records iterated")
 w "M   ",subs," traversal of ",cnt," subscripts in ",$select(hideProcess:"",1:$justify($fn(processtime/1000,",",1),7)),$select(hideProcess:"",1:"ms (process CPU time) "),$justify($fn(realtime/1000,",",1),7),"ms",$select(hideProcess:"",1:" (real time)"),!

 ; names in Lua
 set code="set cnt=$$lua(""local cnt,n = 0,ydb.node("_$$subs2lua(subs)_") for x in n:subscripts() do cnt=cnt+1 end return cnt"")"
 do minIterate(10,code)
 w "Lua ",subs," traversal of ",cnt," subscripts in ",$select(hideProcess:"",1:$justify($fn(processtime/1000,",",1),7)),$select(hideProcess:"",1:"ms (process CPU time) "),$justify($fn(realtime/1000,",",1),7),"ms",$select(hideProcess:"",1:" (real time)"),!

 ; nodes in Lua
 set code="set cnt=$$lua(""local cnt,n = 0,ydb.node("_$$subs2lua(subs)_") for k,v in pairs(n) do cnt=cnt+1 end return cnt"")"
 do minIterate(10,code)  ;don't do so many iterations because this one is slow
 w "Lua ",subs," traversal of ",cnt," node objs  in ",$select(hideProcess:"",1:$justify($fn(processtime/1000,",",1),7)),$select(hideProcess:"",1:"ms (process CPU time) "),$justify($fn(realtime/1000,",",1),7),"ms",$select(hideProcess:"",1:" (real time)"),!
 quit

treeTraverse(subs,length,depth)
 ; Given subscript `sub`, create a tree of `length` times `depth` entries at that subscript
 new cnt,name,code
 do makeTree(subs,length,depth,0)

 ; in M
 do minIterate(10,"set cnt=$$mTraverse(subs)")
 w "M   ",subs," traversal of ",cnt," records in ",$select(hideProcess:"",1:$justify($fn(processtime/1000,",",1),7)),$select(hideProcess:"",1:"ms (process CPU time) "),$justify($fn(realtime/1000,",",1),7),"ms",$select(hideProcess:"",1:" (real time)"),!

 ; in Lua
 do assert($$lua("return ydb._VERSION")>=1.2,1,"lua_yottadb version must be >=1.2 to run the Lua tree iteration test")
 do lua(" node=ydb.node("_$$subs2lua(subs)_") ")
 do lua(" function counter(node, sub, val)  cnt=cnt+(val and 1 or 0)  end ")
 do minIterate(10,"set cnt=$$lua(""cnt=0 node:gettree(nil,counter) return cnt"")")
 w "Lua ",subs," traversal of ",cnt," records in ",$select(hideProcess:"",1:$justify($fn(processtime/1000,",",1),7)),$select(hideProcess:"",1:"ms (process CPU time) "),$justify($fn(realtime/1000,",",1),7),"ms",$select(hideProcess:"",1:" (real time)"),!
 quit

subs2lua(subs)
 ; Given subscript list "^varname(a,b)" convert it to lua-compatible subscript format "'^varname','a','b'"
 new name
 set name=$translate(subs,"""()","',")
 set $piece(name,",",1)="'"_$piece(name,",",1)_"'"
 quit name

mTraverse(subs)
 new node,cnt
 set node="",cnt=0
 for  set node=$order(@subs@(node)) quit:node=""  do
 .set cnt=cnt+1
 .quit:$data(@subs@(node))<10
 .set cnt=cnt+$$mTraverse($name(@subs@(node)))
 quit cnt

makeTree(subs,length,depth,value)
 ;given subscript `sub`, recursively create a tree of `records` entries at that subscript, each with `records` depth
 new i
 for i=1:1:length do
 .set @subs@(i)=value+i
 .if depth>1 do makeTree($name(@subs@(i)),length,depth-1,(value+i)*10)
 quit

assert(str1,str2,msg)
 ; Assert both parameters are equal
 new line
 set msg=$select($data(msg)=0:"",1:msg_"; ")
 set line=$stack($stack(-1)-1,"PLACE")
 if str1'=str2 write "  Failed ("_line_"): "_msg_"'",str1,"' <> '",str2,"'",! zmessage -1
 quit

; ~~~ Signal calling overhead benchmarks

benchmarkSignals()
 new iterations,processtime,realtime
 set iterations=100000
 do sleep(4)  ; to get consistent results, need time after previous CPU-intensive process
 set processtime=$$iterateCall(iterations,0,.realtime)
 w "MLua calling overhead without signal blocking: ",$select(hideProcess:"",1:$justify($fn(processtime,",",1),7)),$select(hideProcess:"",1:"us (process CPU time) "),$justify($fn(realtime,",",1),7),"us",$select(hideProcess:"",1:" (real time)"),!
 set processtime=$$iterateCall(iterations,$&mlua.open(.o,4),.realtime)
 w "MLua calling overhead with    signal blocking: ",$select(hideProcess:"",1:$justify($fn(processtime,",",1),7)),$select(hideProcess:"",1:"us (process CPU time) "),$justify($fn(realtime,",",1),7),"us",$select(hideProcess:"",1:" (real time)"),!
 quit

iterateCall(iterations,luaHandle,realtime)
 new processtime
 do iterate(iterations,"do &mlua.lua("">math.abs"",.o,luaHandle,-1)")
 quit processtime


benchmarkStringProcesses()
 new expect10,expect1k,expect1m
 w "Strings of size:",?21,$justify("10B",11),"   ",$justify("1kB",11),"   ",$justify("1mB",11),!

 set expect10="8772d22407ac282809a75706f91fab898adea0235f1d304d85c1c48650c283413e533eba63880c51be67e35dfc3433ddbe78e73d459511aaf29251a64a803884"
 set expect1k="7319dbae7e935f940b140f8b9d8e4d5e2509d634fb67041d8828833dcf857cfecda45282b54c0a77e2875185381d95791594dbf1a0f3db5cae71d95617287c18"
 set expect1m="7a0712c75269ad5fbf829e04f116701899bcbefc5f07e4610fbaddf493ee2b917f84f1f0107f0ee95b420efc3c4cd6b687ee944a52351fc0c52eba260b11bed6"
 if '$$lua("return isfile('brocr')") w "Skipping uninstalled shellSHA. To install, run: make anet-benchmarks",!
 else  do benchmarkSizes("shellSHA",200,200,1,expect10,expect1k,expect1m)
 do benchmarkSizes("pureluaSHA",10000,2000,2,expect10,expect1k,expect1m)
 if '$$lua("return pcall(require,'hmac')") w "Skipping uninstalled luaCLibSHA. To install, run: luarocks install hmac",!
 else  do benchmarkSizes("luaCLibSHA",200000,100000,100,expect10,expect1k,expect1m)
 if '$$lua("return isfile('cstrlib.so')") w "Skipping uninstalled cmumpsSHA. To install, run: make anet-benchmarks",!
 else  do benchmarkSizes("cmumpsSHA",100000,100000,100,expect10,expect1k,expect1m)

 set expect10=8
 set expect1k=998
 set expect1m=999998
 do benchmarkSizes("luaStripCharsPrm",20000,10000,10,expect10,expect1k,expect1m)
 do benchmarkSizes("luaStripCharsDb",10000,5000,10,expect10,expect1k,expect1m)
 if '$$lua("return isfile('cstrlib.so')") w "Skipping uninstalled cmumpsStripChars. To install, run: make anet-benchmarks",!
 else  do benchmarkSizes("cmumpsStripChars",100000,1000,10,expect10,expect1k,expect1m)
 do benchmarkSizes("mStripChars",10000,2000,10,expect10,expect1k,expect1m)
 quit

benchmarkSizes(testName,iterations10,iterations1k,iterations1m,expect10,expect1k,expect1m)
 ; Benchmark `testName` using various string sizes
 new us10,us1k,us1m
 new rt10,rt1k,rt1m
 w testName,?19
 set us10=$$test(testName,10,iterations10,expect10,.rt10)
 if 'hideProcess w $justify($fn(us10,",",1),11),"us "
 set us1k=$$test(testName,1000,iterations1k,expect1k,.rt1k)
 if 'hideProcess w $justify($fn(us1k,",",1),11),"us "
 set us1m=$$test(testName,1000000,iterations1m,expect1m,.rt1m)
 if 'hideProcess w $justify($fn(us1m,",",1),11),"us   (process CPU time)",!
 w ?19,$justify($fn(rt10,",",1),11),"us ",$justify($fn(rt1k,",",1),11),"us ",$justify($fn(rt1m,",",1),11),"us",$select(hideProcess:"",1:"   (real time)"),!
 quit

lua(lua,a1,a2,a3,a4,a5,a6,a7,a8)
 ; Wrap mlua.lua() so that it handles errors; otherwise returns the output
 ; Handles up to 8 params, which matches mlua.xc
 new o,result
 ;w "LUA: ",lua,"(",$s($d(a1)=0:"",1:a1_","),$s($d(a1)=0:"",1:a1_","),$s($d(a2)=0:"",1:a2_","),$s($d(a3)=0:"",1:a3_","),$s($d(a4)=0:"",1:a4_","),$s($d(a5)=0:"",1:a5_","),$s($d(a6)=0:"",1:a6_","),$s($d(a7)=0:"",1:a7_","),$s($d(a8)=0:"",1:a8),!
 set result=$select($data(a1)=0:$&mlua.lua(lua,.o),$data(a2)=0:$&mlua.lua(lua,.o,,a1),$data(a3)=0:$&mlua.lua(lua,.o,,a1,a2),$data(a4)=0:$&mlua.lua(lua,.o,,a1,a2,a3),$data(a5)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4),$data(a6)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5),$data(a7)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6),$data(a8)=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6,a7),0=0:$&mlua.lua(lua,.o,,a1,a2,a3,a4,a5,a6,a7,a8))
 if result write o,! set $ecode=",U1,MLua,"
 quit:$quit o quit

test(command,size,iterations,expected,realtime)
 ; Invoke test `command` with random string of `size`, setting realtime to the time taken
 ; Check that returned result equals expected
 ; return elapsed processtime
 new msg
 set msg=$extract(randomMB,1,size)
 kill result
 do @command^benchmark(iterations)
 do assert(result,expected)
 quit processtime

; Sleep to let CPU clear its cache, etc., after previous benchmark
sleep(seconds)
 zsystem "sleep "_seconds
 quit

; Microsecond timer functions
start()
 set realtime=$&mlua.nanoseconds(0)
 set processtime=$&mlua.nanoseconds(1)
 quit
stop()
 set realtime=($&mlua.nanoseconds(0)-realtime)/1000  ; convert nanoseconds to microseconds
 set processtime=($&mlua.nanoseconds(1)-processtime)/1000  ; convert nanoseconds to microseconds
 quit:$quit processtime quit

iterate(iterations,code)
 ; Run code `iterations` times
 ; returns elapsed CPU processtime and realtime in globals `processtime` and `realtime`
 new i
 ; include timer start() in compiled code to ensure we're not counting compile time
 ; invoke lua directly rather than through $$lua() to avoid $$lua() M subroutine overhead
 xecute "do start() for i=1:1:iterations "_code
 do stop()
 set processtime=processtime/iterations
 set realtime=realtime/iterations
 quit

minIterate(iterations,code)
 ; Run code `iterations` times, timing each iteration and return the minimum time measured
 ; returns elapsed CPU processtime and realtime in globals `processtime` and `realtime`
 new i,minProcesstime,minRealtime
 set minProcesstime=1E18,minRealtime=1E18  ;start with largest possible value
 for i=1:1:iterations do
 .;include timer start() in compiled code to ensure we're not counting compile time
 .;invoke lua directly rather than through $$lua() to avoid $$lua() M subroutine overhead
 .xecute "do start() "_code
 .do stop()
 .if processtime<minProcesstime set minProcesstime=processtime
 .if realtime<minRealtime set minRealtime=realtime
 ;return the minimums
 set processtime=minProcesstime
 set realtime=minRealtime
 quit

; ~~~ strStrip benchmarks

stripSetup()
 set chars=" "_$char(9,13,10,12,22)  ; example whitespace chars to strip
 set msg=" "_$extract(msg,1,$length(msg)-2)_" "  ; ensure whitespace either end to strip, just to make it a bit realistic
 ; setup lua
 do lua(" chars=ydb.get('chars') match=string.match ")
 quit

luaStripCharsDb(iterations)
 ; This uses one of the faster Lua string strip methods, trim7, taken from http://lua-users.org/wiki/StringTrim
 ; Note that chars must not have % in it as Lua interprets that specially. Substitute it with %%
 ; If you need to support %, create a macro to automatically substitute it with "%%" without creating overhead
 ; You can also use Lua to replace % as follows, but it adds about 10% overhead (for small msg strings)
 ;   "if string.find(chars, '%', 1, true) then chars=string.gsub(chars, '%%', '%%%%') end"
 new stripped,chars
 do stripSetup()
 ; the first match below is a speedup to avoid very inefficient operation on strings where every character gets stripped
 do lua(" function func() s=ydb.get('msg') stripped=match(s,'^()['..chars..']*$') and '' or match(s,'^['..chars..']*(.*[^'..chars..'])') ydb.set('stripped', stripped) end ")
 do iterate(iterations,"do &mlua.lua("">func"")")
 set result=$length(stripped)
 quit

luaStripCharsPrm(iterations)
 ; same as luaStripChrsDb() except passes/returns the string as function parameters rather than ydb.get/set -- see if it's faster
 new stripped,chars
 do stripSetup()

 ; the first match below is a speedup to avoid very inefficient operation on strings where every character gets stripped
 do lua(" function func(s) return match(s,'^()['..chars..']*$') and '' or match(s,'^['..chars..']*(.*[^'..chars..'])') end ")
 do iterate(iterations,"do &mlua.lua("">func"",.stripped,0,msg)")
 set result=$length(stripped)
 quit

cmumpsStripChars(iterations)
 new stripped,chars
 do stripSetup()
 do iterate(iterations,"do &cstrlib.strip(.stripped,msg,chars)")
 set result=$length(stripped)
 quit

mStripChars(iterations)
 new stripped,chars
 do stripSetup()
 do iterate(iterations,"set stripped=$$%Strip(msg,chars)")
 set result=$length(stripped)
 quit

%Strip(PDs,PDchars)
 n i,j,ch,y,stop,from,to,ZAchar
 n ASCII,ASCIIE
 s ASCII=$C(32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126)
 s ASCIIE=$C(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255)
 s bytesUTF8types="LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEELLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLEEEEEEEEEEE"
 s:PDchars="" PDchars=$C(9,10,11,12,13,32)
 ; we nemen dit eerst, omdat dit de meest voorkomende situatie is
 i $tr(PDchars,ASCII)="" d  q $E(PDs,i,j)
 . f i=1:1 s ch=$E(PDs,i) q:ch=""  q:PDchars'[ch
 . f j=$L(PDs):-1:1 s ch=$E(PDs,j) q:ch=""  q:PDchars'[ch
 . q
 ;splits PDchars in ZAchar(char)=""
 ;m4_strSplitChars(ZAchar,PDchars,seq=0)
 k ZAchar s MDchri=1,MDchry=$tr(PDchars,ASCIIE,bytesUTF8types) f  s MDchrf=$f(MDchry,"L",MDchri) s:MDchrf>2!'MDchrf ZAchar($e(PDchars,MDchri-1,$s(MDchrf:MDchrf-2,1:$l(PDchars))))="" q:'MDchrf  s MDchri=MDchrf
 s y=$tr(PDs,ASCIIE,bytesUTF8types)
 s from=1 f  d  q:stop
 . ; neem het eerste karakter
 . s stop=1,ch=$e(PDs,$l($p(y,"L",1,from))+1,$l($p(y,"L",1,from+1)))
 . q:ch=""
 . q:'$d(ZAchar(ch))
 . s from=from+1,stop=0
 . q
 ;R
 s to=$l(y,"L")-1
 f  d  q:stop
 . s stop=1,ch=$e(PDs,$l($p(y,"L",1,to))+1,$l($p(y,"L",1,to+1)))
 . ;neem laatste karakter
 . q:ch=""
 . q:'$d(ZAchar(ch))
 . s to=to-1
 . q:to=1
 . s stop=0
 . q
 q $e(PDs,from,$l($p(y,"L",1,to+1)))


; ~~~ SHA benchmarks

shellSHA(iterations)
 new RAinput,RAret,sha512
 do iterate(iterations,"set result=$$m4ShellSHA()")
 quit

m4ShellSHA()
 ; code below taken from Brocade m4_HSHA512
 set RAinput(1)=msg d %Pipe(.RAret,"./brocr SHA512",.RAinput,$c(13,10),0)
 set sha512=$g(RAret(1)),sha512=$p($p(sha512,"(",2),")")
 quit sha512

cmumpsSHA(iterations)
 do iterate(iterations,"do &cstrlib.sha512(.result,msg)")
 quit

pureluaSHA(iterations)
 do lua(" sha=require'sha2' function func(msg) return sha.sha512(msg) end ")
 do iterate(iterations,"do &mlua.lua("">func"",.result,0,msg)")
 quit

luaCLibSHA(iterations)
 do lua(" hmac=require'hmac' function func(msg) ctx=hmac.sha512() ctx:update(msg) return ctx:final() end ")
 do iterate(iterations,"do &mlua.lua("">func"",.result,0,msg)")
 quit


;%Pipe function to spawn a process from M -- used for shellSHA
;Copy catch macro here as documentation of parameters for %Pipe below
;macro catch($ret, $cmd, $input=0, $eol=«$c(13,10)», $debug=0):
;    $synopsis: launch an external process, and capture the output
;    $ret: the name of the array, which contains the output in the right hand side
;    $cmd: the action to be performed. This can contain spaces and arguments.
;    $input: Optional. Array, which contains the stdinput in the right-hand side
;    $eol: Optional. The end-of-line delimiter of the input.
;    $debug: Shows extra info during communication
;    $example: m4_catch(RAret,"ls")
;    $example: m4_catch(RAret,"ls /library/process")
;    $example: k RAinput s RAinput(1)="test one",RAinput(2)="test two" m4_catch(RAret,"grep two",RAinput)
;    '''
;    «d %Pipe^uosr4_m_os_type(.$ret,$cmd,,$eol,$debug)»
;        if «$input isEqualTo "0"»
;    «d %Pipe^uosr4_m_os_type(.$ret,$cmd,.$input,$eol,$debug)»
;
; Make a system call. Parameters documented in m4_catch() macro above
%Pipe(PAret,PDcmd,PAinput,PDeol,PDdebug)
 n x,y,z,i,ln,pipe,zeof
 ;vb : d %Pipe^uosgtm(.RAret,"ls")
 k PAret
 s PDdebug=+$g(PDdebug)
 s pipe="Pipe"
 o pipe:(command=PDcmd):"":"PIPE"
 i $d(PAinput)>1 d
 . s ln=""
 . f  s ln=$o(PAinput(ln)) q:ln=""  d
 .. u pipe f i=1:32000:$l(PAinput(ln)) w $e(PAinput(ln),i,i+32000-1) s $x=0
 .. u pipe w PDeol i PDdebug u $p w "writing to pipe ",PAinput(ln),!
 .. q
 . u pipe x "w /EOF" i PDdebug u $p
 . q
 i PDdebug u $p w !,"reading from pipe.."
 f i=1:1 u pipe r PAret(i):1 s zeof=$zeof q:zeof
 c pipe
 q
