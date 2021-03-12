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

IMPLEMENTATION MODULE MainDlg;

        (************************************************************)
        (*                                                          *)
        (*                       Clock utility                      *)
        (*             The settings notebook and its frame          *)
        (*                                                          *)
        (*    Started:        10 August 2020                        *)
        (*    Last edited:    6 October 2020                        *)
        (*    Status:         OK                                    *)
        (*                                                          *)
        (************************************************************)


FROM SYSTEM IMPORT
    (* type *)  ADDRESS, CARD16,
    (* proc *)  CAST, ADR;

IMPORT OS2, OS2RTL, DID, PMInit, ClockPage, ZonePage, About, EditDlg,
            CommonSettings, Strings, INIData;

FROM CommonSettings IMPORT
    (* const*)  MainDlg;

FROM Languages IMPORT
    (* type *)  LangHandle,
    (* proc *)  StrToBuffer;

FROM LowLevel IMPORT
    (* proc *)  IAND;

FROM Names IMPORT
    (* type *)  FilenameString;

(**************************************************************************)

CONST
    Nul = CHR(0);

TYPE
    Page = (clock, zone, about);
    LanguageString = ARRAY [0..31] OF CHAR;

<* PUSH *>
<* VOLATILE+ *>

VAR
    dlghandle: OS2.HWND;
    StartingPage: Page;
    pagehandle: ARRAY Page OF OS2.HWND;
    IDofPage: ARRAY Page OF CARDINAL;
    ObservesSummerTime, ChangeInProgress: BOOLEAN;
    ININame: FilenameString;
    PageFont, TabFontName: CommonSettings.FontName;
    OurLanguage: LanguageString;
    SwitchData: OS2.SWCNTRL;     (* switch entry data *)
    rc, test: CARDINAL;

<* POP *>

(**************************************************************************)

PROCEDURE SetINIname;

    (* Informs each notebook page of the INI file name.  *)

    BEGIN
        ClockPage.SetINIFileName(ININame);
        ZonePage.SetINIFileName(ININame);
        EditDlg.SetININame(ININame);
    END SetINIname;

(**************************************************************************)

PROCEDURE SetLanguage;

    (* Changes the language of the notebook pages to the current language *)
    (* as recorded by module CommonSettings.                              *)

    VAR NewLang: LangHandle;
        NewName: LanguageString;
        stringval: ARRAY [0..255] OF CHAR;

    BEGIN
        CommonSettings.CurrentLanguage (NewLang, NewName);
        StrToBuffer (NewLang, "Main.Title", stringval);
        OS2.WinSetWindowText (dlghandle, stringval);
        IF NOT Strings.Equal(NewName, OurLanguage) THEN
            ClockPage.SetLanguage (NewLang);
            ZonePage.SetLanguage (NewLang);
            About.SetLanguage (NewLang);
            OurLanguage := NewName;
        END (*IF*);
    END SetLanguage;

(**************************************************************************)

PROCEDURE MakeNotebookNewStyle (hwnd: OS2.HWND;  NewStyle: BOOLEAN);

    (* Change to Warp 3 or Warp 4 notebook style. *)

    CONST
        OldStyleFlags = OS2.BKS_BACKPAGESBR + OS2.BKS_MAJORTABBOTTOM
                + OS2.BKS_ROUNDEDTABS + OS2.BKS_TABTEXTCENTER
                + OS2.BKS_STATUSTEXTCENTER + OS2.BKS_SPIRALBIND;
        NewStyleFlags = OS2.BKS_TABBEDDIALOG + OS2.BKS_MAJORTABTOP + OS2.BKS_BACKPAGESTR;

    VAR style: CARDINAL;

    BEGIN
        style := OS2.WinQueryWindowULong (hwnd, OS2.QWL_STYLE);
        style := IAND (style, 0FFFF0000H);
        IF NewStyle THEN
            INC (style, NewStyleFlags);
        ELSE
            INC (style, OldStyleFlags);
        END (*IF*);
        OS2.WinSetWindowULong (hwnd, OS2.QWL_STYLE, style);
    END MakeNotebookNewStyle;

(**************************************************************************)

