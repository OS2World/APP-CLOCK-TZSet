(**************************************************************************)
(*                                                                        *)
(*  Support module for some of my applications                            *)
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

IMPLEMENTATION MODULE DTFormat;

        (********************************************************)
        (*                                                      *)
        (*        Conversion of date and time to string         *)
        (*                                                      *)
        (*  Programmer:         P. Moylan                       *)
        (*  Started:            17 August 2020                  *)
        (*  Last edited:        4 September 2020                *)
        (*  Status:             OK                              *)
        (*                                                      *)
        (********************************************************)

IMPORT Strings, CommonSettings;

(****************************************************************************)

CONST Nul = CHR(0);

(********************************************************************************)
(*                                DAY OF WEEK                                   *)
(********************************************************************************)

PROCEDURE PutDayName (date: DateTime;  VAR (*INOUT*) result: ARRAY OF CHAR;
                                          VAR (*INOUT*) j: CARDINAL);

    (* Puts the abbreviation for the day of week in result, updates j. *)

    TYPE
        MonthData = ARRAY [1..13] OF CARDINAL;
        DayOfWeek = [0..6];       (* 0 = Sunday *)

    CONST
        BaseDay = 6;

        (* Days since beginning of year, for the 1st of each month.  In a   *)
        (* leap year you need an extra correction.                          *)

        FirstDayInMonth = MonthData {  0,  31,  59,  90, 120, 151,
                                     181, 212, 243, 273, 304, 334, 365};

    VAR FirstDayOfYear, weekday: DayOfWeek;
        dayofyear: CARDINAL;
        IsLeapYear: BOOLEAN;

    BEGIN
        (* Every group of four years has 4*365+1 = 1461 days, and       *)
        (* 1461 MOD 7 = 5.  This means that the DayOfWeek changes by    *)
        (* 5 days per 4 years.                                          *)

        FirstDayOfYear := (BaseDay + 5*(date.year DIV 4)) MOD 7;

        (* Thereafter, it changes by 2 days in the first year, and one  *)
        (* day per year after that.                                     *)

        IsLeapYear := (date.year MOD 4) = 0;
        IF date.year MOD 4 <> 0 THEN
            FirstDayOfYear := (FirstDayOfYear + (date.year MOD 4) + 1) MOD 7;
        END (*IF*);

        (* Now we want to know the current day of the year. *)

        dayofyear := FirstDayInMonth[ORD(date.month)] + ORD(date.day) - 1;
        IF IsLeapYear AND (ORD(date.month) > 2) THEN
            INC (dayofyear);
        END (*IF*);

        weekday := (FirstDayOfYear + dayofyear - 1) MOD 7;
        result[j] := Nul;
        Strings.Append (CommonSettings.DayName[weekday], result);
        j := LENGTH (result);

    END PutDayName;

(********************************************************************************)
(*                       FORMATTING DATE/TIME AS STRING                         *)
(********************************************************************************)

PROCEDURE Convert2 (value: CARDINAL;  VAR (*INOUT*) result: ARRAY OF CHAR;
                                      VAR (*INOUT*) j: CARDINAL);

    (* Puts a 2-digit number at result[j], updates j. *)

    (****************************************************************************)

    PROCEDURE Convert1 (value: CARDINAL);

        (* Puts a 1-digit number at result[j], updates j. *)

        BEGIN
            result[j] := CHR(value + ORD('0'));  INC(j);
        END Convert1;

    (****************************************************************************)

    BEGIN
        Convert1 (value DIV 10);  Convert1 (value MOD 10);
    END Convert2;

(********************************************************************************)

