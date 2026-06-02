REM UDF in PRINT list must not strand the parse cursor (next bare PRINT needs a newline).
function Tag$(N)
    return "Q"+str$(N)
end function

print "A";Tag$(1);".";
print
print "OK"
end
