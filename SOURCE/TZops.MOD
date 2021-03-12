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

IMPLEMENTATION MODULE TZops;

        (****************************************************************)
        (*                                                              *)
        (*                         NuClock utility                      *)
        (*                     Working with TZ strings                  *)
        (*                                                              *)
        (*    Started:        22 August 2020                            *)
        (*    Last edited:    10 September 2020                         *)
        (*    Status:         OK                                        *)
        (*                                                              *)
        (****************************************************************)


FROM InternalDT IMPORT
    (* type *)  IDateTime,
    (* proc *)  DTtoIDT, DiffMinutes;

FROM DateTime IMPORT
    (* type *)  RawDataType, RawInfoType, CookedInfoType,
    (* proc *)  FindSummerStartAndEnd;

FROM DTFormat IMPORT
    (* proc *)  FormatDateTime;

FROM Storage IMPORT
    (* proc *)  ALLOCATE, DEALLOCATE;

IMPORT Strings, OS2;

(************************************************************************)

TYPE
    CharSet = SET OF CHAR;

CONST
    Nul = CHR(0);
    MinutesPerDay = 24*60;

    USRules = "3,2,0,7200,11,1,0,7200,3600";

(************************************************************************)
(*                                                                      *)
(*               ANALYSIS OF THE TZ ENVIRONMENT VARIABLE                *)
(*                                                                      *)
(************************************************************************)

