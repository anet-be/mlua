; Benchmark comparison of SHA2 via M, MLua, and C

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
 quit

cmumpsSHA()
 new i
 for i=1:1:iterations do
 . set result=$$%HSHA512(msg,1)
 quit

goSHA()
 new i
 for i=1:1:iterations do
 . set result=$$%HSHA512(msg,0)
 quit

cmumpsSHANoWrapper()
 new i
 for i=1:1:iterations do
 . do &cstrlib.sha512(.sha512,msg)
 . set result=sha512
 quit

luaSHA()
 new lua,i
 do lua(" ydb=require'yottadb' sha=require'sha2' ")
 for i=1:1:iterations do
 . set result=$$lua(" return sha.sha512(ydb.get('msg')) ")
 quit


; invoke from command line: test^%benchmark <command> <iterations> <hashSize>
test()
 new command,size,iterations,msg
 set command=$piece($zcmdline," ",1)
 set iterations=$piece($zcmdline," ",2)
 set size=$piece($zcmdline," ",3)

 do init()
 set msg=$extract(randomMB,1,size)
 xecute "do "_command_"()"
 quit



; ~~~ Code converted from m4_SHA512 macro to normal M code

; perform equivalent of the m4_SHA512 macro for comparison purposes, without having to actually use m4
; PDmessage: the string to encode
; PDclib: 1/0 Use faster C libraries:
;           1 = use C libraries, if available
;           0 = only use the M-ISO standard implementation
%HSHA512(PDmessage,PDclib)
 n sha512,RAinput,RAret,x
 d getMumpsType(.x)
 s PDclib=$g(PDclib,1)
 i x="CACHE" d  q sha512
 . ;pragma set sha512
 . x "s sha512=##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHAHash(512,$zcvt(PDmessage,""O"",""UTF8"")))"
 . s sha512=$tr(sha512,m4_UP,m4_LO)
 . q
 i x="GT.M" i PDclib=1 d &cstrlib.sha512(.sha512,.PDmessage) q sha512
 s RAinput(1)=PDmessage d %Pipe(.RAret,"./brocr SHA512",.RAinput,$c(13,10),0)
 s sha512=$g(RAret(1)),sha512=$p($p(sha512,"(",2),")")
 q sha512

getMumpsType(type)
 s type=$zv s type=$s(type["Cache":"CACHE",type["IRIS":"CACHE",type["ISM":"ISM",1:$p(type," "))
 q


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
