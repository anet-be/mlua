; Benchmark comparison of SHA2 via M, Lua, and C

; Default function
%benchmark()
 do test() quit

; Wrap mlua.lua() so that it handles errors, else returns the result
lua(lua,data)
 new out
 if $data(data)=0 if $&mlua.lua(lua,.out) w out set $ecode=",U1,"
 if $data(data)'=0 if $&mlua.lua(lua,.out,,data) w out set $ecode=",U1,"
 quit:$quit out quit

; Detect whether lua module is installed from command line
detectLuaModule()
 new module
 set module=$piece($zcmdline," ",1)
 write $$lua("return pcall(require, '"_module_"')")
 quit

; Get random 1MB string from Lua so we can have a reproducable one (fixed seed)
; Lua is faster, anyway (see notes in randomMB.lua)
init()
 do lua(" rand=require'randomMB' ydb=require'yottadb' ydb.set('randomMB',rand.randomMB()) ")
 do lua(" cputime=require'cputime' ")
 do lua(" function start() start_child=cputime.get_children_process_cputime() start_time=cputime.get_process_cputime() end ")
 do lua(" function stop() r1=cputime.get_process_cputime()-start_time r2=cputime.get_children_process_cputime()-start_child return r1+r2 end ")
 quit

; Invoke test() from command line: test^%benchmark <command> <iterations> <hashSize>
test()
 new command,size,iterations,msg
 set command=$piece($zcmdline," ",1)
 set iterations=$piece($zcmdline," ",2)
 set size=$piece($zcmdline," ",3)

 do init()
 set msg=$extract(randomMB,1,size)
 set elapsed=$$@command^%benchmark(iterations)
 if $data(result)>0 if result'="" w result,!
 write elapsed
 quit


; ~~~ strStrip benchmarks

luaStripSetup()
 set chars=" "_$char(9,13,10,12,22)  ; example whitespace chars to strip
 set msg=" "_$extract(msg,1,$length(msg)-2)_" "  ; ensure whitespace either end to strip, just to make it a bit realistic
 ; setup lua
 do lua(" ydb=require'yottadb' chars=ydb.get('chars') match=string.match ")
 q

luaStripCharsDb(iterations)
 ; This uses one of the faster Lua string strip methods, trim7, taken from http://lua-users.org/wiki/StringTrim
 ; Note that chars must not have % in it as Lua interprets that specially. Substitute it with %%
 ; If you need to support %, create a macro to automatically substitute it with "%%" without creating overhead
 ; You can also use Lua to replace % as follows, but it adds about 10% overhead (for small msg strings)
 ;   "if string.find(chars, '%', 1, true) then chars=string.gsub(chars, '%%', '%%%%') end"
 new elapsed,i,stripped,chars
 d luaStripSetup()
 ; the first match below is a speedup to avoid very inefficient operation on strings where every character gets stripped
 do lua(" function func() s=ydb.get('msg') stripped=match(s,'^()['..chars..']*$') and '' or match(s,'^['..chars..']*(.*[^'..chars..'])') ydb.set('stripped', stripped) end ")

 do lua(">start")
 for i=1:1:iterations do
 . do lua(">func")
 set elapsed=$$lua(">stop")
 set result=$length(stripped)
 quit elapsed

luaStripCharsPrm(iterations)
 ; same as luaStripChrsDb() except passes/returns the string as function parameters rather than ydb.get/set -- see if it's faster
 new elapsed,i,stripped,chars
 d luaStripSetup()

 ; the first match below is a speedup to avoid very inefficient operation on strings where every character gets stripped
 do lua(" function func(s) return match(s,'^()['..chars..']*$') and '' or match(s,'^['..chars..']*(.*[^'..chars..'])') end ")

 do lua(">start")
 for i=1:1:iterations do
 . set stripped=$$lua(">func",msg)
 set elapsed=$$lua(">stop")
 set result=$length(stripped)
 quit elapsed


cmumpsStripChars(iterations)
 new elapsed,i,stripped,chars
 set chars=" "_$char(9,13,10,12,22)  ; example whitespace chars to strip
 set msg=" "_$extract(msg,1,$length(msg)-2)_" "  ; add whitespace either end to strip, just to make it a bit realistic

 do lua(">start")
 for i=1:1:iterations do
 . do &cstrlib.strip(.stripped,msg,chars)
 set elapsed=$$lua(">stop")
 set result=$length(stripped)
 quit elapsed

;$target=$$%Strip^bstrfmt(msg,chars)

; ~~~ SHA benchmarks

goSHA(iterations)
 new elapsed,i,RAinput,RAret
 do lua(">start")
 for i=1:1:iterations do
 . ; code below taken from Brocade m4_HSHA512
 . set RAinput(1)=msg d %Pipe(.RAret,"./brocr SHA512",.RAinput,$c(13,10),0)
 . set sha512=$g(RAret(1)),sha512=$p($p(sha512,"(",2),")")
 . set result=sha512
 set elapsed=$$lua(">stop")
 quit elapsed

cmumpsSHA(iterations)
 new elapsed,i
 do lua(">start")
 for i=1:1:iterations do
 . do &cstrlib.sha512(.sha512,msg)
 . set result=sha512
 set elapsed=$$lua(">stop")
 quit elapsed

pureluaSHA(iterations)
 new elapsed,i
 do lua(" ydb=require'yottadb' sha=require'sha2' ")
 do lua(" function func() return sha.sha512(ydb.get('msg')) end ")
 do lua(">start")
 for i=1:1:iterations do
 . set result=$$lua(">func")
 set elapsed=$$lua(">stop")
 quit elapsed

luaCLibSHA(iterations)
 new elapsed,i
 do lua(" ydb=require'yottadb' hmac=require'hmac' ")
 do lua(" function func() ctx=hmac.sha512() ctx:update(ydb.get('msg')) return ctx:final() end ")
 do lua(">start")
 for i=1:1:iterations do
 . set result=$$lua(">func")
 set elapsed=$$lua(">stop")
 quit elapsed


;%Pipe function to spawn a process from M -- used for goSHA
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
 .. u pipe w PAinput(ln),PDeol i PDdebug u $p w "writing to pipe ",PAinput(ln),!
 .. q
 . u pipe x "w /EOF" i PDdebug u $p
 . q
 i PDdebug u $p w !,"reading from pipe.."
 f i=1:1 u pipe r PAret(i):1 s zeof=$zeof q:zeof
 c pipe
 q
