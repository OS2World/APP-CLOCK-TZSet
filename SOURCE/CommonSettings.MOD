(**************************************************************************)
(*                                                                        *)
(*  Clock utility                                                         *)
(*  Copyright (C) 2020   Peter Moylan                                     *)
(*                                                                        *)
(*  This program is free software: you can redistribute it and/or modify  *)
(*  it under the terms of the GNU General Public License as published by  *)
(*  the Free Software Foundation, either version 3 of the License, or     *)
(*  (at your option) any later version.                                   *)
(*                                                                        *)
(*  This program is distributed in the hope that it will be useful,       *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU General Public License for more details.                          *)
(*                                                                        *)
(*  You should have received a copy of the GNU General Public License     *)
(*  along with this program.  If not, see <http://www.gnu.org/licenses/>. *)
(*                                                                        *)
(*  To contact author:   http://www.pmoylan.org   peter@pmoylan.org       *)
(*                                                                        *)
(**************************************************************************)

IMPLEMENTATION MODULE CommonSettings;

        (****************************************************************)
        (*                                                              *)
        (*                         Clock utility                        *)
        (*                 Data common to several modules               *)
        (*                                                              *)
        (*    Started:        10 August 2020                            *)
        (*    Last edited:    23 September 2020                         *)
        (*    Status:         OK                                        *)
        (*                                                              *)
        (****************************************************************)


IMPORT OS2, Strings, FileSys, INIData, Languages;

FROM Names IMPORT
    (* type *)  FilenameString;

FROM Storage IMPORT
    (* proc *)  ALLOCATE;

(************************************************************************)

CONST
    Nul = CHR(0);

TYPE
    NameArray = ARRAY FontGroup OF FontName;
    WindowList = POINTER TO
                    RECORD
                        this: OS2.HWND;
                        next: WindowList;
                    END (*RECORD*);

    WindowPosition = RECORD
                         x, y: INTEGER;
                     END (*RECORD*);

<* PUSH *>
<* VOLATILE+ *>

VAR
    INIFileName: FilenameString;
    GroupWindows: ARRAY FontGroup OF WindowList;

    OurFontName: NameArray;
    OurLanguage: Languages.LangHandle;
    LanguageCode: ARRAY [0..31] OF CHAR;
    StartingUp: BOOLEAN;

<* POP *>

CONST
    GroupLabel = NameArray {"MainDlg", "BigFont", "EditDlg"};
    DefaultFont = NameArray {"8.Helv", "14.Helv", "8.Helv"};

(************************************************************************)
(*                         WINDOW POSITION                              *)
(************************************************************************)

PROCEDURE SetInitialWindowPosition (hwnd: OS2.HWND;  group: FontGroup);

    (* If this window has a previously stored position in our INI file, *)
    (* positions the window to that position.                           *)

    CONST bufsize = 256;

    VAR hini: INIData.HINI;  pos: WindowPosition;
        app: ARRAY [0..9] OF CHAR;

    BEGIN
        hini := INIData.OpenINIFile(INIFileName);
        IF NOT INIData.INIValid(hini) THEN
            hini := INIData.CreateINIFile(INIFileName);
        END (*IF*);
        app := "WindowPos";
        IF INIData.INIGet (hini, app, GroupLabel[group], pos) THEN
            OS2.WinSetWindowPos (hwnd, 0, pos.x, pos.y, 0, 0, OS2.SWP_MOVE);
        END (*IF*);
        INIData.CloseINIFile (hini);
    END SetInitialWindowPosition;

(************************************************************************)

PROCEDURE StoreWindowPosition (hwnd: OS2.HWND;  group: FontGroup);

    (* Saves the location of this window in our INI file. *)

    CONST bufsize = 256;

    VAR hini: INIData.HINI;  swp: OS2.SWP;
        pos: WindowPosition;
        app: ARRAY [0..9] OF CHAR;

    BEGIN
        OS2.WinQueryWindowPos (hwnd, swp);
        pos.x := swp.x;  pos.y := swp.y;
        hini := INIData.OpenINIFile(INIFileName);
        app := "WindowPos";
        INIData.INIPut (hini, app, GroupLabel[group], pos);
        INIData.CloseINIFile (hini);
    END StoreWindowPosition;

(************************************************************************)
(*                              FONTS                                   *)
(************************************************************************)

PROCEDURE AddToGroup (group: FontGroup;  hwnd: OS2.HWND;  ID: CARDINAL);

    (* Declares a window to belong to this group.  If ID=0 then hwnd    *)
    (* is the window.  Otherwise, ID identifies a subwindow of hwnd.    *)

    VAR w: OS2.HWND;
        p: WindowList;

    BEGIN
        IF ID = 0 THEN w := hwnd;
        ELSE
            w := OS2.WinWindowFromID (hwnd, ID);
        END (*IF*);
        NEW (p);
        p^.this := w;
        p^.next := GroupWindows[group];
        GroupWindows[group] := p;
    END AddToGroup;

(************************************************************************)

PROCEDURE SetFontsForGroup (group: FontGroup);

    (* Sets the font for all windows in this group.  This might be      *)
    (* overkill, but it's the simplest solution until such time as I've *)
    (* solved the font inheritance problem.                             *)

    VAR p: WindowList;

    BEGIN
        p := GroupWindows[group];
        WHILE p <> NIL DO
            OS2.WinSetPresParam (p^.this, OS2.PP_FONTNAMESIZE,
                                        FontNameSize, OurFontName[group]);
            p := p^.next;
        END (*WHILE*);
    END SetFontsForGroup;

(************************************************************************)

PROCEDURE UpdateFontFrom (hwnd: OS2.HWND;  group: FontGroup);

    (* Takes the font setting from window hwnd and propagates it to the *)
    (* entire group.  Note that this will often be a "no operation"     *)
    (* because the font is no different from the presently active one.  *)

    VAR NewFontName: FontName;
        AttrFound, length: CARDINAL;
        hini: INIData.HINI;
        app: ARRAY [0..4] OF CHAR;

    BEGIN
        length := OS2.WinQueryPresParam (hwnd, OS2.PP_FONTNAMESIZE, 0,
                                     AttrFound, FontNameSize, NewFontName,
                                      OS2.QPF_NOINHERIT);
        IF length < FontNameSize THEN
            NewFontName[length] := Nul;
        END (*IF*);

        IF NOT Strings.Equal (NewFontName, OurFontName[group]) THEN

            OurFontName[group] := NewFontName;
            hini := INIData.OpenINIFile (INIFileName);
            app := "Font";
            INIData.INIPutString (hini, app, GroupLabel[group],
                                                        OurFontName[group]);
            INIData.CloseINIFile (hini);

            SetFontsForGroup (group);

        END (*IF*);

    END UpdateFontFrom;

(************************************************************************)
(*                              LANGUAGE                                *)
(************************************************************************)

PROCEDURE SetDayNames (lang: Languages.LangHandle);

    (* Fills in the DayNames array. *)

    BEGIN
        Languages.StrToBuffer (lang, "Sun", DayName[0]);
        Languages.StrToBuffer (lang, "Mon", DayName[1]);
        Languages.StrToBuffer (lang, "Tue", DayName[2]);
        Languages.StrToBuffer (lang, "Wed", DayName[3]);
        Languages.StrToBuffer (lang, "Thu", DayName[4]);
        Languages.StrToBuffer (lang, "Fri", DayName[5]);
        Languages.StrToBuffer (lang, "Sat", DayName[6]);
    END SetDayNames;

(************************************************************************)

PROCEDURE SetMonthNames (lang: Languages.LangHandle);

    (* Fills in the MonthNames array. *)

    BEGIN
        Languages.StrToBuffer (lang, "Jan", MonthName[1]);
        Languages.StrToBuffer (lang, "Feb", MonthName[2]);
        Languages.StrToBuffer (lang, "Mar", MonthName[3]);
        Languages.StrToBuffer (lang, "Apr", MonthName[4]);
        Languages.StrToBuffer (lang, "May", MonthName[5]);
        Languages.StrToBuffer (lang, "Jun", MonthName[6]);
        Languages.StrToBuffer (lang, "Jul", MonthName[7]);
        Languages.StrToBuffer (lang, "Aug", MonthName[8]);
        Languages.StrToBuffer (lang, "Sep", MonthName[9]);
        Languages.StrToBuffer (lang, "Oct", MonthName[10]);
        Languages.StrToBuffer (lang, "Nov", MonthName[11]);
        Languages.StrToBuffer (lang, "Dec", MonthName[12]);
    END SetMonthNames;

(************************************************************************)

PROCEDURE ChangeLanguageTo (name: ARRAY OF CHAR): BOOLEAN;

    (* Changes the current language setting, but only if a suitable     *)
    (* Clock.name.lng file exists.  Returns FALSE if no change.         *)

    CONST prefix = "Clock";

    VAR result: BOOLEAN;  file: FilenameString;

    BEGIN
        Strings.Capitalize (name);
        result := StartingUp;
        StartingUp := FALSE;
        IF NOT Strings.Equal (name, LanguageCode) THEN
            Strings.Assign (prefix, file);
            Strings.Append (".", file);
            Strings.Append (name, file);
            Strings.Append (".lng", file);
            IF FileSys.Exists (file) THEN
                Languages.DropLanguage (OurLanguage);
                Strings.Assign (name, LanguageCode);
                OurLanguage := Languages.UseLanguage (prefix, name);
                SetDayNames (OurLanguage);
                SetMonthNames (OurLanguage);
                result := TRUE;
            END (*IF*);
        END (*IF*);
        RETURN result;
    END ChangeLanguageTo;

(************************************************************************)

PROCEDURE CurrentLanguage (VAR (*OUT*) lang: Languages.LangHandle;
                                VAR (*OUT*) name: ARRAY OF CHAR);

    (* Returns the current language setting. *)

    BEGIN
        lang := OurLanguage;
        Strings.Assign (LanguageCode, name);
    END CurrentLanguage;

(************************************************************************)

PROCEDURE SetInitialLanguage;

    (* Sets the language from the INI file. *)

    VAR hini: INIData.HINI;
        SYSapp: ARRAY [0..4] OF CHAR;

    BEGIN
        SYSapp := "$SYS";
        hini := INIData.OpenINIFile(INIFileName);
        IF INIData.INIValid(hini) THEN
            IF NOT INIData.INIGetString (hini, SYSapp, 'Language', LanguageCode)
                                         OR (LanguageCode[0] = Nul) THEN
                LanguageCode := "en";
            END (*IF*);
            INIData.CloseINIFile (hini);
        ELSE
            LanguageCode := "en";
        END (*IF*);
        OurLanguage := Languages.UseLanguage ("Clock", LanguageCode);
    END SetInitialLanguage;

(**************************************************************************)
(*                             INITIALISATION                             *)
(**************************************************************************)

PROCEDURE SetInitialFontsAndLanguage;

    (* Initialisation for CommonSettings module. *)

    VAR hini: INIData.HINI;  group: FontGroup;
        app: ARRAY [0..4] OF CHAR;

    BEGIN
        hini := INIData.OpenINIFile(INIFileName);
        IF NOT INIData.INIValid(hini) THEN
            hini := INIData.CreateINIFile(INIFileName);
        END (*IF*);
        app := "Font";
        FOR group := MIN(FontGroup) TO MAX(FontGroup) DO
            GroupWindows[group] := NIL;
            IF NOT INIData.INIGetString (hini, app, GroupLabel[group],
                                                OurFontName[group])
                          OR (OurFontName[group][0] = Nul) THEN
                OurFontName[group] := DefaultFont[group];
                INIData.INIPutString (hini, app, GroupLabel[group],
                                                    OurFontName[group]);
            END (*IF*);
        END (*FOR*);
        INIData.CloseINIFile (hini);
        SetInitialLanguage;
    END SetInitialFontsAndLanguage;

(************************************************************************)

BEGIN
    StartingUp := TRUE;
    INIFileName := "Clock.INI";
    SetInitialFontsAndLanguage;
END CommonSettings.

