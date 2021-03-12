:userdoc.
:title.TZSet documentation
:docprof toc=1234.

.***********************************
.*   INTRODUCTION
.***********************************

:h1.Introduction

:p.
A missing feature in the "System Clock" object in OS/2, I have always
thought, is the failure to deal with the time zone. In principle,
an application wanting to know the current time zone can call the
API function DosGetDateTime, but in practice the returned time zone
value is always "undefined". Presumably the person implementing "System
Clock" never got around to finishing the job before the project was
cancelled.

:p.In practice, programs that need this information parse the TZ
string instead. This is needless duplication. Why should application
programs keep repeating a calculation that a system utility should
have done once?

:p.This software uses the TZ environment string as the final authority, but
it stores the time zone in a way that it can be fetched by a program
calling DosGetDateTime. In addition, it provides the usual "clock"
functions of displaying the current date and time, including a way of
setting the date and time.

:p.
It is distributed as open-source freeware subject to the GNU GPL
licence. Source code is in the SOURCE directory of this package.
You can safely delete it if you are not interested in the source code.

:p.This documentation is for version 1.0.

:p.
:hp2.Disclaimer of Warranty:ehp2.

:sl compact.
:li.
:hp1.
This Product is provided "as-is", without warranty of any
kind, either expressed or implied, including, but not limited to,
the implied warranties of merchantability and fitness for a
particular purpose. The entire risk as to the quality and
performance of the Product is with you. Should the Product prove
defective, the full cost of repair, servicing, or correction lies
with you.
:ehp1.
:esl.

:p.
The author of TZSet is Peter Moylan, peter@pmoylan.org.

:p.
The latest version of TZSet is normally kept at http&colon.&slash.&slash.www.pmoylan.org/software.
Information about other software on this site may also be found on that page.

:p.
:hp2.Finding out which version you have:ehp2.

:p.If you have lost track of which version of TZSet you have, open
an OS/2 command window and type the command
:xmp.

       bldlevel clock.exe
:exmp.

:p.The "bldlevel" command is an OS/2 feature, not a TZSet feature.
Alternatively, you can just look at the "About" page of clock.exe.

.***********************************
.*   THE TWO EXECUTABLES
.***********************************

:h1 id=executables.Executables

:hp2.The two executables:ehp2.

:p.There are two executable programs in this package: Clock.exe and TZSet.exe.
TZSet sits in the background, sleeping until a time zone change (from summer
to winter time, or vice versa) happens, at which time it alters the record
inside of OS/2 of the time zone, and adjusts the clock.  If you are in a
region that does not observe daylight saving time, TZSet simply terminates
without doing anything.

:p.If you want the daylight saving adjustments, you should arrange for TZSet
to start every time you boot the operating system. The easiest way to do this
is to put a shadow or program object for TZSet into the Startup folder.

:p.The other executable, Clock.exe, is the user interface. This is where you can see the
current date and time, and alter it if necessary. To avoid duplicated clock updates,
Clock.exe kills TZSet when it starts, and then restarts it when it exits.

:p.(Exception: if your TZ string indicates that daylight saving time is not
observed, TZSet is not started.)

:p.It is theoretically possible for the clock adjustment to be missed between the
termination of Clock.exe and the execution of TZSet.exe. It will also be missed if
the change happens while your computer is shut down.
In such a case the time zone variable will still be updated correctly, but the
adjustment of the clock forward or backward might be skipped.  Since you are
probably also running some sort of Clock Synchronisation software, that
periodically gets the time from a time server, the clock will in any case be
adjusted after a few hours.

.***********************************
.*   SCOPE
.***********************************

:h1 id=scope.Scope

:hp2.Scope:ehp2.

:p.Some arbitrary decisions had to be made about what features should be
included in Clock.exe. Those decisions can be altered by user feedback,
but for now the status is

:dl break=fit.
:dt.Analogue display
:dd.The original system clock has an analogue clock display by default, but
I don't find this to be necessary. TZSet displays date and time in
pure text form.
:dt.Synchronisation
:dd.It is tempting to add a feature to synchronise with time servers, but
this seems pointless given that you probably already have software
installed to do this synchronisation.
:dt.Database of TZ strings
:dd.It would be possible to look up TZ strings for your location, but this is
probably not necessary, given that this was already done during system
installation.
:dt.Alarms
:dd.Alarms are not at present implemented. My understanding is that at present
there is no demand for such a feature. Contact me if you would like this
feature added.
:edl.

.***********************************
.*   INSTALLATION
.***********************************

:h1 id=installation.installation

:hp2.Prerequisites:ehp2.

:p.This software assumes that both INIDATA.DLL and XDS230M.DLL are in your
LIBPATH. If, when trying to run TZSet.exe, you get a message like
"The system cannot find the file XDS230M", you must install INIData,
version 1.1 or later. INIData can be found at the same web or FTP site as where
you found the TZSet zip file.

:p.:hp2.Installation:ehp2.

:p.There are no special installation requirements. Just unzip the zip file
into a directory of your choice. If you later decide that you do not want the
program, delete that directory.

