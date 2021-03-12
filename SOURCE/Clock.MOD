(**************************************************************************)
(*                                                                        *)
(*  A "System Clock" object                                               *)
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

MODULE Clock;

        (************************************************************)
        (*                                                          *)
        (*          PM interface to system clock settings           *)
        (*                                                          *)
        (*    Started:        10 August 2020                        *)
        (*    Last edited:    12 September 2020                     *)
        (*    Status:         OK                                    *)
        (*                                                          *)
        (************************************************************)

IMPORT OS2, MainDlg;

FROM PMInit IMPORT
    (* proc *)  OurHab;

(********************************************************************************)

VAR hab: OS2.HAB;            (* anchor block handle *)
    qmsg: OS2.QMSG;          (* message structure *)

(********************************************************************************)
(*              MAIN PROGRAM: INITIALISATION AND MESSAGE DISPATCHING            *)
(********************************************************************************)

BEGIN
    hab := OurHab();

    (* NOTE:  clean up from here is handled by the DosExitList processing *)
    (* Since signal exceptions are not handled by RTS yet, using module   *)
    (* finalization for clean up is incorrect. This will be changed in the*)
    (* next release.                                                      *)

    MainDlg.OpenMainDlg;

    (* Get/Dispatch Message loop *)

    WHILE OS2.WinGetMsg (hab, qmsg, 0, 0, 0) DO
        OS2.WinDispatchMsg (hab, qmsg);
    END;

END Clock.
