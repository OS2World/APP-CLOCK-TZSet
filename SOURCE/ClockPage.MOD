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

IMPLEMENTATION MODULE ClockPage;

        (****************************************************************)
        (*                                                              *)
        (*                          Clock utility                       *)
        (*                     Page 1 of the notebook                   *)
        (*                                                              *)
        (*    Started:        10 August 2020                            *)
        (*    Last edited:    23 September 2020                         *)
        (*    Status:         OK                                        *)
        (*                                                              *)
        (****************************************************************)


FROM SYSTEM IMPORT ADDRESS, CARD8, INT16, CAST, ADR;

IMPORT OS2, OS2RTL, CommonSettings, EditDlg;

IMPORT DID, Strings;

FROM PMInit IMPORT
    (* proc *)  OurHab;

FROM CommonSettings IMPORT
    (* const*)  FontNameSize,
    (* type *)  FontName, FontGroup,
    (* proc *)  AddToGroup, UpdateFontFrom, CurrentLanguage, ChangeLanguageTo;

FROM INIData IMPORT
    (* type *)  HINI,
    (* proc *)  OpenINIFile, INIValid, CloseINIFile, INIGetString, INIPutString;

FROM TaskControl IMPORT
    (* proc *)  CreateTask;

FROM Languages IMPORT
    (* type *)  LangHandle,
    (* proc *)  StrToBuffer;

FROM DTFormat IMPORT
    (* proc *)  FormatDateTime;

FROM InternalDT IMPORT
    (* type *)  IDateTime,
    (* proc *)  AddMinutes, SubtractMinutes, DTtoIDT, IDTtoDT;

FROM MiscFuncs IMPORT
    (* proc *)  EVAL;

FROM Names IMPORT
    (* type *)  FilenameString;

(**************************************************************************)

CONST
    Nul = CHR(0);
    LangStringSize = 32;

TYPE
    DirectoryString = ARRAY [0..511] OF CHAR;
    LangString = ARRAY [0..LangStringSize-1] OF CHAR;
    FormatString = ARRAY [0..63] OF CHAR;

VAR
    TimerMethod: (useWM_TIMER);

    INIFileName: FilenameString;

(*
    <* PUSH *>
    <* VOLATILE+ *>
        pagehandle: OS2.HWND;
    <* POP *>
*)

    OurWindow, pagehandle, notebookhandle, hwndParent: OS2.HWND;
    OurPageID: CARDINAL;
    ourlanguage: LangHandle;

    (* The point at which we should notify a "significant" change in    *)
    (* the time.  See procedure SetWatch for details.                   *)

    WatchLevel: CARDINAL;

    ChangeInProgress: BOOLEAN;

    (* Format Strings. *)

    DateFormat, TimeFormat: FormatString;

    (* The last date/time we have displayed. *)

    LastDateTime: OS2.DATETIME;

    (* Original values of the ini variables. *)

    OldLanguage: LangString;
    OldDateFormat, OldTimeFormat: FormatString;

(************************************************************************)
(*                    UPDATING THE DATE/TIME DISPLAY                    *)
(************************************************************************)

PROCEDURE RefreshDateAndTime (hwnd: OS2.HWND);

    (* Responds to a WM_TIMER message, or a language change. *)

    VAR dt: OS2.DATETIME;
        string: FormatString;
        watch: BOOLEAN;

    BEGIN
        OS2.DosGetDateTime (dt);
        FormatDateTime (dt, DateFormat, string);
        OS2.WinSetDlgItemText (hwnd, DID.date, string);
        IF dt.seconds <> LastDateTime.seconds THEN
            FormatDateTime (dt, TimeFormat, string);
            OS2.WinSetDlgItemText (hwnd, DID.time, string);
        END (*IF*);

        (* Now decide whether to notify a significant change, where the *)
        (* meaning of "significant" depends on WatchLevel.  Longer-term *)
        (* notifications supersede shorter-interval ones, so it is      *)
        (* important to test in the correct order.                      *)

        (* The once-per-day notification, at midnight, is unconditional. *)

        IF dt.day <> LastDateTime.day THEN
            OS2.WinPostMsg (hwndParent, CommonSettings.TIMECHANGED,
                            OS2.MPFROMLONG(1), OS2.MPFROMLONG(0));
        ELSE
            watch := FALSE;
            IF dt.hours <> LastDateTime.hours THEN
                watch := WatchLevel >= 1;
            END (*IF*);
            IF (NOT watch) AND (WatchLevel >= 2) THEN
                watch := dt.minutes <> LastDateTime.minutes;
            END (*IF*);
            IF (NOT watch) AND (WatchLevel >= 3) THEN
                watch := dt.seconds <> LastDateTime.seconds;
            END (*IF*);

            IF watch THEN
                OS2.WinPostMsg (hwndParent, CommonSettings.NEWTICK,
                                OS2.MPFROMLONG(1), OS2.MPFROMLONG(0));
            END (*IF*);

        END (*IF*);

        LastDateTime := dt;

    END RefreshDateAndTime;

