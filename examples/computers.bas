REM RETRO COMPUTERS AS SPRITE STAMPS 
REM ================================

' 640x400 
  SCREEN 4               
  ANTIALIAS OFF
  BACKGROUNDRGB 0, 0, 0                                                         
  CLS
                                                                                
  LOADSPRITE 0, "computer-sheet.png", 128, 128           
                                                                                
  FOR I = 0 TO 12                                        
    COL = I MOD 5
    ROW = I \ 5                                                                 
    SPRITE STAMP 0, COL * 128, ROW * 128, I + 1
  NEXT                                                                          
                                                         
  DO                                                                            
    VSYNC
  LOOP                                              