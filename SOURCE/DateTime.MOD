IMPLEMENTATION MODULE DateTime;

        (********************************************************)
        (*                                                      *)
        (*       Manipulation of dates and times in order to    *)
        (*            deal with summer time adjustments.        *)
        (*                                                      *)
        (*   This is a modified version of a module with the    *)
        (*          same name in my TZSet program.              *)
        (*                                                      *)
        (*  Programmer:         P. Moylan                       *)
        (*  Started:            31 December 2018                *)
        (*  Last edited:        5 September 2020                *)
        (*  Status:             OK                              *)
        (*                                                      *)
        (********************************************************)


IMPORT OS2;

FROM InternalDT IMPORT
    (* type *)  IDateTime, DayOfWeek,
    (* proc *)  DTtoIDT, IDTtoDT, SetDayOfWeek;

FROM Storage IMPORT
    (* type *)  ALLOCATE, DEALLOCATE;

(************************************************************************)

TYPE
    MonthData = ARRAY [1..13] OF CARDINAL;

CONST
    MinutesPerDay = 24*60;

    (* Days since beginning of year, for the 1st of each month.  In a   *)
    (* leap year you need an extra correction.                          *)

    FirstDayInMonth = MonthData {  0,  31,  59,  90, 120, 151,
                                 181, 212, 243, 273, 304, 334, 365};

(************************************************************************)
(*                   THE TIME ZONE AS STORED BY OS/2                    *)
(************************************************************************)

