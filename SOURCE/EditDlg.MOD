(**************************************************************************)
(*                                                                        *)
(*  Clock utility - dialogue to edit date/time                            *)
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

IMPLEMENTATION MODULE EditDlg;

        (************************************************************)
        (*                                                          *)
        (*               Clock clock setting utility                *)
        (*             Dialogue to edit a date and time             *)
        (*                                                          *)
        (*    Started:        1 September 2020                      *)
        (*    Last edited:    30 September 2020                     *)
        (*    Status:         Working                               *)
        (*                                                          *)
        (************************************************************)

IMPORT OS2, DID, INIData, Strings, CommonSettings;

FROM SYSTEM IMPORT
    (* type *)  CARD16, INT16;

FROM CommonSettings IMPORT
    (* type *)  FontGroup,
    (* proc *)  AddToGroup, SetFontsForGroup;

FROM Languages IMPORT
    (* type *)  LangHandle,
    (* proc *)  StrToBuffer;

FROM Names IMPORT
    (* type *)  FilenameString;

(**************************************************************************)

TYPE
    datepart = (day, month, year);
    dsppos = [1..3];

VAR
    Is12hr, IsPM, ChangeInProgress: BOOLEAN;
    pagehandle: OS2.HWND;
    ININame: FilenameString;
    OurLang: LangHandle;
    dtdisplay: ARRAY datepart OF dsppos;
    dtfield: ARRAY datepart OF CARDINAL;
    DateLabel: ARRAY dsppos OF ARRAY [0..4] OF CHAR;
    dateseparator: ARRAY [0..1] OF CHAR;

(************************************************************************)
(*              WORKING OUT ORDER OF YEAR-MONTH-DAY FIELDS              *)
(************************************************************************)

PROCEDURE SetDateOrder (dateformat: ARRAY OF CHAR);

    (* Uses the date format to work out the display order of dates. *)
    (* Also sets global variable dateseparator.                     *)

    VAR fpos: ARRAY datepart OF CARDINAL;
        j: dsppos;
        k: datepart;
        m, m2: CARDINAL;
        separator: CHAR;
        found, found2: BOOLEAN;

    BEGIN
        (* Work out the date separator. *)

        Strings.FindNext ("/", dateformat, 0, found, m);
        Strings.FindNext ("-", dateformat, 0, found2, m2);
        IF found THEN
            separator := '/';
            IF found2 AND (m2 < m) THEN
                separator := '-';
            END (*IF*);
        ELSIF found2 THEN
            separator := '-';
        ELSE
            separator := ' ';
        END (*IF*);
        dateseparator[0] := separator;
        dateseparator[1] := CHR(0);

        (* Fill in the fpos array. *)

        Strings.FindNext ("yy", dateformat, 0, found, fpos[year]);
        IF NOT found THEN fpos[year] := MAX(CARDINAL) END(*IF*);
        Strings.FindNext ("mm", dateformat, 0, found, fpos[month]);
        IF NOT found THEN fpos[month] := MAX(CARDINAL) END(*IF*);
        Strings.FindNext ("dd", dateformat, 0, found, fpos[day]);
        IF found THEN

            (* Special case: ignore "ddd" entries. *)

            m := fpos[day]+2;
            IF dateformat[m] = 'd' THEN
                Strings.FindNext ("dd", dateformat, m, found, fpos[day]);
            END (*IF*)

        END (*IF*);
        IF NOT found THEN fpos[day] := MAX(CARDINAL) END(*IF*);

        (* Use this to assign a display order. *)

        IF fpos[year] < fpos[month] THEN
            (* year before month *)
            IF fpos[month] < fpos[day] THEN
                (* yyyy-mm-dd *)
                dtdisplay[year] := 1;
                dtdisplay[month] := 2;
                dtdisplay[day] := 3;
            ELSE
                (* dd-yyyy-mm or yyyy-dd-mm *)
                IF fpos[day] < fpos[year] THEN
                    (* dd-yyyy-mm *)
                    dtdisplay[year] := 2;
                    dtdisplay[month] := 3;
                    dtdisplay[day] := 1;
                ELSE
                    (* yyyy-dd-mm *)
                    dtdisplay[year] := 1;
                    dtdisplay[month] := 3;
                    dtdisplay[day] := 2;
                END (*IF*);
            END (*IF*);
        ELSE
            (* month before year *)
            IF fpos[day] < fpos[month] THEN
                (* dd-mm-yyyy *)
                dtdisplay[year] := 3;
                dtdisplay[month] := 2;
                dtdisplay[day] := 1;
            ELSE
                (* mm-dd-yyyy or mm-yyyy-dd *)
                IF fpos[day] < fpos[year] THEN
                    (* mm-dd-yyyy *)
                    dtdisplay[year] := 3;
                    dtdisplay[month] := 1;
                    dtdisplay[day] := 2;
                ELSE
                    (* mm-yyyy-dd *)
                    dtdisplay[year] := 2;
                    dtdisplay[month] := 1;
                    dtdisplay[day] := 3;
                END (*IF*);
            END (*IF*);
        END (*IF*);

        (* Use this order to set the labels. *)

        DateLabel[dtdisplay[year]] := "yyyy";
        DateLabel[dtdisplay[month]] := "mm";
        DateLabel[dtdisplay[day]] := "dd";

        (* The dtfield array is, in effect, the inverse of dtdisplay. *)

        FOR k := day TO year DO
            j := dtdisplay[k];
            IF j = 1 THEN dtfield[k] := DID.EDval1;
            ELSIF j = 2 THEN dtfield[k] := DID.EDval2;
            ELSE dtfield[k] := DID.EDval3;
            END (*IF*);
        END (*FOR*);

    END SetDateOrder;

