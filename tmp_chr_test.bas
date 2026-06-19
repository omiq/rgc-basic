function test()
  GV=305
  print ECOL$;chr$(48+GV\100);
  print DCOL$;chr$(48+(GV\10)mod10);
  print HCOL$;chr$(48+GV mod10);FCOL$;
  print "---";
  print ECOL$;GV\100;
  print DCOL$;(GV\10)mod10;
  print HCOL$;GV mod10;FCOL$;
  return
end function