(************************************************************************)
(*                    OPERATIONS ON DIALOGUE LABELS                     *)
(************************************************************************)

PROCEDURE SetLanguage (lang: LangHandle);

    (* Relabels this page in the new language. *)

    VAR stringval: ARRAY [0..511] OF CHAR;

    BEGIN
        ourlanguage := lang;
        StrToBuffer (lang, "ClockPage.tab", stringval);
        OS2.WinSendMsg (notebookhandle, OS2.BKM_SETTABTEXT,
                        CAST(ADDRESS,OurPageID), ADR(stringval));

        StrToBuffer (lang, "ClockPage.language", stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.langlabel, stringval);

        StrToBuffer (lang, "ClockPage.format", stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.format, stringval);

        StrToBuffer (lang, "ClockPage.setclock", stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.setclock, stringval);

        RefreshDateAndTime (pagehandle);

    END SetLanguage;

(************************************************************************)
(*                     LOADING DATA FROM THE INI FILE                   *)
(************************************************************************)

PROCEDURE LoadValues (hwnd: OS2.HWND);

    (* Fills the dialogue elements on page 1 with data from the INI file,       *)
    (* or loads default values if they're not in the INI file.                  *)

    VAR opened: BOOLEAN;
        NewLang: LangHandle;
        HostName: DirectoryString;
        hini: HINI;
        SysApp: ARRAY [0..4] OF CHAR;
        stringval: LangString;

    BEGIN
        HostName[0] := Nul;
        hini := OpenINIFile (INIFileName);
        opened := INIValid (hini);
        SysApp := "$SYS";

        (* Language. *)

        IF opened AND INIGetString (hini, SysApp, 'language', stringval) THEN
            Strings.Assign (stringval, OldLanguage);
        ELSE
            stringval := "en";
        END (*IF*);
        OS2.WinSetDlgItemText (hwnd, DID.language, stringval);
        IF ChangeLanguageTo(stringval) THEN
            CurrentLanguage (NewLang, stringval);
            SetLanguage (NewLang);
        END (*IF*);

        (* Date format. *)

        IF opened AND INIGetString (hini, SysApp, 'dateformat', DateFormat) THEN
            Strings.Assign (DateFormat, OldDateFormat);
        ELSE
            DateFormat := "ddd, dd-mmm-yyyy zz:zz";
        END (*IF*);
        OS2.WinSetDlgItemText (hwnd, DID.dateformat, DateFormat);

        (* Time format. *)

        IF opened AND INIGetString (hini, SysApp, 'timeformat', TimeFormat) THEN
            Strings.Assign (DateFormat, OldTimeFormat);
        ELSE
            TimeFormat := "HH:MM and SS seconds";
        END (*IF*);
        OS2.WinSetDlgItemText (hwnd, DID.timeformat, TimeFormat);

        CloseINIFile(hini);

    END LoadValues;

(************************************************************************)
(*                      STORING DATA TO THE INI FILE                    *)
(************************************************************************)

PROCEDURE StoreData (hwnd: OS2.HWND);

    (* Stores the values on the clock page back into the INI file.  *)

    VAR opened: BOOLEAN;
        hini: HINI;
        app: ARRAY [0..4] OF CHAR;
        stringval: ARRAY [0..127] OF CHAR;

    BEGIN
        hini := OpenINIFile (INIFileName);
        opened := INIValid (hini);

        IF opened THEN

            app := "$SYS";

            (* Language. *)

            OS2.WinQueryDlgItemText (hwnd, DID.language, 32, stringval);
            IF NOT Strings.Equal (stringval, OldLanguage) THEN
                INIPutString (hini, app, 'language', stringval);
            END (*IF*);

            (* Date format. *)

            OS2.WinQueryDlgItemText (hwnd, DID.dateformat, SIZE(FormatString), stringval);
            IF NOT Strings.Equal (stringval, OldDateFormat) THEN
                INIPutString (hini, app, 'dateformat', stringval);
            END (*IF*);

            (* Time format. *)

            OS2.WinQueryDlgItemText (hwnd, DID.timeformat, SIZE(FormatString), stringval);
            IF NOT Strings.Equal (stringval, OldTimeFormat) THEN
                INIPutString (hini, app, 'timeformat', stringval);
            END (*IF*);

            CloseINIFile(hini);
        END (*IF*);

    END StoreData;

(************************************************************************)
(*                     REQUESTS FROM ELSEWHERE                          *)
(************************************************************************)

PROCEDURE SetWatch (level: CARDINAL);

    (* Request, from the time zone page, to be notified, when there is   *)
    (* an important change in date/time.  The values of level are:       *)
    (*   0   only notify on the midnight switch to a new day             *)
    (*   1   notify once per hour                                        *)
    (*   2   notify once per minute                                      *)
    (*   3   notify once per second                                      *)

    BEGIN
        WatchLevel := level;
    END SetWatch;

(************************************************************************)
(*                  CLOCK CHANGE ON TIME ZONE CHANGE                    *)
(************************************************************************)

PROCEDURE AdjustClock (minutes: INTEGER);

    (* Subtracts minutes from the current time. *)

    VAR dt: OS2.DATETIME;
        idt: IDateTime;

    BEGIN
        OS2.DosGetDateTime (dt);
        idt := DTtoIDT (dt);
        IF minutes >= 0 THEN
            AddMinutes (idt, minutes);
        ELSE
            SubtractMinutes (idt, ORD(-minutes));
        END (*IF*);
        dt := IDTtoDT(idt);
        OS2.DosSetDateTime (dt);
    END AdjustClock;

(************************************************************************)
(*                        DIALOGUE PROCEDURE                            *)
(************************************************************************)

PROCEDURE DeclareWindows (hwnd: OS2.HWND);

    (* Tells module CommonSettings which windows belong to which group. *)

    BEGIN
        AddToGroup (MainDlg, hwnd, 0);
        AddToGroup (MainDlg, hwnd, DID.langlabel);
        AddToGroup (MainDlg, hwnd, DID.language);
        AddToGroup (MainDlg, hwnd, DID.format);
        AddToGroup (MainDlg, hwnd, DID.dateformat);
        AddToGroup (MainDlg, hwnd, DID.timeformat);
        AddToGroup (MainDlg, hwnd, DID.setclock);

        AddToGroup (BigFont, hwnd, DID.date);
        AddToGroup (BigFont, hwnd, DID.time);

    END DeclareWindows;

(**************************************************************************)

PROCEDURE ["SysCall"] DialogueProc (hwnd: OS2.HWND;  msg: OS2.ULONG;
                                      mp1, mp2: OS2.MPARAM): OS2.MRESULT;

    VAR ButtonID, NotificationCode: CARDINAL;
        NewLang: LangHandle;
        langval: ARRAY [0..LangStringSize] OF CHAR;
        format: FormatString;

    BEGIN
        NotificationCode := OS2.ULONGFROMMP(mp1);
        ButtonID := NotificationCode MOD 65536;
        NotificationCode := NotificationCode DIV 65536;

        IF msg = OS2.WM_INITDLG THEN

            DeclareWindows(hwnd);
            OurWindow := hwnd;
            LoadValues (hwnd);
            OS2.WinSetDlgItemText (hwnd, DID.clockdebug, "");
            RETURN NIL;

        ELSIF msg = OS2.WM_TIMER THEN

            (* So far I haven't found a way to intercept a font  *)
            (* change in time or date, so checking once every    *)
            (* clock tick is the only approach I can think of    *)
            (* for now.                                          *)

            UpdateFontFrom (OS2.WinWindowFromID (hwnd, DID.date), BigFont);
            UpdateFontFrom (OS2.WinWindowFromID (hwnd, DID.time), BigFont);

            (* Now the real business of handling a timer tick. *)

            RefreshDateAndTime (hwnd);
            RETURN NIL;

        ELSIF msg = OS2.WM_PRESPARAMCHANGED THEN

            IF ChangeInProgress THEN
                RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
            ELSE
                ChangeInProgress := TRUE;
                UpdateFontFrom (hwnd, MainDlg);
                ChangeInProgress := FALSE;
                RETURN NIL;
            END (*IF*);

        ELSIF msg = OS2.WM_COMMAND THEN
            IF ButtonID = DID.setclock THEN
                OS2.WinQueryDlgItemText (hwnd, DID.dateformat, SIZE(FormatString), format);
                EditDlg.Edit (hwnd, ourlanguage, format);
                OS2.WinPostMsg (hwndParent, CommonSettings.TIMECHANGED,
                                OS2.MPFROMLONG(1), OS2.MPFROMLONG(0));
                RETURN NIL;
            ELSE
                RETURN OS2.WinDefDlgProc (hwnd, msg, mp1, mp2);
            END (*IF*);

        ELSIF msg = OS2.WM_CONTROL THEN

            IF NotificationCode = OS2.EN_CHANGE THEN
                CASE ButtonID OF
                    DID.language:
                        OS2.WinQueryDlgItemText (hwnd, DID.language,
                                                 LangStringSize+1, langval);
                        IF ChangeLanguageTo(langval) THEN
                            CurrentLanguage (NewLang, langval);
                            SetLanguage (NewLang);
                            OS2.WinPostMsg (hwndParent, CommonSettings.LANGCHANGED,
                                   OS2.MPFROMLONG(1), OS2.MPFROMLONG(0));
                        END (*IF*);
                        RETURN NIL;
                    |
                    DID.dateformat:
                        OS2.WinQueryDlgItemText (hwnd, DID.dateformat, SIZE(FormatString), DateFormat);
                        LastDateTime.day := CHR(0);
                        RETURN NIL;
                    |
                    DID.timeformat:
                        OS2.WinQueryDlgItemText (hwnd, DID.timeformat, SIZE(FormatString), TimeFormat);
                        RETURN NIL;
                    |
                ELSE
                        RETURN OS2.WinDefDlgProc (hwnd, msg, mp1, mp2);
                END (*CASE*);

            END (*IF*);

        END (*CASE*);

        RETURN OS2.WinDefDlgProc (hwnd, msg, mp1, mp2);

    END DialogueProc;

(**************************************************************************)

PROCEDURE CreatePage (notebook: OS2.HWND;
                       VAR (*OUT*) PageID: CARDINAL): OS2.HWND;

    (* Creates page 1 and adds it to the notebook. *)

    CONST
        id_timer = 1;
        updateinterval = 250;

    VAR Label: ARRAY [0..31] OF CHAR;

    BEGIN
        notebookhandle := notebook;
        hwndParent := OS2.WinQueryWindow (notebook, OS2.QW_PARENT);
        pagehandle := OS2.WinLoadDlg(notebook, notebook,
                       DialogueProc,    (* dialogue procedure *)
                       0,                   (* use resources in EXE *)
                       DID.ClockPage,                (* dialogue ID *)
                       NIL);                 (* creation parameters *)
        OurPageID := OS2.ULONGFROMMR (OS2.WinSendMsg (notebook, OS2.BKM_INSERTPAGE,
                         NIL,
                         OS2.MPFROM2SHORT (OS2.BKA_MAJOR+OS2.BKA_AUTOPAGESIZE,
                                           OS2.BKA_FIRST)));
        PageID := OurPageID;
        OurWindow := pagehandle;
        Label := "Clock";
        OS2.WinSendMsg (notebook, OS2.BKM_SETTABTEXT,
                        CAST(ADDRESS,PageID), ADR(Label));
        OS2.WinSendMsg (notebook, OS2.BKM_SETPAGEWINDOWHWND,
                        CAST(ADDRESS,PageID), CAST(ADDRESS,pagehandle));
        OS2.WinSetWindowPos (pagehandle, 0, 0, 0, 0, 0, OS2.SWP_MOVE);

        OS2.WinStartTimer (OurHab(), pagehandle, id_timer, updateinterval);

        RETURN pagehandle;
    END CreatePage;

(**************************************************************************)

PROCEDURE SetINIFileName (name: ARRAY OF CHAR);

    (* Sets the INI file name. *)

    BEGIN
        Strings.Assign (name, INIFileName);
    END SetINIFileName;

(**************************************************************************)
(*                       DISPLAYING DATE AND TIME                         *)
(**************************************************************************)

BEGIN
    TimerMethod := useWM_TIMER;
    ChangeInProgress := FALSE;
    WatchLevel := 0;

    OldLanguage := '?';
    OldDateFormat := '?';
    OldTimeFormat := '?';

    LastDateTime.day := CHR(0);
    LastDateTime.hours := CHR(25);
    LastDateTime.minutes := CHR(60);
    LastDateTime.seconds := CHR(60);

END ClockPage.