(************************************************************************)
(*                    OPERATIONS ON DIALOGUE LABELS                     *)
(************************************************************************)

PROCEDURE SetLanguage (OurPageHandle: OS2.HWND;  lang: LangHandle);

    (* Relabels this page in the new language. *)

    VAR stringval: ARRAY [0..511] OF CHAR;

    BEGIN
        StrToBuffer (lang, "EditDlg.Title", stringval);
        OS2.WinSetWindowText (OurPageHandle, stringval);
        StrToBuffer (lang, "Buttons.OK", stringval);
        OS2.WinSetDlgItemText (OurPageHandle, DID.EditOK, stringval);
        StrToBuffer (lang, "Buttons.Cancel", stringval);
        OS2.WinSetDlgItemText (OurPageHandle, DID.EditCancel, stringval);
    END SetLanguage;

(**************************************************************************)
(*                   LOADING AND STORING INI DATA                         *)
(**************************************************************************)

PROCEDURE ShowCard2 (hwnd: OS2.HWND;  ID, val: CARDINAL);

    (* Displays val as a two-digit decimal number. *)

    VAR tval: ARRAY [0..2] OF CHAR;

    BEGIN
        IF val > 9 THEN
            tval[0] := CHR(val DIV 10 + ORD('0'));
            val := val MOD 10;
        ELSE
            tval[0] := '0';
        END (*IF*);
        tval[1] := CHR(val + ORD('0'));
        tval[2] := CHR(0);
        OS2.WinSetDlgItemText (hwnd, ID, tval);
    END ShowCard2;

(**************************************************************************)

PROCEDURE InitialDisplay (hwnd: OS2.HWND);

    (* Fills in the dialogue values from the current date/time.  *)

    VAR dt: OS2.DATETIME;

    BEGIN
        OS2.WinSetDlgItemText (hwnd, DID.EDlabel1, DateLabel[1]);
        OS2.WinSetDlgItemText (hwnd, DID.EDlabel2, DateLabel[2]);
        OS2.WinSetDlgItemText (hwnd, DID.EDlabel3, DateLabel[3]);

        OS2.WinSetDlgItemText (hwnd, DID.sep1, dateseparator);
        OS2.WinSetDlgItemText (hwnd, DID.sep2, dateseparator);

        OS2.DosGetDateTime (dt);
        OS2.WinSetDlgItemShort (hwnd, dtfield[year], VAL (CARD16, dt.year), FALSE);
        ShowCard2 (hwnd, dtfield[month], ORD(dt.month));
        ShowCard2 (hwnd, dtfield[day], ORD(dt.day));

        ShowCard2 (hwnd, DID.EDvalHH, ORD(dt.hours));
        ShowCard2 (hwnd, DID.EDvalMM, ORD(dt.minutes));
        ShowCard2 (hwnd, DID.EDvalSS, ORD(dt.seconds));
        OS2.WinShowWindow (OS2.WinWindowFromID (hwnd, DID.ampmb), FALSE);
        OS2.WinSendDlgItemMsg (hwnd, DID.h24, OS2.BM_SETCHECK,
                                 OS2.MPFROMSHORT(ORD(TRUE)), NIL);
    END InitialDisplay;

(************************************************************************)

