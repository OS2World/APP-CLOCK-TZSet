(**************************************************************************)
(*                                                                        *)
(*  NuClock utility                                                       *)
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

IMPLEMENTATION MODULE ZonePage;

        (****************************************************************)
        (*                                                              *)
        (*                         NuClock utility                      *)
        (*                       The time zone page                     *)
        (*                                                              *)
        (*    Started:        10 August 2020                            *)
        (*    Last edited:    30 September 2020                         *)
        (*    Status:         Still tweaking                            *)
        (*                                                              *)
        (****************************************************************)


IMPORT Conversions, PMInit;    (* while debugging *)

FROM SYSTEM IMPORT ADDRESS, CARD8, INT16, CAST, ADR;

IMPORT OS2, OS2RTL, CommonSettings;

IMPORT DID, Strings;

FROM CommonSettings IMPORT
    (* type *)  FontGroup,
    (* proc *)  AddToGroup;

FROM DateTime IMPORT
    (* type *)  RawInfoType, CookedInfoType;

FROM ClockPage IMPORT
    (* proc *)  SetWatch;

FROM TZops IMPORT
    (* proc *)  UpdateTZinfo, GetZoneInfo, TimeToNextChange;

FROM INIData IMPORT
    (* type *)  HINI,
    (* proc *)  OpenINIFile, INIValid, CloseINIFile, INIGet, INIPut,
                INIGetString, INIPutString, INIDeleteKey;

FROM Languages IMPORT
    (* type *)  LangHandle,
    (* proc *)  StrToBuffer, StrToBufferA, StrToBufferN, StrToBufferAN;

FROM MiscFuncs IMPORT
    (* proc *)  EVAL;

FROM FileOps IMPORT
    (* type *)  ChanId,
    (* proc *)  OpenOldFile, OpenNewFile, CloseFile, DeleteFile, MoveFile,
                ReadLine, FWriteString, FWriteLn;

FROM Names IMPORT
    (* type *)  FilenameString;

(**************************************************************************)

CONST
    Nul = CHR(0);  CtrlZ = CHAR(26);

TYPE
    DirectoryString = ARRAY [0..511] OF CHAR;
    TZStringType = ARRAY [0..128] OF CHAR;
    TZSptr = POINTER TO TZStringType;

VAR
    INIFileName: FilenameString;

    pagehandle, notebookhandle, hwndParent: OS2.HWND;
    OurPageID: CARDINAL;
    ourlanguage: LangHandle;

    RawTZdata: RawInfoType;
    ChangeInProgress: BOOLEAN;
    TZisValid, SummerNow: BOOLEAN;
    OldTZString, TZString: TZStringType;
    oldunit: [0..3];

    (* info holds the data for summer start and end. *)

    info: CookedInfoType;

(************************************************************************)
(*         NOTIFYING THAT SUMMER TIME HAS JUST STARTED OR ENDED         *)
(************************************************************************)

PROCEDURE NotifyMajorChange;

    VAR adjust: INTEGER;

    BEGIN
        adjust := RawTZdata^.correction;
        IF NOT SummerNow THEN
            (* We have just passed into winter time. *)
            adjust := -adjust;
        END (*IF*);
        OS2.WinPostMsg (hwndParent, CommonSettings.ADJUSTCLOCK,
                               OS2.MPFROMLONG(adjust), OS2.MPFROMLONG(0));
    END NotifyMajorChange;

(************************************************************************)
(*                          DISPLAYING RESULTS                          *)
(************************************************************************)

PROCEDURE UpdateTZerrmes;

    (* Displays the field that says whether the current TZString is valid. *)

    VAR stringval: ARRAY [0..511] OF CHAR;

    BEGIN
        IF TZisValid THEN
            stringval := "";
        ELSE
            StrToBuffer (ourlanguage, "ZonePage.TZerror", stringval);
        END (*IF*);
        OS2.WinSetDlgItemText (pagehandle, DID.TZerror, stringval);
    END UpdateTZerrmes;

(************************************************************************)

PROCEDURE ShowZoneInfo (hwnd: OS2.HWND);    FORWARD;

(************************************************************************)