PROCEDURE InitialiseNotebook (hwnd: OS2.HWND);

    (* hwnd is the handle of the notebook control. *)

    VAR swp: OS2.SWP;  scale: CARDINAL;
        hini: INIData.HINI;
        NewStyle: BOOLEAN;
        app: ARRAY [0..12] OF CHAR;

    BEGIN
        (* Find OS version to decide what notebook style to use. *)

        scale := 30;
        OS2.DosQuerySysInfo(12, 12, ADR(scale), SIZE(CARDINAL));
        NewStyle := scale >= 40;
        MakeNotebookNewStyle (hwnd, NewStyle);

        hini := INIData.OpenINIFile (ININame);
        app := "StartingPage";
        IF NOT INIData.INIGet (hini, app, "MainNotebook", StartingPage) THEN
            StartingPage := MIN(Page);
        END (*IF*);
        app := "Font";
        IF NOT INIData.INIGetString (hini, app, "MainDlgTabs", TabFontName) THEN
            TabFontName := "8.Helv";
        END (*IF*);
        INIData.CloseINIFile (hini);
        OS2.WinSetPresParam (hwnd, OS2.PP_FONTNAMESIZE,CommonSettings.FontNameSize, TabFontName);

        (* If the new style is enabled, the following code will have no effect *)
        (* because the messages to set tab size and colours will be ignored.   *)

        OS2.WinQueryWindowPos (hwnd, swp);
        scale := 2*swp.cx DIV 13;
        OS2.WinSendMsg (hwnd, OS2.BKM_SETDIMENSIONS,
             OS2.MPFROM2SHORT(scale,5*scale DIV 12), OS2.MPFROMSHORT(OS2.BKA_MAJORTAB));
        OS2.WinSendMsg (hwnd, OS2.BKM_SETNOTEBOOKCOLORS,
                        CAST(ADDRESS,00FFFFAAH(*0055DBFFH*)), CAST(ADDRESS,OS2.BKA_BACKGROUNDPAGECOLOR));
        OS2.WinSendMsg (hwnd, OS2.BKM_SETNOTEBOOKCOLORS,
                        CAST(ADDRESS,0080DBAAH), CAST(ADDRESS,OS2.BKA_BACKGROUNDMAJORCOLOR));

        pagehandle[clock] := ClockPage.CreatePage(hwnd, IDofPage[clock]);
        pagehandle[zone] := ZonePage.CreatePage(hwnd, IDofPage[zone]);
        About.Create (hwnd, IDofPage[about]);
        CommonSettings.SetFontsForGroup (CommonSettings.MainDlg);
        CommonSettings.SetFontsForGroup (CommonSettings.BigFont);
        SetLanguage;
        OS2.WinSendMsg (hwnd, OS2.BKM_TURNTOPAGE,
                           OS2.MPFROMULONG(IDofPage[StartingPage]), NIL);
        OS2.WinShowWindow (hwnd, TRUE);

    END InitialiseNotebook;

(**************************************************************************)
(*                WINDOW PROCEDURE FOR SUBCLASSED CASE                    *)
(**************************************************************************)