PROCEDURE CommitChanges (hwnd: OS2.HWND);

    (* Stores the updated values as the current date and time.  *)

    VAR hour, val: INT16;
        dt: OS2.DATETIME;

    BEGIN
        (* Read hour, convert to 24-hour time if necessary. *)

        OS2.WinQueryDlgItemShort(hwnd, DID.EDvalHH, hour, FALSE);
        IF Is12hr THEN
            IF hour = 12 THEN
                IF NOT IsPM THEN
                    hour := 0;
                END(*IF*);
            ELSIF IsPM THEN
                INC (hour, 12);
            END (*IF*);
        END (*IF*);
        IF hour > 23 THEN DEC(hour, 24) END (*IF*);

        (* Read current date/time, to preserve the time zone, and then  *)
        (* fill in all the values.                                      *)

        OS2.DosGetDateTime (dt);
        dt.hours := CHR(hour);

        (* Fill in date.  The dtfield array takes care of the fact that *)
        (* we have different field orders for different users.          *)

        OS2.WinQueryDlgItemShort(hwnd, dtfield[year], val, FALSE);
        dt.year := val;
        OS2.WinQueryDlgItemShort(hwnd, dtfield[month], val, FALSE);
        dt.month := CHR(val);
        OS2.WinQueryDlgItemShort(hwnd, dtfield[day], val, FALSE);
        dt.day := CHR(val);

        (* Fill in minutes and seconds.  *)

        OS2.WinQueryDlgItemShort(hwnd, DID.EDvalMM, val, FALSE);
        dt.minutes := CHR(val);
        OS2.WinQueryDlgItemShort(hwnd, DID.EDvalSS, val, FALSE);
        dt.seconds := CHR(val);

        OS2.DosSetDateTime (dt);

    END CommitChanges;

(************************************************************************)

PROCEDURE LabelAMPM (hwnd: OS2.HWND);

    (* Set the label on the AM/PM button to agree with IsPM.    *)

    BEGIN
        IF IsPM THEN
            OS2.WinSetDlgItemText (hwnd, DID.ampmb, "PM");
        ELSE
            OS2.WinSetDlgItemText (hwnd, DID.ampmb, "AM");
        END (*IF*);
    END LabelAMPM;

(************************************************************************)

PROCEDURE Set12hr (hwnd: OS2.HWND;  to12: BOOLEAN);

    (* Sets the time to either the 12-hour or 24-hour convention.  *)

    VAR hour: INT16;
        tag : ARRAY [0..2] OF CHAR;

    BEGIN
        OS2.WinQueryDlgItemShort(hwnd, DID.EDvalHH, hour, FALSE);
        IF to12 THEN
            IF hour < 12 THEN tag := "AM";
            ELSE tag := "PM";
            END (*IF*);
            OS2.WinSetDlgItemText (hwnd, DID.ampmb, tag);
            IsPM := hour >= 12;
            LabelAMPM (hwnd);
            OS2.WinShowWindow (OS2.WinWindowFromID(hwnd, DID.ampmb), TRUE);
            IF hour = 0 THEN hour := 12;
            ELSIF hour > 12 THEN DEC (hour, 12);
            END (*IF*);
        ELSE
            IF hour = 12 THEN
                IF NOT IsPM THEN
                    hour := 0;
                END(*IF*);
            ELSIF IsPM THEN
                INC (hour, 12);
            END (*IF*);
            IF hour > 23 THEN DEC(hour, 24) END (*IF*);
            OS2.WinShowWindow (OS2.WinWindowFromID(hwnd, DID.ampmb), FALSE);
        END (*IF*);
        Is12hr := to12;
        OS2.WinSetDlgItemShort (hwnd, DID.EDvalHH, hour, FALSE);
    END Set12hr;

(************************************************************************)
(*                       THE DIALOGUE PROCEDURE                         *)
(************************************************************************)

PROCEDURE DeclareWindows (hwnd: OS2.HWND);

    (* Tells module CommonSettings which windows belong to which group. *)

    BEGIN
        AddToGroup (EditDlg, hwnd, 0);
        AddToGroup (EditDlg, hwnd, DID.EditOK);
        AddToGroup (EditDlg, hwnd, DID.EDlabel1);
        AddToGroup (EditDlg, hwnd, DID.EDlabel2);
        AddToGroup (EditDlg, hwnd, DID.EDlabel3);
        AddToGroup (EditDlg, hwnd, DID.EDlabel4);
        AddToGroup (EditDlg, hwnd, DID.EDlabel5);
        AddToGroup (EditDlg, hwnd, DID.EDlabel6);
        AddToGroup (EditDlg, hwnd, DID.EditCancel);
        AddToGroup (EditDlg, hwnd, DID.ampmb);
        AddToGroup (EditDlg, hwnd, DID.h12);
        AddToGroup (EditDlg, hwnd, DID.h24);
        AddToGroup (EditDlg, hwnd, DID.EDval1);
        AddToGroup (EditDlg, hwnd, DID.EDval2);
        AddToGroup (EditDlg, hwnd, DID.EDval3);
        AddToGroup (EditDlg, hwnd, DID.EDvalHH);
        AddToGroup (EditDlg, hwnd, DID.EDvalMM);
        AddToGroup (EditDlg, hwnd, DID.EDvalSS);
    END DeclareWindows;