PROCEDURE ExtractTZconsts (TZstr: ARRAY OF CHAR;  VAR (*INOUT*) p: RawInfoType);

    (* Extracts time zone parameters from TZstr.  If the data are       *)
    (* invalid, returns FALSE, with j equal to the error position.      *)

    (* Note that the scope of j includes all of the following nested    *)
    (* procedures.  They all update j, and in case of an error they all *)
    (* all exit with j set to the error point.                          *)

    CONST Digits = CharSet{'0'..'9'};
          Sign = CharSet {'+', '-'};
          SecondsPerDay = MinutesPerDay*60;

    VAR j: CARDINAL;

    (********************************************************************)

    PROCEDURE ReadSign (str: ARRAY OF CHAR): BOOLEAN;

        (* Reads '+' or '-' from str[j], updates j, returns TRUE    *)
        (* if we found '-'.  (The '+' is optional.)                 *)

        VAR negative: BOOLEAN;

        BEGIN
            negative := FALSE;
            IF str[j] = '+' THEN
                INC (j);
            ELSIF str[j] = '-' THEN
                negative := TRUE;  INC (j);
            END (*IF*);
            RETURN negative;
        END ReadSign;

    (********************************************************************)

    PROCEDURE ReadNum (str: ARRAY OF CHAR): INTEGER;

        (* Reads a numeric string from str[j], updates j. *)

        VAR result: INTEGER;  negative: BOOLEAN;

        BEGIN
            negative := ReadSign (str);
            result := 0;
            WHILE str[j] IN Digits DO
                result := 10*result + VAL(INTEGER, ORD(str[j]) - ORD('0'));
                INC (j);
            END (*WHILE*);

            IF negative THEN
                result := -result;
            END (*IF*);
            RETURN result;

        END ReadNum;

    (********************************************************************)

    PROCEDURE InRange (val, min, max: INTEGER): BOOLEAN;

        (* Returns TRUE iff  min <= val <= max. *)

        BEGIN
            IF (val <> MIN(INTEGER)) AND (val >= min) AND (val <= max) THEN
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END (*IF*);
        END InRange;

    (********************************************************************)

    PROCEDURE BoundaryParams (str: ARRAY OF CHAR;
                               VAR (*OUT*) RawData: RawDataType): BOOLEAN;

        (* Converts a four-parameter string, used in TZ to specify the  *)
        (* start or end of summer time, to a RawData array.             *)
        (* We start at str[j], and update j.                            *)

        VAR k: CARDINAL;  s2: BOOLEAN;
            numstart: ARRAY [0..3] OF CARDINAL;

        BEGIN
            (* Gets the four numbers from the TZ string. *)

            FOR k := 0 TO 3 DO
                numstart[k] := j;
                IF str[j] IN Digits+Sign THEN
                    RawData[k] := ReadNum (str);
                ELSE
                    RETURN FALSE;
                END (*IF*);
                IF str[j] = ',' THEN
                    INC (j);
                END (*IF*);
            END (*FOR*);

            (* Now check these four values for being in range. *)

            IF NOT InRange (RawData[0], 1, 12) THEN
                j := numstart[0];
                RETURN FALSE;
            END (*IF*);
            IF NOT InRange (RawData[1], -4, 4) THEN
                j := numstart[1];
                RETURN FALSE;
            END (*IF*);
            IF RawData[1] = 0 THEN
                s2 := InRange (RawData[2], 1, 31);
            ELSE
                s2 := InRange (RawData[2], 0, 6);
            END (*IF*);
            IF NOT s2 THEN
                j := numstart[2];
                RETURN FALSE;
            END (*IF*);
            IF NOT InRange (RawData[3], 0, SecondsPerDay-1) THEN
                j := numstart[3];
                RETURN FALSE;
            END (*IF*);

            RETURN TRUE;

        END BoundaryParams;

    (********************************************************************)

    PROCEDURE TZtail (str: ARRAY OF CHAR): BOOLEAN;

        (* Decodes the part of a TZ string that encodes the summer  *)
        (* time information.                                        *)

        BEGIN
            IF NOT BoundaryParams (str, p^.StartRaw) THEN
                RETURN FALSE;
            END (*IF*);
            IF NOT BoundaryParams (str, p^.EndRaw) THEN
                RETURN FALSE;
            END (*IF*);

            (* Finally we should have the summer time correction    *)
            (* in seconds.  Convert this to minutes.                *)

            IF NOT (str[j] IN Digits) THEN
                RETURN FALSE;
            END (*IF*);
            p^.correction := ReadNum (str);
            IF NOT InRange (p^.correction, 0, SecondsPerDay-1) THEN
                RETURN FALSE;
            END (*IF*);
            p^.correction := (p^.correction + 30) DIV 60;
            RETURN TRUE;

        END TZtail;

    (********************************************************************)

    VAR negative, success: BOOLEAN;

    BEGIN
        IF p <> NIL THEN
            DISPOSE (p);
        END (*IF*);
        NEW (p);
        p^.valid := FALSE;

        j := 0;

        (* The first parameter is AAAnBBB, where AAA and BBB are    *)
        (* codes that are of no interest to us, and n is a          *)
        (* signed hour:minute:second value where only the hour is   *)
        (* compulsory.  This gives the time zone when summer time   *)
        (* is not in force.  The value is negative for regions east *)
        (* of Greenwich.                                            *)

        WHILE NOT (TZstr[j] IN CharSet {',', '+', '-', '0'..'9'}) DO
            INC (j);
        END (*WHILE*);

        negative := ReadSign (TZstr);
        IF NOT (TZstr[j] IN Digits) THEN
            p^.errpos := j;
            RETURN;
        END (*IF*);
        p^.BaseZone := 60*ReadNum(TZstr);
        IF TZstr[j] = ':' THEN
            INC (j);  INC (p^.BaseZone, ReadNum(TZstr));
            IF TZstr[j] = ':' THEN
                (* We don't use the seconds value. *)
                REPEAT
                    INC (j);
                UNTIL NOT (TZstr[j] IN Digits);
            END (*IF*);
        END (*IF*);
        IF negative THEN
            p^.BaseZone := -p^.BaseZone;
        END (*IF*);

        (* Now skip the BBB code. *)

        WHILE (TZstr[j] <> CHR(0)) AND (TZstr[j] <> ',') DO
            INC (j);
        END (*WHILE*);

        IF TZstr[j] = ',' THEN
            INC (j);
        END (*IF*);

        (* If we've reached the end of the string, the default summer   *)
        (* time information must be appended.                           *)

        IF TZstr[j] = CHR(0) THEN
            j := 0;
            success := TZtail (USRules);
        ELSE
            success := TZtail (TZstr);
        END (*IF*);

        p^.valid := success;
        p^.errpos := j;

    END ExtractTZconsts;

(************************************************************************)

PROCEDURE UpdateTZinfo (TZstr: ARRAY OF CHAR;  VAR (*INOUT*) p: RawInfoType): BOOLEAN;

    (* Extracts time zone parameters from TZstr.    *)
    (* Returns TRUE iff TZstr is a valid TZ string. *)

    BEGIN
        IF p <> NIL THEN
            DISPOSE (p);
        END (*IF*);
        NEW (p);
        ExtractTZconsts (TZstr, p);
        RETURN p^.valid;
    END UpdateTZinfo;

(************************************************************************)
(*                    CONVERTING TIME ZONE TO STRING                    *)
(************************************************************************)

PROCEDURE PutCard1 (VAR (*INOUT*) str: ARRAY OF CHAR;
                            VAR (*INOUT*) j: CARDINAL;  value: CARDINAL);

    (* Encodes a one-digit number in decimal. *)

    BEGIN
        str[j] := CHR(ORD('0') + value);  INC(j);
    END PutCard1;

(************************************************************************)

PROCEDURE PutCard2 (VAR (*INOUT*) str: ARRAY OF CHAR;
                            VAR (*INOUT*) j: CARDINAL;  value: CARDINAL);

    (* Writes a two-digit number in decimal. *)

    BEGIN
        PutCard1 (str, j, value DIV 10);
        PutCard1 (str, j, value MOD 10);
    END PutCard2;

(************************************************************************)

PROCEDURE EncodeTZ (mins: INTEGER;  VAR (*OUT*) str: ARRAY OF CHAR);

    (* Sets str to the current time zone in +hhmm format. *)

    VAR j: CARDINAL;

    BEGIN
        j := 0;
        IF mins < 0 THEN
            str[j] := '+';  INC(j);  mins := -mins;
        ELSE
            str[j] := '-';  INC(j);
        END (*IF*);
        PutCard2 (str, j, mins DIV 60);
        PutCard2 (str, j, mins MOD 60);
        str[j] := Nul;
    END EncodeTZ;

(************************************************************************)
(*                CALCULATING THE SUMMER TIME BOUNDARIES                *)
(************************************************************************)

PROCEDURE GetZoneInfo (raw: RawInfoType;  VAR (*INOUT*) info: CookedInfoType;
                            VAR (*OUT*) currentTZ: ARRAY OF CHAR;
                            VAR (*OUT*) SummerStart, SummerEnd: ARRAY OF CHAR);

    (* Translates the raw data to text strings. *)

    CONST DateFormat = "ddd, yyyy-mmm-dd";

    VAR TimeZone: INTEGER;
        DTsummerstart, DTsummerend: OS2.DATETIME;

    BEGIN
        IF NOT raw^.valid THEN
            IF info = NIL THEN
                NEW (info);
            END (*IF*);
            info^.NoSummerTime := TRUE;
            Strings.Assign ("??", currentTZ);
            RETURN;
        END (*IF*);

        FindSummerStartAndEnd (raw, info,
                                DTsummerstart, DTsummerend,
                                TimeZone);
        EncodeTZ (TimeZone, currentTZ);
        IF NOT info^.NoSummerTime THEN
            FormatDateTime (DTsummerstart, DateFormat, SummerStart);
            FormatDateTime (DTsummerend, DateFormat, SummerEnd);
        END (*IF*);

    END GetZoneInfo;

(************************************************************************)

PROCEDURE TimeToNextChange (info: CookedInfoType;
                                VAR (*OUT*) amount, unit: CARDINAL);

    (* Calculates how many days/hours/minutes until next time zone change.  *)
    (* unit = 0 for days, 1 for hours, 2 for minutes, 3 for seconds.        *)

    VAR delay: INTEGER;
        dt: OS2.DATETIME;
        Now: IDateTime;

    BEGIN
        OS2.DosGetDateTime (dt);
        Now := DTtoIDT (dt);
        IF info^.InSummerTime THEN
            delay := DiffMinutes (Now, info^.SummerEnd);
        ELSE
            delay := DiffMinutes (Now, info^.SummerStart);
        END (*IF*);
        delay := 60*delay - VAL(INTEGER, dt.seconds);
        IF delay < 0 THEN
            delay := 0;
        END (*IF*);
        amount := ABS(delay);       (* seconds *)
        IF amount < 90 THEN
            unit := 3;
        ELSE
            amount := (amount + 30) DIV 60;     (* minutes *)
            IF amount < 180 THEN
                unit := 2;
            ELSE
                amount := (amount + 30) DIV 60;     (* hours *)
                unit := 1;
                IF amount > 71 THEN
                    amount := (amount + 12) DIV 24; (* days *)
                    unit := 0;
                END (*IF*);
            END (*IF*);
        END (*IF*);

    END TimeToNextChange;

(************************************************************************)

END TZops.


