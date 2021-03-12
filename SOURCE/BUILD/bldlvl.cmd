/*----------------------------------------------------------
   Appends a build level to NUCLOCK.EXE.

           Author:       Peter Moylan
           Last revised: 6 October 2020

   Usage:
           bldlvl ver

           where ver is the version string

------------------------------------------------------------*/

parse arg ver
projHost = "PJM3"
timestamp = LEFT(DATE() TIME(),25)LEFT(projHost,10)
signature = "@#Peter Moylan:"ver"#@##1## "timestamp"::EN:AU:::@@Replacement for System Clock object"
outfile = "level.txt"
"@DEL "outfile" 2> NUL"
CALL LINEOUT outfile, signature
CALL STREAM outfile,'C','CLOSE'
"@copy Clock.exe /B + level.txt Clock.exe /B > NUL"
"@copy TZset.exe /B + level.txt TZset.exe /B > NUL"
"@DEL "outfile

exit