PROCEDURE FormatDateTime (Time: DateTime;  format: ARRAY OF CHAR;
                                    VAR (*OUT*) result: ARRAY OF CHAR);

    (* Puts the current date and time into result according to the      *)
    (* given format specification.  The format codes are:               *)
    (*                                                                  *)
    (*      HH          hours                                           *)
    (*      MM          minutes                                         *)
    (*      SS          seconds                                         *)
    (*      AM          implies 12-hour clock, replaced by PM if needed *)
    (*      PM          implies 12-hour clock, replaced by AM if needed *)
    (*                                                                  *)
    (*      dd          day, numeric                                    *)
    (*      ddd         day, three-letter name                          *)
    (*      mm          month, numeric                                  *)
    (*      mmm         month, three-letter name                        *)
    (*      yy          year, including Y2K bug                         *)
    (*      yyyy        year, all four digits                           *)
    (*                                                                  *)
    (*      zz          first time: sign and hours of time zone         *)
    (*      zz          second time: minutes part of time zone          *)
    (*                                                                  *)
    (* Note: in some languages the day name and/or month name could be  *)
    (* more than three characters long.                                 *)

    VAR j, k, kf: CARDINAL;
        literal, zonefound, clock12: BOOLEAN;

    BEGIN
        (* Initial scan to check for 12-hour clock. *)

        clock12 := FALSE;
        Strings.FindNext ("AM", format, 0, clock12, j);
        IF NOT clock12 THEN
            Strings.FindNext ("PM", format, 0, clock12, j);
        END (*IF*);

        k := 0;  kf := 0;  zonefound := FALSE;
        WHILE (kf <= HIGH(format)) AND (format[kf] <> Nul) DO
            literal := TRUE;
            CASE format[kf] OF
              | 'A', 'P':
                    IF format[kf+1] = 'M' THEN
                        IF ORD(Time.hours) < 12 THEN
                            result[k] := 'A';
                        ELSE
                            result[k] := 'P';
                        END (*IF*);
                        INC (kf, 2);
                        INC (k);
                        result[k] := 'M';  INC(k);
                        literal := FALSE;
                    END (*IF*);
              | 'd':
                    IF format[kf+1] = 'd' THEN
                        INC (kf, 2);
                        IF format[kf] = 'd' THEN
                            INC (kf);
                            PutDayName (Time, result, k);
                        ELSE
                            Convert2 (ORD(Time.day), result, k);
                        END (*IF*);
                        literal := FALSE;
                    END (*IF*);
              | 'm':
                    IF format[kf+1] = 'm' THEN
                        INC (kf, 2);
                        IF format[kf] = 'm' THEN
                            INC (kf);
                            result[k] := Nul;
                            Strings.Append (CommonSettings.MonthName[ORD(Time.month)], result);
                            k := LENGTH(result);
                            (*
                            FOR j := 0 TO 2 DO
                                result[k] := CommonSettings.MonthName[ORD(Time.month)][j];  INC(k);
                            END (*FOR*);
                            *)
                        ELSE
                            Convert2 (ORD(Time.month), result, k);
                        END (*IF*);
                        literal := FALSE;
                    END (*IF*);
              | 'y':
                    IF format[kf+1] = 'y' THEN
                        INC (kf, 2);
                        IF (format[kf] = 'y') AND (format[kf+1] = 'y') THEN
                            INC (kf, 2);
                            Convert2 (Time.year DIV 100, result, k);
                        END (*IF*);
                        Convert2 (Time.year MOD 100, result, k);
                        literal := FALSE;
                    END (*IF*);
              | 'h', 'H':
                    IF CAP(format[kf+1]) = 'H' THEN
                        INC (kf, 2);
                        j := ORD(Time.hours);
                        IF clock12 THEN
                            IF j = 0 THEN j := 12;
                            ELSIF j > 12 THEN DEC(j, 12);
                            END (*IF*);
                        END (*IF*);
                        Convert2 (j, result, k);
                        literal := FALSE;
                    END (*IF*);
              | 'M':
                    IF format[kf+1] = 'M' THEN
                        INC (kf, 2);
                        Convert2 (ORD(Time.minutes), result, k);
                        literal := FALSE;
                    END (*IF*);
              | 's', 'S':
                    IF CAP(format[kf+1]) = 'S' THEN
                        INC (kf, 2);
                        Convert2 (ORD(Time.seconds), result, k);
                        literal := FALSE;
                    END (*IF*);
              | 'z':
                    IF format[kf+1] = 'z' THEN
                        INC (kf, 2);
                        IF Time.timezone <> -1 THEN

                            (* -1 means undefined, other values are minutes *)

                            IF zonefound THEN
                                Convert2 (ABS(Time.timezone) MOD 60, result, k);
                            ELSE
                                IF Time.timezone > 0 THEN
                                    result[k] := '-';
                                ELSE
                                    result[k] := '+';
                                END (*IF*);
                                INC (k);
                                Convert2 (ABS(Time.timezone) DIV 60, result, k);
                            END (*IF*);
                        END (*IF*);
                        zonefound := TRUE;
                        literal := FALSE;
                    END (*IF*);
              | ELSE
                    literal := TRUE;
            END (*CASE*);
            IF literal THEN
                result[k] := format[kf];
                INC (k);  INC(kf);
            END (*IF*);
        END (*WHILE*);
        IF k <= HIGH(result) THEN
            result[k] := Nul;
        END (*IF*);
    END FormatDateTime;

(****************************************************************************)

END DTFormat.

