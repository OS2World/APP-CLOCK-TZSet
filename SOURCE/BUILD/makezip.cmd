/* Batch file to create the TZSet distribution. */

'del TZSet*.zip 2>nul'
'del temp /N 2>nul'
'call deltree /Y temp >nul'           /* deltree3.zip from Hobbes */
'xc =p clock.prj'
'xc =p TZset.prj'
'\apps\lxlite\lxlite *.exe'

/* Create the INF file. */

'cd doc'
'ipfc -i TZSet.ipf'
'cd ..'

/* Generate symbol files.  The next four lines can be skipped   */
/* if you don't have Perl.                                      */

'copy D:\Dev1\mapxqs.exe'
'call PerlEnv.cmd'
perl 'D:\Apps\scripts\makexqs.pl' clock.map
say "clock.sym and clock.xqs should now exist"

/* Build level. */

call seticon
ver = version()
call bldlvl ver

/* Zip up the source files. */

'del src.zip 2>nul'
'Imports Clock | zip -q -j -u src.zip -@'
'Imports TZmon | zip -q -j -u src.zip -@'
'zip -q src.zip Clock.prj TZmon.prj xc.red'

/* Copy the files we want to zip up into a "temp" directory. */

mkdir temp
cd temp
mkdir DOC
'copy ..\doc\changes.txt doc'
'copy ..\doc\TZSet.inf doc'
mkdir SOURCE
'move ..\src.zip SOURCE'
'copy ..\res\DID.res SOURCE'
cd SOURCE
'unzip -q -o src.zip'
'del src.zip'
'mkdir DOC'
'copy ..\..\doc\TZSet.ipf doc'
'mkdir BUILD'
'copy ..\..\bldlvl.cmd BUILD'
'copy ..\..\makezip.cmd BUILD'
'copy ..\..\version.cmd BUILD'
'cd ..'
'copy ..\README'
'copy D:\Dev1\General\doc\gpl.txt'
'copy ..\Clock.exe'
'copy ..\Clock.sym'
'copy ..\Clock.xqs'
'copy ..\Clock.map'
'copy ..\clock.*.lng'
'copy ..\TZset.exe'

/* Create the final zip file. */

'zip -q -r ..\TZSet_'ver'.zip .'

/* Remove temporary files and directories. */

'cd SOURCE'
'del * /n'
'del DOC\* /n'
'rmdir DOC'
'del BUILD\* /n'
'rmdir BUILD'
'cd ..'
'rmdir SOURCE'
'del doc\* /n'
rmdir doc
'del * /n'
'cd ..'
rmdir temp