PROCEDURE TimeToNext;

    (* Displays the time to next time zone change. *)

    VAR nextchange, unit: CARDINAL;
        stringval: ARRAY [0..511] OF CHAR;
        unitstr: ARRAY [0..31] OF CHAR;

    BEGIN
        TimeToNextChange (info, nextchange, unit);
        IF nextchange = 0 THEN
            ShowZoneInfo (pagehandle);
            SummerNow := NOT SummerNow;
            NotifyMajorChange;
            SetWatch (0);
        ELSE
            IF unit <> oldunit THEN
                SetWatch (unit);
            END (*IF*);
            IF unit = 0 THEN
                StrToBuffer (ourlanguage, "days", unitstr);
            ELSIF unit = 1 THEN
                StrToBuffer (ourlanguage, "hours", unitstr);
            ELSIF unit = 2 THEN
                StrToBuffer (ourlanguage, "minutes", unitstr);
            ELSE
                StrToBuffer (ourlanguage, "seconds", unitstr);
            END (*IF*);
            oldunit := unit;
            StrToBufferAN (ourlanguage, "ZonePage.nextchange",
                                        unitstr, nextchange, stringval);
            OS2.WinSetDlgItemText (pagehandle, DID.nextchange, stringval);
        END (*IF*);
    END TimeToNext;

(************************************************************************)

PROCEDURE ShowZoneInfo (hwnd: OS2.HWND);

    (* Displays when summer time starts and ends *)

    VAR stringval, param, SummerStart, SummerEnd: ARRAY [0..511] OF CHAR;
        SummerNow: BOOLEAN;

    BEGIN
        GetZoneInfo (RawTZdata, info, param, SummerStart, SummerEnd);
        StrToBufferA (ourlanguage, "ZonePage.YourZone", param, stringval);
        OS2.WinSetDlgItemText (hwnd, DID.YTZ, stringval);
        IF info^.NoSummerTime THEN
            StrToBuffer (ourlanguage, "ZonePage.NoSummerTime", stringval);
            OS2.WinSetDlgItemText (pagehandle, DID.YouAreOn, stringval);
            stringval := "";
            OS2.WinSetDlgItemText (pagehandle, DID.switch1, stringval);
            OS2.WinSetDlgItemText (pagehandle, DID.switch2, stringval);
            OS2.WinSetDlgItemText (pagehandle, DID.nextchange, stringval);
        ELSE
            SummerNow := info^.InSummerTime;
            IF SummerNow THEN
                StrToBuffer (ourlanguage, "ZonePage.SummerNow", stringval);
            ELSE
                StrToBuffer (ourlanguage, "ZonePage.WinterNow", stringval);
            END (*IF*);
            OS2.WinSetDlgItemText (pagehandle, DID.YouAreOn, stringval);

            StrToBufferA (ourlanguage, "ZonePage.SummerStarts", SummerStart, stringval);
            IF SummerNow THEN
                OS2.WinSetDlgItemText (pagehandle, DID.switch2, stringval);
            ELSE
                OS2.WinSetDlgItemText (pagehandle, DID.switch1, stringval);
            END (*IF*);

            StrToBufferA (ourlanguage, "ZonePage.SummerEnds", SummerEnd, stringval);
            IF SummerNow THEN
                OS2.WinSetDlgItemText (pagehandle, DID.switch1, stringval);
            ELSE
                OS2.WinSetDlgItemText (pagehandle, DID.switch2, stringval);
            END (*IF*);

            (* Time to next time zone change. *)

            TimeToNext;

        END (*IF*);

    END ShowZoneInfo;

(************************************************************************)

PROCEDURE RecomputeTimeZone;

    (* Called when there is a possibility that we have moved into or    *)
    (* out of summer time.  Forces a display update if necessary.       *)

    BEGIN
        ShowZoneInfo (pagehandle);
    END RecomputeTimeZone;

(************************************************************************)

PROCEDURE SetLanguage (lang: LangHandle);

    (* Relabels this page in the new language. *)

    VAR stringval: ARRAY [0..511] OF CHAR;

    BEGIN
        ourlanguage := lang;
        StrToBuffer (lang, "ZonePage.tab", stringval);
        OS2.WinSendMsg (notebookhandle, OS2.BKM_SETTABTEXT,
                        CAST(ADDRESS,OurPageID), ADR(stringval));
        UpdateTZerrmes;
        ShowZoneInfo (pagehandle);
    END SetLanguage;

(************************************************************************)
(*                     LOADING DATA FROM THE INI FILE                   *)
(************************************************************************)

