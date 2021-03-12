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

IMPLEMENTATION MODULE InternalDT;

        (****************************************************************)
        (*                                                              *)
        (*                         NuClock utility                      *)
        (*                    Internal date/time format                 *)
        (*                                                              *)
        (*    Started:        30 August 2020                            *)
        (*    Last edited:    22 September 2020                         *)
        (*    Status:         OK                                        *)
        (*                                                              *)
        (****************************************************************)


IMPORT OS2;

FROM SYSTEM IMPORT
    (* proc *)  CAST;

(************************************************************************)

TYPE
    CharSet = SET OF CHAR;

TYPE
    MonthData = ARRAY [1..13] OF CARDINAL;

CONST
    (* Days since beginning of year, for the 1st of each month.  In a   *)
    (* leap year you need an extra correction.                          *)

    FirstDayInMonth = MonthData {  0,  31,  59,  90, 120, 151,
                                 181, 212, 243, 273, 304, 334, 365};

    Feb28 = 31 + 27;   (* not 28, because we use zero-based numbering.  *)

    MinutesPerDay = 24*60;

(************************************************************************)
(*                     MISCELLANEOUS OPERATIONS                         *)
(************************************************************************)

PROCEDURE SetDayOfWeek (VAR (*INOUT*) d: IDateTime);

    (* Calculates d.weekday, on the assumption that d.year and d.day    *)
    (* are already set correctly.                                       *)

    CONST BaseDay = 6;

    VAR FirstDayOfYear: DayOfWeek;

    BEGIN
        (* Every group of four years has 4*365+1 = 1461 days, and       *)
        (* 1461 MOD 7 = 5.  This means that the DayOfWeek changes by    *)
        (* 5 days per 4 years.                                          *)

        FirstDayOfYear := (BaseDay + 5*(d.year DIV 4)) MOD 7;

        (* Thereafter, it changes by 2 days in the first year, and one  *)
        (* day per year after that.                                     *)

        IF d.year MOD 4 <> 0 THEN
            FirstDayOfYear := (FirstDayOfYear + (d.year MOD 4) + 1) MOD 7;
        END (*IF*);

        d.weekday := (FirstDayOfYear + d.day - 1) MOD 7;

    END SetDayOfWeek;

(************************************************************************)
(*                              ARITHMETIC                              *)
(************************************************************************)

PROCEDURE AddMinutes (VAR (*INOUT*) idt: IDateTime;  extra: CARDINAL);

    (* Adds extra to idt.  We assume extra < minutes per day. *)

    VAR sum, newday, DaysInYear: CARDINAL;

    BEGIN
        sum := idt.minute + extra;
        IF sum >= MinutesPerDay THEN
            DEC (sum, MinutesPerDay);

            (* Go to next day. *)

            IF (idt.year MOD 4) = 0 THEN
                DaysInYear := 366;
            ELSE
                DaysInYear := 365;
            END (*IF*);
            newday := idt.day + 1;
            IF newday >= DaysInYear THEN
                INC (idt.year);
                newday := 0;
            END (*IF*);
            idt.day := newday;
        END (*IF*);
        idt.minute := sum;
    END AddMinutes;

(************************************************************************)

PROCEDURE SubtractMinutes (VAR (*INOUT*) idt: IDateTime;  adjust: CARDINAL);

    (* Subtracts adjust from idt.  We assume adjust < minutes per day. *)

    BEGIN
        IF adjust <= idt.minute THEN
            DEC (idt.minute, adjust);
        ELSE
            INC (idt.minute, MinutesPerDay - adjust);

            (* Go back one day. *)

            IF idt.day > 0 THEN
                DEC (idt.day);
            ELSE
                DEC (idt.year);
                IF (idt.year MOD 4) = 0 THEN
                    idt.day := 365;
                ELSE
                    idt.day := 364;
                END (*IF*);
            END (*IF*);

        END (*IF*);
    END SubtractMinutes;

(************************************************************************)

PROCEDURE DiffMinutes (VAR (*IN*) from, to: IDateTime): INTEGER;

    (* Returns (to - from), in minutes.  Assumption: the dates are      *)
    (* either in the same year, or to is in the year after from.        *)

    VAR result: INTEGER;

    BEGIN
        result := 0;
        IF to.year > from.year THEN
            result := 365;

            (* Increment the result if either from is a leap year and   *)
            (* from.day is before Feb 29, or to is a leap year and      *)
            (* to.day is after Feb 28.  Because we assuming at most a   *)
            (* one-year gap, only one of these conditions can hold.     *)

            IF ((from.year MOD 4 = 0) AND (from.day <= Feb28))
                       OR ((to.year MOD 4 = 0) AND (to.day > Feb28)) THEN
                result := 366;
            END (*IF*);

        END (*IF*);
        result := result + CAST(INTEGER,to.day) - CAST(INTEGER,from.day);
        result := 60*24*result
                  + CAST(INTEGER,to.minute) - CAST(INTEGER,from.minute);
        RETURN result;
    END DiffMinutes;

(************************************************************************)
(*             CONVERSION TO/FROM THE MORE STANDARD FORMAT              *)
(************************************************************************)

PROCEDURE DTtoIDT (dt: OS2.DATETIME): IDateTime;

    (* Converts from the OS/2 representation to our internal representation. *)

    VAR result: IDateTime;  LeapYear: BOOLEAN;

    BEGIN
        result.year := dt.year;
        result.day := FirstDayInMonth[ORD(dt.month)] + ORD(dt.day) - 1;
        result.minute := 60*ORD(dt.hours) + ORD(dt.minutes);
        LeapYear := (dt.year MOD 4) = 0;
        IF LeapYear AND (ORD(dt.month) > 2) THEN
            INC (result.day);
        END (*IF*);
        result.weekday := ORD(dt.weekday);
        RETURN result;
    END DTtoIDT;

(************************************************************************)

PROCEDURE IDTtoDT (idt: IDateTime): OS2.DATETIME;

    (* Converts from our internal representation to the OS/2 representation. *)

    VAR result: OS2.DATETIME;
        month, day, daysinmonth: CARDINAL;
        IsLeapYear: BOOLEAN;

    BEGIN
        IsLeapYear := (idt.year MOD 4) = 0;
        result.year := idt.year;
        day := idt.day;
        IF (day > Feb28) AND IsLeapYear THEN
           DEC (day);
        END (*IF*);
        month := 1;
        daysinmonth := FirstDayInMonth[2];
        WHILE day >= daysinmonth DO
            DEC (day, daysinmonth);
            INC (month);
            daysinmonth := FirstDayInMonth[month+1] - FirstDayInMonth[month];
        END (*WHILE*);
        result.month := CHR(month);
        result.day := CHR(day + 1);
        result.hours := CHR(idt.minute DIV 60);
        result.minutes := CHR(idt.minute MOD 60);
        result.seconds := CHR(0);
        result.hundredths := CHR(0);
        result.weekday := CHR(idt.weekday);
        RETURN result;
    END IDTtoDT;

(************************************************************************)

END InternalDT.


