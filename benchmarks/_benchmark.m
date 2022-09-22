; Benchmark comparison of SHA2 via M, Lua, and C

%benchmark()
 do test() quit

;wrap mlua.lua() so that it handles errors, else returns the result
lua(lua)
 new out
 if $&mlua.lua(lua,.out) w out set $ecode=",U1,"
 quit:$quit out quit

init()
 ; get random 1MB string from Lua so we can have a reproducable one (fixed seed)
 ; Lua is faster, anyway (see notes in randomMB.lua)
 do lua(" rand=require'randomMB' ydb=require'yottadb' ydb.set('randomMB',rand.randomMB()) ")
 do lua(" cputime=require'cputime' ")
 do lua(" function start() start_child=cputime.get_children_process_cputime() start_time=cputime.get_process_cputime() end ")
 do lua(" function stop() r1=cputime.get_process_cputime()-start_time r2=cputime.get_children_process_cputime()-start_child return r1+r2 end ")
 quit

goSHA()
 new i,RAinput,RAret
 do lua(">start")
 for i=1:1:iterations do
 . ; code below taken from Brocade m4_HSHA512
 . set RAinput(1)=msg d %Pipe(.RAret,"./brocr SHA512",.RAinput,$c(13,10),0)
 . set sha512=$g(RAret(1)),sha512=$p($p(sha512,"(",2),")")
 . set result=sha512
 set elapsed=$$lua(">stop")
 quit elapsed

cmumpsSHA()
 new i
 do lua(">start")
 for i=1:1:iterations do
 . do &cstrlib.sha512(.sha512,msg)
 . set result=sha512
 set elapsed=$$lua(">stop")
 quit elapsed

luaSHA()
 new lua,i
 do lua(" ydb=require'yottadb' sha=require'sha2' function func() return sha.sha512(ydb.get('msg')) end ")
 do lua(">start")
 for i=1:1:iterations do
 . set result=$$lua(">func")
 set elapsed=$$lua(">stop")
 quit elapsed

; invoke from command line: test^%benchmark <command> <iterations> <hashSize>
test()
 new command,size,iterations,msg
 set command=$piece($zcmdline," ",1)
 set iterations=$piece($zcmdline," ",2)
 set size=$piece($zcmdline," ",3)

 do init()
 set msg=$extract(randomMB,1,size)
 s elapsed=$$@command
 w elapsed/iterations_" "_elapsed_" ",!
 ;w !,result
 w elapsed
 quit


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