PROCEDURE ["SysCall"] SubWindowProc (hwnd     : OS2.HWND;
                                     msg      : OS2.ULONG;
                                     mp1, mp2 : OS2.MPARAM): OS2.MRESULT;

    (* Window procedure to intercept some of the things that happen in  *)
    (* the notebook subwindow.  We want this here mainly so that we can *)
    (* detect a new font dropped on the notebook tabs.  If the message  *)
    (* is something we don't want to deal with here, we pass it         *)
    (* to the parent window procedure.                                  *)

    VAR OldWndProc: OS2.PFNWP;
        owner: OS2.HWND;  hini: INIData.HINI;
        length, AttrFound: CARDINAL;
        NewFontName: CommonSettings.FontName;
        app: ARRAY [0..4] OF CHAR;

    BEGIN
        OldWndProc := CAST (OS2.PFNWP, OS2.WinQueryWindowPtr (hwnd, OS2.QWL_USER));
        owner := OS2.WinQueryWindow(hwnd,OS2.QW_OWNER);

        (* Because of the interaction between subclassing and DragText, *)
        (* some messages will go lost if we use the obvious strategy of *)
        (* sending them through to OldWndProc.  To get around this, we  *)
        (* have to send those messages directly to the target window.   *)

        IF (msg = OS2.WM_BUTTON2DOWN) OR (msg = OS2.DM_DRAGOVER)
                   OR (msg = OS2.DM_DRAGLEAVE) OR (msg = OS2.DM_DROP) THEN

            RETURN OS2.WinSendMsg (owner, msg, mp1, mp2);

        (* Check for font or colour change. *)

        ELSIF msg = OS2.WM_PRESPARAMCHANGED THEN

            IF ChangeInProgress THEN
                RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
            ELSE
                ChangeInProgress := TRUE;
                length := OS2.WinQueryPresParam (hwnd, OS2.PP_FONTNAMESIZE, 0,
                                             AttrFound, CommonSettings.FontNameSize, NewFontName,
                                              0(*OS2.QPF_NOINHERIT*));
                IF length < CommonSettings.FontNameSize THEN
                    NewFontName[length] := Nul;
                END (*IF*);

                IF NOT Strings.Equal (NewFontName, TabFontName) THEN
                    TabFontName := NewFontName;
                    hini := INIData.OpenINIFile (ININame);
                    app := "Font";
                    INIData.INIPutString (hini, app, "MainDlgTabs", TabFontName);
                    INIData.CloseINIFile (hini);
                    OS2.WinSetPresParam (hwnd, OS2.PP_FONTNAMESIZE,CommonSettings.FontNameSize, TabFontName);
                END (*IF*);
                ChangeInProgress := FALSE;
                RETURN NIL;
            END (*IF*);

        END (*IF*);

        RETURN OldWndProc (hwnd, msg, mp1, mp2);

    END SubWindowProc;

(**************************************************************************)
(*                   WINDOW PROCEDURE FOR MAIN DIALOGUE                   *)
(**************************************************************************)

PROCEDURE ["SysCall"] MainDialogueProc(hwnd     : OS2.HWND
                     ;msg      : OS2.ULONG
                     ;mp1, mp2 : OS2.MPARAM): OS2.MRESULT;

    VAR bookwin: OS2.HWND;  lang: LangHandle;
        app: ARRAY [0..12] OF CHAR;
        stringval: ARRAY [0..255] OF CHAR;
        pageID: CARDINAL;  pg: Page;
        hini: INIData.HINI;

    BEGIN
        CASE msg OF
           |  OS2.WM_INITDLG:
                   CommonSettings.SetInitialWindowPosition (hwnd, MainDlg);
                   CommonSettings.CurrentLanguage (lang, stringval);
                   StrToBuffer (lang, "Main.Title", stringval);
                   OS2.WinSetWindowText (hwnd, stringval);
                   bookwin := OS2.WinWindowFromID (hwnd, DID.notebook);
                   InitialiseNotebook (bookwin);
                   OS2.WinSetWindowPtr (bookwin, OS2.QWL_USER,
                               CAST(ADDRESS,OS2.WinSubclassWindow (bookwin,
                                                           SubWindowProc)));

           |  CommonSettings.LANGCHANGED:

                   IF ChangeInProgress THEN
                       RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
                   ELSE
                       ChangeInProgress := TRUE;
                       CommonSettings.CurrentLanguage (lang, stringval);
                       SetLanguage;
                       ChangeInProgress := FALSE;
                       RETURN NIL;
                   END (*IF*);

           |  CommonSettings.TIMECHANGED:

                   IF ChangeInProgress THEN
                       RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
                   ELSE
                       ChangeInProgress := TRUE;
                       ZonePage.RecomputeTimeZone;
                       ChangeInProgress := FALSE;
                       RETURN NIL;
                   END (*IF*);

           |  CommonSettings.NEWTICK:

                   IF ChangeInProgress THEN
                       RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
                   ELSE
                       ChangeInProgress := TRUE;
                       ZonePage.TimeToNext;
                       ChangeInProgress := FALSE;
                       RETURN NIL;
                   END (*IF*);

           |  CommonSettings.ADJUSTCLOCK:

                   ClockPage.AdjustClock(OS2.LONGFROMMP(mp1));
                   RETURN NIL;

           |  OS2.WM_CLOSE:
                   bookwin := OS2.WinWindowFromID(hwnd, DID.notebook);
                   pageID := OS2.ULONGFROMMR(OS2.WinSendMsg (bookwin, OS2.BKM_QUERYPAGEID,
                                 OS2.MPFROMULONG(0),
                                  OS2.MPFROMSHORT(OS2.BKA_TOP)));
                   pg := MAX(Page);
                   WHILE (IDofPage[pg] <> pageID) AND (pg > MIN(Page)) DO
                       DEC (pg);
                   END (*WHILE*);
                   hini := INIData.OpenINIFile (ININame);
                   app := "StartingPage";
                   INIData.INIPut (hini, app, "MainNotebook", pg);

                   (* Store the data that TZmon will need. *)

                   ZonePage.StoreRawData (hini);

                   INIData.CloseINIFile (hini);
                   CommonSettings.StoreWindowPosition (hwnd, MainDlg);
                   ClockPage.StoreData (pagehandle[clock]);
                   ObservesSummerTime := ZonePage.StoreData (pagehandle[zone]);
                   OS2.WinPostMsg(hwnd, OS2.WM_QUIT, NIL, NIL);
                   RETURN NIL;

        ELSE    (* default *)
           RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
        END (*CASE*);
        RETURN NIL;
    END MainDialogueProc;

(**************************************************************************)

PROCEDURE StartSuccessor;

    (* Starts the program that is to run after this one exits. *)

    CONST monitorname = "TZset";

    VAR startdata: OS2.STARTDATA;
        idsession, id: CARDINAL;
        name: ARRAY [0..5] OF CHAR;
        pgmname: ARRAY [0..511] OF CHAR;

    BEGIN
        name := monitorname;
        INIData.OurDirectory (pgmname);
        Strings.Append ('\', pgmname);
        Strings.Append (monitorname, pgmname);
        Strings.Append (".exe", pgmname);
        WITH startdata DO
            Length := SIZE(startdata);
            Related := 0;
            FgBg := OS2.SSF_FGBG_BACK;
            TraceOpt := 0;
            PgmTitle := ADR(name);
            PgmName := ADR(pgmname);
            PgmInputs := NIL;
            TermQ := NIL;
            Environment := NIL;
            InheritOpt := OS2.SSF_INHERTOPT_PARENT;
            SessionType := OS2.SSF_TYPE_WINDOWABLEVIO;
            IconFile := NIL;
            PgmHandle := 0;
            PgmControl := OS2.SSF_CONTROL_INVISIBLE;
            InitXPos := 0;
            InitYPos := 0;
            InitXSize := 0;
            InitYSize := 0;
            Reserved := 0;
            ObjectBuffer := NIL;
            ObjectBuffLen := 0;
        END (*WITH*);
        rc := OS2.DosStartSession (startdata, idsession, id);
        test := rc;
    END StartSuccessor;

(**************************************************************************)

PROCEDURE StopSuccessor;

    (* Kills any instance of TZset that is already running. *)

    VAR semName: ARRAY [0..127] OF CHAR;
        ShutdownSignal: OS2.HEV;
        rc: CARDINAL;

    BEGIN
        semName := "\SEM32\TZSET_TERMINATE";
        ShutdownSignal := 0;
        LOOP
            rc := OS2.DosOpenEventSem (semName, ShutdownSignal);
            IF rc = OS2.ERROR_SEM_NOT_FOUND THEN
                EXIT (*LOOP*);
            END (*IF*);

            (* An instance of TZmon or TZset must be running.       *)
            (* Kill it, and don't proceed until we know that that   *)
            (* instance has closed the semaphore.                   *)

            rc := OS2.DosPostEventSem (ShutdownSignal);
            rc := OS2.DosCloseEventSem (ShutdownSignal);
            OS2.DosSleep (200);
        END (*LOOP*);
    END StopSuccessor;

(**************************************************************************)

PROCEDURE OpenMainDlg;

    (* Creates the main dialogue box. *)

    VAR pid: OS2.PID;  tid: OS2.TID;

    BEGIN
        StopSuccessor;
        ChangeInProgress := FALSE;
        dlghandle := OS2.WinLoadDlg(OS2.HWND_DESKTOP, OS2.HWND_DESKTOP,
                       MainDialogueProc,    (* dialogue procedure *)
                       0,                   (* use resources in EXE *)
                       DID.BigFrame,        (* dialogue ID *)
                       NIL);                (* creation parameters *)

        (* Put us on the visible task list.  *)

        OS2.WinQueryWindowProcess (dlghandle, pid, tid);
        SwitchData.hwnd := dlghandle;
        WITH SwitchData DO
            hwndIcon      := 0;
            hprog         := 0;
            idProcess     := pid;
            idSession     := 0;
            uchVisibility := OS2.SWL_VISIBLE;
            fbJump        := OS2.SWL_JUMPABLE;
            szSwtitle     := "NuClock";
            bProgType     := 0;
        END (*WITH*);
        OS2.WinCreateSwitchEntry (PMInit.OurHab(), SwitchData);

        OS2.WinProcessDlg(dlghandle);
        OS2.WinDestroyWindow (dlghandle);
        IF ObservesSummerTime THEN
            StartSuccessor();
        END (*IF*);

    END OpenMainDlg;

(**************************************************************************)

VAR pg: Page;

BEGIN
    ChangeInProgress := FALSE;
    ININame := "Clock.INI";
    SetINIname;
    PageFont := "";
    TabFontName := "";
    OurLanguage := "?";
    StartingPage := MIN(Page);
    FOR pg := MIN(Page) TO MAX(Page) DO
        IDofPage[pg] := 0;
    END (*FOR*);
END MainDlg.

