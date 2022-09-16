; Benchmark comparison of SHA2 via M, MLua, and C

%benchmark()
 do test() quit

cmumpsHash(glvn)
 quit $$%HSHA512(glvn,1)

;wrap mlua.lua() so that it handles errors, else returns the result
lua(lua)
 new out
 if $&mlua.lua(lua,.out) w out set $ecode=",U1,"
 quit:$quit out quit

init()
 ; get random 1MB string from Lua so we can have a reproducable one (fixed seed)
 ; Lua is faster, anyway (see notes in randomMB.lua)
 new lua,out
 do lua(" rand=require'randomMB' ydb=require'yottadb' ydb.set('randomMB',rand.randomMB()) ")
 quit

cmumpsSHA()
 for i=1:1:iterations do
 . set result=$$cmumpsHash(msg)
 quit

luaSHA()
 new lua,out,result
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



;~~~ Code converted from m4_SHA512 macro to normal M code

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
 s RAinput(1)=PDmessage ;m4_catch(RAret,"brocr SHA512",RAinput)
 s sha512=$g(RAret(1)),sha512=$p($p(sha512,"(",2),")")
 q sha512

getMumpsType(type)
 s type=$zv s type=$s(type["Cache":"CACHE",type["IRIS":"CACHE",type["ISM":"ISM",1:$p(type," "))
 q
