5 REM Regression tests for string slicing patterns used in trek.bas

REM Basic LEFT$/RIGHT$ behaviour
10 A$="ABCDEFG"
20 PRINT RIGHT$(A$,5)  : REM Expect CDEFG
30 PRINT LEFT$(A$,5)   : REM Expect ABCDE

REM Quadrant insertion-style splice like trek.bas line 5440
40 Q$=STRING$(190,".")  : REM 190 dots
50 A$="XYZ"
60 S8=10
70 Q$=LEFT$(Q$,S8-1)+A$+RIGHT$(Q$,190-S8)
80 PRINT MID$(Q$,S8,3) : REM Expect XYZ
90 END