PROCEDURE LoadValues (hwnd: OS2.HWND);

    (* Fills the dialogue elements on page 1 with data from the INI file,       *)
    (* or loads default values if they're not in the INI file.                  *)

    VAR opened: BOOLEAN;
        rc: CARDINAL;
        hini: HINI;
        p: OS2.PCSZ;
        q: TZSptr;

    BEGIN
        (* First fetch the TZ environment variable. *)

        rc := OS2.DosScanEnv ("TZ", p);
        IF rc = 0 THEN
            q := CAST (TZSptr, p);
            Strings.Assign (q^, OldTZString);
        ELSE
            OldTZString := "";
        END (*IF*);
        TZString := OldTZString;
        OS2.WinSetDlgItemText (hwnd, DID.TZ, TZString);
        TZisValid := UpdateTZinfo (TZString, RawTZdata);

        (* Now the INI file data. *)

        hini := OpenINIFile (INIFileName);
        opened := INIValid (hini);

        IF opened THEN
            CloseINIFile(hini);
        END (*IF*);

    END LoadValues;

(************************************************************************)

PROCEDURE StoreRawData (hini: HINI);

    (* Stores the data that TZmon will need. *)

    VAR app: ARRAY [0..5] OF CHAR;

    BEGIN
        app := "TZRaw";
        WITH RawTZdata^ DO
            INIPut (hini, app, "StartRaw", StartRaw);
            INIPut (hini, app, "EndRaw", EndRaw);
            INIPut (hini, app, "BaseTimeZone", BaseZone);
            INIPut (hini, app, "SummerAdjust", correction);
        END (*WITH*);
    END StoreRawData;

(************************************************************************)
(*                 STORING NEW TZ STRING TO CONFIG.SYS                  *)
(************************************************************************)

PROCEDURE StoreTZ;

    (* Stores TZ string as the new value of TZ in CONFIG.SYS.  *)

    VAR line: ARRAY [0..512] OF CHAR;
        j: CARDINAL;

    (********************************************************************)

    PROCEDURE Match (pattern: ARRAY OF CHAR): BOOLEAN;

        VAR k: CARDINAL;

        BEGIN
            k := 0;
            LOOP
                IF pattern[k] = Nul THEN
                    RETURN TRUE;
                END (*IF*);
                IF CAP(line[j]) <> pattern[k] THEN
                    RETURN FALSE;
                END (*IF*);
                INC (j);  INC(k);
            END (*LOOP*);
        END Match;

    (********************************************************************)

    VAR incid, outcid: ChanId;
        configname, tmpname, bakname: ARRAY [0..15] OF CHAR;
        drive: CARDINAL;

    BEGIN
        (* Find the system drive, and set file names appropriately. *)

        drive := 3;
        OS2.DosQuerySysInfo (5, 5, ADR(drive), SIZE(drive));
        configname[0] := CHR(ORD('A')+drive-1);
        configname[1] := ':';
        configname[2] := '\';
        configname[3] := Nul;
        Strings.Append ("CONFIG.", configname);
        Strings.Assign (configname, tmpname);
        Strings.Assign (configname, bakname);
        Strings.Append ("SYS", configname);
        Strings.Append ("###", tmpname);
        Strings.Append ("BAK", bakname);

        DeleteFile (tmpname);
        incid := OpenOldFile (configname, TRUE, FALSE);
        outcid := OpenNewFile (tmpname, FALSE);
        LOOP
            ReadLine (incid, line);
        OS2.WinSetDlgItemText (pagehandle, DID.TZerror, line);
            IF line[0] = CtrlZ THEN
                EXIT (*LOOP*);
            END (*IF*);

            (* Look for a line of the form SET TZ=...  *)

            j := 0;
            WHILE line[j] = ' ' DO INC(j) END (*WHILE*);
            IF Match ("SET ") THEN
                WHILE line[j] = ' ' DO INC(j) END (*WHILE*);
            END (*IF*);
            IF Match ("TZ") THEN
                WHILE line[j] = ' ' DO INC(j) END (*WHILE*);
            END (*IF*);
            IF line[j] = '=' THEN
                (* We have a match.  Replace this line. *)
                Strings.Assign ("SET TZ=", line);
                Strings.Append (TZString, line);
                (*OS2.WinSetDlgItemText (pagehandle, DID.TZerror, line);*)
            END (*IF*);

            FWriteString (outcid, line);
            FWriteLn (outcid);

        END (*LOOP*);

        CloseFile (outcid);
        CloseFile (incid);

        DeleteFile (bakname);
        IF MoveFile (configname, bakname) THEN
            EVAL (MoveFile (tmpname, configname));
        END (*IF*);

    END StoreTZ;

(************************************************************************)
(*                    STORING DATA TO THE INI FILE                      *)
(************************************************************************)

PROCEDURE StoreData (hwnd: OS2.HWND): BOOLEAN;

    (* Stores the values on page 1 back into the INI file.  Returns     *)
    (* TRUE if checks for start/end of summer time will still be needed.*)

    VAR opened: BOOLEAN;
        hini: HINI;

    BEGIN
        IF TZisValid AND NOT Strings.Equal (TZString, OldTZString) THEN
            StoreTZ;
        END (*IF*);

        hini := OpenINIFile (INIFileName);
        opened := INIValid (hini);

        IF opened THEN
            CloseINIFile(hini);
        END (*IF*);

        IF info = NIL THEN
            RETURN FALSE;
        ELSE
            RETURN NOT info^.NoSummerTime;
        END (*IF*);

    END StoreData;

(************************************************************************)
(*                        DIALOGUE PROCEDURE                            *)
(************************************************************************)

PROCEDURE DeclareWindows (hwnd: OS2.HWND);

    (* Tells module CommonSettings which windows belong to which group. *)

    BEGIN
        AddToGroup (MainDlg, hwnd, 0);
        AddToGroup (MainDlg, hwnd, DID.TZ);
        AddToGroup (MainDlg, hwnd, DID.TZlabel);
        AddToGroup (MainDlg, hwnd, DID.TZerror);
        AddToGroup (MainDlg, hwnd, DID.YTZ);
        AddToGroup (MainDlg, hwnd, DID.YouAreOn);
        AddToGroup (MainDlg, hwnd, DID.switch1);
        AddToGroup (MainDlg, hwnd, DID.switch2);
        AddToGroup (MainDlg, hwnd, DID.nextchange);
    END DeclareWindows;

(**************************************************************************)

PROCEDURE ["SysCall"] DialogueProc (hwnd: OS2.HWND;  msg: OS2.ULONG;
                                      mp1, mp2: OS2.MPARAM): OS2.MRESULT;

    VAR ButtonID, NotificationCode: CARDINAL;

    BEGIN
        IF msg = OS2.WM_INITDLG THEN

            DeclareWindows (hwnd);
            LoadValues (hwnd);
            RETURN NIL;

        ELSIF msg = OS2.WM_PRESPARAMCHANGED THEN

            IF ChangeInProgress THEN
                RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
            ELSE
                ChangeInProgress := TRUE;
                CommonSettings.UpdateFontFrom (hwnd, CommonSettings.MainDlg);
                ChangeInProgress := FALSE;
                RETURN NIL;
            END (*IF*);

        ELSIF msg = OS2.WM_CONTROL THEN

            NotificationCode := OS2.ULONGFROMMP(mp1);
            ButtonID := NotificationCode MOD 65536;
            NotificationCode := NotificationCode DIV 65536;
            IF NotificationCode = OS2.EN_CHANGE THEN
                CASE ButtonID OF
                    DID.TZ:
                        OS2.WinQueryDlgItemText (hwnd, DID.TZ, SIZE(TZString), TZString);
                        TZisValid := UpdateTZinfo (TZString, RawTZdata);
                        UpdateTZerrmes;
                        ShowZoneInfo (hwnd);
                        RETURN NIL;
                ELSE
                        RETURN OS2.WinDefDlgProc (hwnd, msg, mp1, mp2);
                END (* CASE *);

            END (*IF*);

        END (*CASE*);

        RETURN OS2.WinDefDlgProc (hwnd, msg, mp1, mp2);

    END DialogueProc;

(**************************************************************************)

PROCEDURE CreatePage (notebook: OS2.HWND;
                       VAR (*OUT*) PageID: CARDINAL): OS2.HWND;

    (* Creates page 1 and adds it to the notebook. *)

    VAR Label: ARRAY [0..31] OF CHAR;

    BEGIN
        notebookhandle := notebook;
        hwndParent := OS2.WinQueryWindow (notebook, OS2.QW_PARENT);
        pagehandle := OS2.WinLoadDlg(notebook, notebook,
                       DialogueProc,    (* dialogue procedure *)
                       0,                   (* use resources in EXE *)
                       DID.ZonePage,                (* dialogue ID *)
                       NIL);                 (* creation parameters *)
        OurPageID := OS2.ULONGFROMMR (OS2.WinSendMsg (notebook, OS2.BKM_INSERTPAGE,
                         NIL,
                         OS2.MPFROM2SHORT (OS2.BKA_MAJOR+OS2.BKA_AUTOPAGESIZE,
                                           OS2.BKA_LAST)));
        PageID := OurPageID;
        Label := "Time zone";
        OS2.WinSendMsg (notebook, OS2.BKM_SETTABTEXT,
                        CAST(ADDRESS,PageID), ADR(Label));
        OS2.WinSendMsg (notebook, OS2.BKM_SETPAGEWINDOWHWND,
                        CAST(ADDRESS,PageID), CAST(ADDRESS,pagehandle));
        OS2.WinSetWindowPos (pagehandle, 0, 0, 0, 0, 0, OS2.SWP_MOVE);
        RETURN pagehandle;
    END CreatePage;

(**************************************************************************)

PROCEDURE SetINIFileName (name: ARRAY OF CHAR);

    (* Sets the INI file name. *)

    BEGIN
        Strings.Assign (name, INIFileName);
    END SetINIFileName;

(**************************************************************************)

BEGIN
    TZisValid := FALSE;
    SummerNow := FALSE;
    RawTZdata := NIL;
    ChangeInProgress := FALSE;
    info := NIL;
END ZonePage.

