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

mStripChars(iterations)
 new elapsed,i,stripped,chars
 set chars=" "_$char(9,13,10,12,22)  ; example whitespace chars to strip
 set msg=" "_$extract(msg,1,$length(msg)-2)_" "  ; add whitespace either end to strip, just to make it a bit realistic

 do lua(">start")
 for i=1:1:iterations do
 . set stripped=$$%Strip(msg,chars)
 set elapsed=$$lua(">stop")
 set result=$length(stripped)
 quit elapsed

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
 do lua(" function func(msg) return sha.sha512(msg) end ")
 do lua(">start")
 for i=1:1:iterations do
 . set result=$$lua(">func",msg)
 set elapsed=$$lua(">stop")
 quit elapsed

luaCLibSHA(iterations)
 new elapsed,i
 do lua(" ydb=require'yottadb' hmac=require'hmac' ")
 do lua(" function func(msg) ctx=hmac.sha512() ctx:update(msg) return ctx:final() end ")
 do lua(">start")
 for i=1:1:iterations do
 . set result=$$lua(">func",msg)
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
