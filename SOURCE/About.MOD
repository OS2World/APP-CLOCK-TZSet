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

IMPLEMENTATION MODULE About;

        (****************************************************************)
        (*                                                              *)
        (*                        Clock utility                         *)
        (*                     The 'about' dialogue                     *)
        (*                                                              *)
        (*    Started:        10 August 2020                            *)
        (*    Last edited:    20 September 2020                         *)
        (*    Status:         OK                                        *)
        (*                                                              *)
        (****************************************************************)


IMPORT OS2, DID, CommonSettings, NCV;

FROM SYSTEM IMPORT
    (* type *)  ADDRESS,
    (* proc *)  CAST, ADR;

FROM CommonSettings IMPORT
    (* type *)  FontGroup,
    (* proc *)  AddToGroup;

FROM Languages IMPORT
    (* type *)  LangHandle,
    (* proc *)  StrToBuffer, StrToBufferA;

(************************************************************************)

VAR pagehandle, notebookhandle: OS2.HWND;
    OurPageID: CARDINAL;
    ChangeInProgress: BOOLEAN;

(************************************************************************)
(*                    OPERATIONS ON DIALOGUE LABELS                     *)
(************************************************************************)

PROCEDURE SetLanguage (lang: LangHandle);

    (* Relabels this page in the new language. *)

    VAR stringval: ARRAY [0..511] OF CHAR;

    BEGIN
        StrToBuffer (lang, "About.tab", stringval);
        OS2.WinSendMsg (notebookhandle, OS2.BKM_SETTABTEXT,
                        CAST(ADDRESS,OurPageID), ADR(stringval));
        StrToBuffer (lang, "About.1", stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.About1, stringval);
        StrToBufferA (lang, "About.2", NCV.version, stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.About2, stringval);
        StrToBuffer (lang, "About.3", stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.About3, stringval);
        StrToBuffer (lang, "About.4", stringval);
        OS2.WinSetDlgItemText (pagehandle, DID.About4, stringval);
    END SetLanguage;

(************************************************************************)
(*                THE DIALOGUE HANDLER FOR THIS PAGE                    *)
(************************************************************************)

PROCEDURE DeclareWindows (hwnd: OS2.HWND);

    (* Tells module CommonSettings which windows belong to which group. *)

    BEGIN
        AddToGroup (MainDlg, hwnd, 0);
        AddToGroup (MainDlg, hwnd, DID.About1);
        AddToGroup (MainDlg, hwnd, DID.About2);
        AddToGroup (MainDlg, hwnd, DID.About3);
        AddToGroup (MainDlg, hwnd, DID.About3a);
        AddToGroup (MainDlg, hwnd, DID.About3b);
        AddToGroup (MainDlg, hwnd, DID.About3c);
        AddToGroup (MainDlg, hwnd, DID.About4);
        AddToGroup (MainDlg, hwnd, DID.About5);
    END DeclareWindows;

(**************************************************************************)

PROCEDURE ["SysCall"] DialogueProc(hwnd     : OS2.HWND
                     ;msg      : OS2.ULONG
                     ;mp1, mp2 : OS2.MPARAM): OS2.MRESULT;

    (* Message handler for the 'About' dialogue. *)

    BEGIN
        IF msg = OS2.WM_INITDLG THEN
            OS2.WinSetWindowPos (hwnd, 0, 0, 0, 0, 0, OS2.SWP_MOVE);
            DeclareWindows (hwnd);
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

        ELSE
            RETURN OS2.WinDefDlgProc(hwnd, msg, mp1, mp2);
        END (*CASE*);
    END DialogueProc;

(************************************************************************)
(*                   EXTERNALLY CALLABLE PROCEDURES                     *)
(************************************************************************)

PROCEDURE Create (notebook: OS2.HWND;  VAR (*OUT*) PageID: CARDINAL);

    (* Creates the dialogue box. *)

    VAR Label: ARRAY [0..31] OF CHAR;

    BEGIN
        notebookhandle := notebook;
        pagehandle := OS2.WinLoadDlg(notebook, notebook,
                       DialogueProc,        (* dialogue procedure *)
                       0,                   (* use resources in EXE *)
                       DID.AboutPage,                (* dialogue ID *)
                       NIL);                 (* creation parameters *)

        OurPageID := OS2.ULONGFROMMR (OS2.WinSendMsg (notebook, OS2.BKM_INSERTPAGE,
                         NIL,
                         OS2.MPFROM2SHORT (OS2.BKA_MAJOR+OS2.BKA_AUTOPAGESIZE,
                                           OS2.BKA_LAST)));
        PageID := OurPageID;
        Label := "About";
        OS2.WinSendMsg (notebook, OS2.BKM_SETTABTEXT,
                        CAST(ADDRESS,PageID), ADR(Label));
        OS2.WinSendMsg (notebook, OS2.BKM_SETPAGEWINDOWHWND,
                        CAST(ADDRESS,PageID), CAST(ADDRESS,pagehandle));
        OS2.WinSetWindowPos (pagehandle, 0, 0, 0, 0, 0, OS2.SWP_MOVE);
    END Create;

(**************************************************************************)

BEGIN
    ChangeInProgress := FALSE;
END About.