(**************************************************************************)

PROCEDURE ["SysCall"] DialogueProc(hwnd     : OS2.HWND;
                                     msg    : OS2.ULONG;
                                     mp1, mp2 : OS2.MPARAM): OS2.MRESULT;

    (* Message handler for the edit dialogue. *)

    VAR
        NotificationCode, ButtonID: CARDINAL;
        label: ARRAY [0..255] OF CHAR;

    BEGIN
        NotificationCode := OS2.ULONGFROMMP(mp1);
        ButtonID := NotificationCode MOD 65536;
        NotificationCode := NotificationCode DIV 65536;

        CASE msg OF
           |  OS2.WM_INITDLG:
                    label := "EditDlg";
                    CommonSettings.SetInitialWindowPosition (hwnd, EditDlg);
                    DeclareWindows (hwnd);
                    SetFontsForGroup (CommonSettings.EditDlg);
                    SetLanguage (hwnd, OurLang);
                    InitialDisplay (hwnd);
                    RETURN NIL;

           | OS2.WM_PRESPARAMCHANGED:

               IF ChangeInProgress THEN
                   RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
               ELSE
                   ChangeInProgress := TRUE;
                   CommonSettings.UpdateFontFrom (hwnd, CommonSettings.EditDlg);
                   ChangeInProgress := FALSE;
                   RETURN NIL;
               END (*IF*);

           | OS2.WM_CONTROL:
                    IF NotificationCode = OS2.BN_CLICKED THEN
                        IF ButtonID = DID.h12 THEN
                            Set12hr (hwnd, TRUE);
                            RETURN NIL;
                        ELSIF ButtonID = DID.h24 THEN
                            Set12hr (hwnd, FALSE);
                            RETURN NIL;
                        END (*IF*);
                    END (*IF*);
                    RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);

           |  OS2.WM_COMMAND:
                    IF ButtonID = DID.EditOK THEN
                        CommitChanges (hwnd);
                        OS2.WinPostMsg (hwnd, OS2.WM_CLOSE, NIL, NIL);
                        RETURN NIL;
                    ELSIF ButtonID = DID.EditCancel THEN
                        OS2.WinPostMsg (hwnd, OS2.WM_CLOSE, NIL, NIL);
                        RETURN NIL;
                    ELSIF ButtonID = DID.ampmb THEN
                        IsPM := NOT IsPM;
                        LabelAMPM (hwnd);
                        RETURN NIL;
                    ELSE
                        RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
                    END (*IF*);

           |  OS2.WM_CLOSE:
                    label := "EditDlg";
                    CommonSettings.StoreWindowPosition (hwnd, EditDlg);
                    RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);

        ELSE    (* default *)
            RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
        END (*CASE*);

    END DialogueProc;

(************************************************************************)

PROCEDURE Edit (owner: OS2.HWND;  lang: LangHandle;  dateformat: ARRAY OF CHAR);

    (* Allows the user to modify date and time.  *)

    BEGIN
        OurLang := lang;
        SetDateOrder (dateformat);
        pagehandle := OS2.WinDlgBox(OS2.HWND_DESKTOP, owner,
                       DialogueProc,    (* dialogue procedure *)
                       0,                   (* use resources in EXE *)
                       DID.EditDlg,                (* dialogue ID *)
                       NIL);                 (* creation parameters *)

        OS2.WinProcessDlg(pagehandle);
        OS2.WinDestroyWindow (pagehandle);

    END Edit;

(************************************************************************)

PROCEDURE SetININame (name: ARRAY OF CHAR);

    (* Sets the name of the INI file. *)

    BEGIN
        Strings.Assign (name, ININame);
    END SetININame;

(************************************************************************)

BEGIN
    Is12hr := FALSE;  IsPM := FALSE;
    ChangeInProgress := FALSE;
END EditDlg.

