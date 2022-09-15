; Benchmark comparison of SHA2 via M, MLua, and C

%shabench()
 d run()
 w ! q

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
 s out=$$%HSHA512^%shaBench(glvn,1)
 q out

init()
 s msg=""
 n msgTmp s msgTmp=""
 for i=1:1:1000 s msgTmp=msgTmp_$C($random(256))
 for i=1:1:1000 s msg=msg_msgTmp
 q

run()
 d init()
 for i=1:1:1000 d
 . s dummy=$$cmumpsHash(msg)
 q