PROCEDURE UpdateTimeZone (value: INTEGER);

    (* Stores an updated value in the system's copy of the time zone.   *)
    (* We use two kinds of critical section protection here.  The       *)
    (* priority setting reduces the likelihood of clock changes by      *)
    (* some other program.  The "must complete" protection ensures that *)
    (* we don't get interrupted by a process shutdown.                  *)

    VAR dt: OS2.DATETIME;  rc: OS2.APIRET;  nesting: CARDINAL;

    BEGIN
        rc := OS2.DosEnterMustComplete (nesting);
        rc := OS2.DosSetPriority (OS2.PRTYS_THREAD,
                                    OS2. PRTYC_TIMECRITICAL, 0, 0);
        OS2.DosGetDateTime (dt);
        IF dt.timezone <> value THEN
            dt.timezone := value;
            OS2.DosSetDateTime (dt);
        END (*IF*);
        rc := OS2.DosSetPriority (OS2.PRTYS_THREAD,
                                    OS2. PRTYC_REGULAR, 0, 0);
        rc := OS2.DosExitMustComplete (nesting);
    END UpdateTimeZone;

(************************************************************************)

PROCEDURE CurrentDateTime(): IDateTime;

    (* Returns today's date and time.  *)

    VAR dt: OS2.DATETIME;

    BEGIN
        OS2.DosGetDateTime (dt);
        RETURN DTtoIDT (dt);
    END CurrentDateTime;

(************************************************************************)

PROCEDURE IsEqual (d1, d2: IDateTime): BOOLEAN;

    (* Returns TRUE iff d1 and d2 have the same year/day/minute values. *)

    BEGIN
        RETURN (d1.year = d2.year) AND (d1.day = d2.day)
                        AND (d1.minute = d2.minute);
    END IsEqual;

(************************************************************************)

PROCEDURE IsLater (d1, d2: IDateTime): BOOLEAN;

    (* Returns TRUE iff d1 > d2. *)

    VAR result: BOOLEAN;

    BEGIN
        IF d1.year > d2.year THEN result := TRUE
        ELSIF d1.year < d2.year THEN result := FALSE
        ELSIF d1.day > d2.day THEN result := TRUE
        ELSIF d1.day < d2.day THEN result := FALSE
        ELSIF d1.minute > d2.minute THEN result := TRUE
        ELSE result := FALSE;
        END (*IF*);
        RETURN result;
    END IsLater;

(************************************************************************)
(*                                                                      *)
(*            CONVERSION FROM RAW DATA TO IDateTime FORMAT              *)
(*                                                                      *)
(*   This is where we calculate a time where summer starts or ends.     *)
(*                                                                      *)
(************************************************************************)

PROCEDURE SetSwitchTime (thisyear: CARDINAL;
                            raw: RawDataType;
                             VAR (*OUT*) result: IDateTime);

    (* Converts a date/time in RawData form to IDateTime form.  *)

    VAR TargetDay: DayOfWeek;  val, weekcode: INTEGER;  IsLeapYear: BOOLEAN;

    BEGIN
        (* Set the year in the result. *)

        result.year := thisyear;
        IsLeapYear := (thisyear MOD 4) = 0;

        (* The first of the four numbers is a month. *)

        result.day := FirstDayInMonth[raw[0]];
        IF IsLeapYear AND (raw[0] > 2) THEN
            INC (result.day);
        END (*IF*);

        (* The second and third numbers give the day in the month,  *)
        (* but it's in a non-obvious format.  The third number is a *)
        (* day of the week (0 = Sunday).  The second, if it's       *)
        (* positive, says whether it's the first, second, etc.      *)
        (* occurrence of that day in the month.  If it's negative,  *)
        (* we count backwards from the end of the month.  If it's   *)
        (* zero, then the third number is an actual day of the      *)
        (* month, i.e. it's not a day-within-week.                  *)

        weekcode := raw[1];
        IF weekcode = 0 THEN
            val := raw[2]; (* supposed to be an actual day of month *)
            IF val < 1 THEN

                (* Should never happen, but it pays to be paranoid  *)
                (* given the possibility of malformed TZ strings.   *)

                IF VAL (INTEGER, result.day) + val < 1 THEN
                    result.day := 0;
                ELSE
                    DEC (result.day, 1 - val);
                END (*IF*);

            ELSIF val > 1 THEN
                INC (result.day, val - 1);
            END (*IF*);
            SetDayOfWeek (result);
        ELSE
            SetDayOfWeek (result);
            TargetDay := ABS(raw[2]);
            IF weekcode > 0 THEN

                (* Counting from first day of month. *)

                WHILE result.weekday <> TargetDay DO
                    INC (result.day);
                    result.weekday := (result.weekday + 1) MOD 7;
                END (*WHILE*);
                DEC (weekcode);
                INC (result.day, 7*ABS(weekcode));
            ELSE

                (* Counting from last day of month. *)

                INC (result.day, FirstDayInMonth[raw[0]+1]
                           - FirstDayInMonth[raw[0]] - 1);
                IF IsLeapYear AND (raw[0] = 2) THEN
                    INC (result.day);
                END (*IF*);
                SetDayOfWeek (result);

                WHILE result.weekday <> TargetDay DO
                    DEC (result.day);
                    IF result.weekday = 0 THEN result.weekday := 6
                    ELSE DEC(result.weekday)
                    END (*IF*);
                END (*WHILE*);
                INC (weekcode);
                DEC (result.day, 7*ABS(weekcode));

            END (*IF*);
        END (*IF*);

        (* raw[3] should never be negative, and a subsidiary module *)
        (* has already checked this.                                *)

        result.minute := (raw[3] + 30) DIV 60;
        IF result.minute >= MinutesPerDay THEN
            result.minute := MinutesPerDay - 1;
        END (*IF*);

    END SetSwitchTime;

(************************************************************************)
(*                          MAIN CALCULATION                            *)
(************************************************************************)

PROCEDURE FindSummerStartAndEnd (p: RawInfoType;  VAR (*INOUT*) info: CookedInfoType;
                                  VAR (*OUT*) DTSummerStart, DTSummerEnd: OS2.DATETIME;
                                    VAR (*OUT*) zone: INTEGER);

    (* Sets the values of the variables that define the summer start    *)
    (* and end date.  The output value zone is the current time zone,   *)
    (* which is not necessarily the same as the base zone in p^.        *)

    VAR Now: IDateTime;
        SummerHasStarted, SummerIsNotOver: BOOLEAN;

    BEGIN
        IF info <> NIL THEN
            DISPOSE (info);
        END (*IF*);
        NEW (info);

        (* Get current date and time. *)

        Now := CurrentDateTime();

        SetSwitchTime (Now.year, p^.StartRaw, info^.SummerStart);
        SetSwitchTime (Now.year, p^.EndRaw, info^.SummerEnd);

        info^.NoSummerTime := IsEqual (info^.SummerStart, info^.SummerEnd);
        IF info^.NoSummerTime THEN
            info^.InSummerTime := FALSE;
        ELSE

            SummerHasStarted := NOT IsLater (info^.SummerStart, Now);
            SummerIsNotOver := IsLater (info^.SummerEnd, Now);

            IF IsLater (info^.SummerStart, info^.SummerEnd) THEN

                (* Southern hemisphere *)

                info^.InSummerTime := SummerHasStarted OR SummerIsNotOver;

            ELSE

                (* Northern hemisphere *)

                info^.InSummerTime := SummerHasStarted AND SummerIsNotOver;

            END (*IF*);

            (* Make the summer time correction, if applicable. *)

            zone := p^.BaseZone;
            IF info^.InSummerTime THEN
                DEC (zone, p^.correction);
            END (*IF*);
            UpdateTimeZone (zone);

            (* Up to this point, SummerTimeStart and SummerTimeEnd are  *)
            (* dates in this year.  Often they need to be in the next   *)
            (* year, in which case we need to redo the calculation.     *)
            (* It is not good enough to simply add a year, because for  *)
            (* example the last Sunday in a month can be on a very      *)
            (* different date from year to year.                        *)

            IF SummerHasStarted THEN
                SetSwitchTime (Now.year+1, p^.StartRaw, info^.SummerStart);
            END (*IF*);
            IF NOT SummerIsNotOver THEN
                SetSwitchTime (Now.year+1, p^.EndRaw, info^.SummerEnd);
            END (*IF*);

        END (*IF*);

        DTSummerStart := IDTtoDT (info^.SummerStart);
        DTSummerEnd := IDTtoDT (info^.SummerEnd);

    END FindSummerStartAndEnd;

(************************************************************************)

END DateTime.