:p.For preference, TZSet.exe should be running at any time that Clock.exe
is not running, to ensure that the summer time start or end is detected
when it happens. (This creates very little overhead, because TZSet spends
almost all of its time sleeping, waking up approximately once every 24 days
to see whether a change is needed.) To achieve this, you should arrange to
start TZSet.exe each time the system boots up. The easiest way to do this
is to put a shadow or a program object in your Startup folder.

:p.You may, if you wish, create a program object for clock.exe in
your "System Setup" folder, but that is optional.

.***********************************
.*   LANGUAGE SUPPORT
.***********************************

:h1.Language support

:hp2.Language support:ehp2.

:p.The language used for the labels on the TZSet interface is
controlled by the file TZSet.xyz.lng, where xyz is a code for the
language. To add support for a new language, copy TZSet.en.lng (or
any other supported language file) to
a new file, and translate the content in the obvious way. If you send
me a copy of your translation, I will include it in future releases.

.***********************************
.*   THE CLOCK PAGE
.***********************************

:h1.The clock page
:hp2.The clock page:ehp2.

:p.This page displays the current date and time.

:p.Not everyone agrees about the correct order for things like day,
month, and year, so these are controlled by format strings that you
can alter. In the format strings, the following codes are used.

:dl.
    :dt.      HH
    :dd.hours
    :dt.      MM
    :dd.minutes
    :dt.      SS
    :dd.seconds
    :dt.      AM
    :dd.implies 12-hour clock, replaced by PM if needed
    :dt.      PM
    :dd.implies 12-hour clock, replaced by AM if needed
    :dt.      dd
    :dd.day, numeric
    :dt.      ddd
    :dd.day, three-letter name
    :dt.      mm
    :dd.month, numeric
    :dt.      mmm
    :dd.month, three-letter name
    :dt.      yy
    :dd.year, including Y2K bug
    :dt.      yyyy
    :dd.year, all four digits
    :dt.      zz
    :dd.first time: sign and hours of time zone
    :dt.      zz
    :dd.second time: minutes part of time zone
:edl.

:p.All other characters are interpreted literally. This allows you to
insert separators like '/' or '&colon.'.

:note.In some languages the day name and/or month name could be
more than three characters long.

:p.Note that the format codes are case-sensitive. For example, mm and MM have
completely different meanings.

:p.This notebook page also includes a "language" field. If you enter a code
xyz in this field, the notebook labels will be taken from a file
Clock.xyz.lng. If no such file exists, the language labels will remain
unchanged.

:p.Click on the "SET CLOCK" button to change the date or time.

.***********************************
.*   SETTING THE CLOCK
.***********************************

:h1 id=setting.Setting the clock
:hp2.Setting the clock:ehp2.

:p.
If you click on the "SET CLOCK" button on the Clock page, you will get a new
dialogue that lets you alter the date and time.

:note.If you are running any "Clock synchronisation" software - included in
some OS/2 distributions, and probably found in your "System Setup" folder -
that will cancel out any clock changes that you make. Typically, though,
that change will happen only several hours later.

:p.The dialogue for setting the date/time has six fields whose meaning should
be obvious. Note, however, that the order of the date fields is controlled by
the date format string that was specified on the Clock page. That means that
the order will be different for different people.

:p.The time is displayed in 24-hour notation by default. If you prefer a 12-hour
clock, select the "12h" radio button. In that case, an "AM" or "PM" button will appear.
Clicking on that button will toggle between "AM" and "PM".

:p.Clicking on the "OK" button will make your decisions final. If instead you
choose "Cancel", your choices will be discarded.

.***********************************
.*   THE TIME ZONE PAGE
.***********************************

:h1.Time zone
:hp2.Time zone:ehp2.

:p.The only editable field in this tab is the TZ string. This is taken
from the file CONFIG.SYS. When you exit the program CONFIG.SYS will
be updated, but only if the updated string is a valid TZ string.

:p.As you are editing this string, error messages will appear. You
can usually ignore these, because they will usually disappear once you
have made your modifications. If the error messages persist, you
will need to check your TZ string for validity.

:p.The rest of this page is informational. It tells you when the
next time zone change will occur. The display will be updated if the
change happens while this program is running.

.***********************************
.*   ABOUT
.***********************************

:h1 id=About.About

:p.:hp2.About:ehp2.

:p.The "About" page tells you the program version, and related detail.

.***********************************
.*   FONTS
.***********************************

:h1 id=Fonts.Fonts
:hp2.Fonts:ehp2.

:p.You can change the display fonts, with some restrictions, by dropping a new font from the
font palette.

:p.With one exception, to be explained below, dropping a font on an individual
display element (such as a label, an entry field, etc.) has only temporary
effect. The font will change, but will not be remembered for the next time
you run the program.

:p.If you drop a font on the background area of a dialogue, this will change all fonts
in the notebook, or all fonts in the "Set clock" dialogue, as appropriate.
This change will be remembered.

:p.The two lines that are the date and time display have their own font. They are
not affected by the above "background" drop. However, dropping a font on either
of these fields will change the font of the other as well.

:euserdoc.

