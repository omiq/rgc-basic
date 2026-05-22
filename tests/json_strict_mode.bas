1 #OPTION JSON STRICT
2 REM Strict mode: bogus JSONNEW$ kind aborts instead of silent ""
3 PRINT "Before strict failure"
4 R$ = JSONNEW$("bogus")
5 PRINT "If you see this, strict mode is broken: " + R$
