; Benchmark comparison of SHA2 via M, MLua, and C

%benchmark()
 q

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

cmumpsHash(glvn)
 s out=$$%HSHA512(glvn,1)
 q out

; Generate string of random characters.
; Has to be fast because we make it before every timing test
; So, for the sake of speed, cheat -- by repeating 250 chars 4000 times.
; Done this way, it takes about 0.3 ms which is negligible
; Lua can do it in half this time, but we don't need that: 0.3 ms is negligible.
; Done without repeats, it takes 0.3 seconds whereas lua takes 46 ms
; However, ended up having to use Lua since ydb doesn't have a random seed function
; And results need to be repeatable just so we can test one has against another
init()
 n msg,msgTmp,i
 s msg="",msgTmp=""
 for i=1:1:250 s msgTmp=msgTmp_$C($random(256))
 for i=1:1:4000 s msg=msg_msgTmp
 s bigRandomString=msg
 q

cmumps()
 for i=1:1:iterations d
 . s dummy=$$cmumpsHash(msg)
 q

lua()
 for i=1:1:iterations d
 . s dummy=$$cmumpsHash(msg)
 q

; invoke from command line: test^%benchmark <command> <iterations> <hashSize>
test()
 d init()
 new command,size
 set command=$piece($zcmdline," ",1)
 set iterations=$piece($zcmdline," ",2)
 set size=$piece($zcmdline," ",3)
 s msg=$extract(bigRandomString,1,size)
 xecute "do "_command_"()"
 q

time()
 for j=1:1:1000 d
 . d init()
; . w j_$extract(bigRandomString,1)_" "
; . w $length(bigRandomString)
; . w $extract(bigRandomString,1,2)," ",!
 q

noop()
 q