Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- =============================================  
-- Author:  <Author,,JButterly>  
-- Create date: <Create 4/3/2007,,>  
-- Description: <Process to create or update ActiveQueueT records>  
  
-- This is like an OrderType  
-- Status Flag  (P) Pending (new), (C) Confirmed (after pending), (D) Dropped, (X) Cancelled w/ Vendor (after drop)  
--       (R) Revised, (N) Notified (after revise)), (I) Ignore (like a drop),   
--    (T) Terminated (went away before confirmed - after 'P')  
  
-- TripCd(s) TH (ToHotel from Airport), TA (ToAirport from Hotel),   
--    OH (ToOtherHotel from Airport), OA (ToOtherAirport from Hotel)  
--    SS (ToSta from Sta)  
  
-- Action: Need to cleanup bad Travel Pair: (20041 ) record for: PickUp:() DropOff:()  DropOff should be a HotelKey  
-- select * from tblTravelPair where TP_Key = 20041  
-- exec P_QueueMgt_Trips  
-- Select * from dbo.tblBillId_Trip  
-- delete from dbo.tblBillId_Trip  
-- select top 1000 * from tblMesg order by 1 desc  
  
/**  
  
  
declare @FD datetime, @TD datetime  
set @FD = '2/01/2020'  
set @TD = '2/10/2020 23:59'  
exec P_TMSMain_Common @FD, @TD, 'JL'  
exec P_TMSMain_JL 'JL', @FD, @TD  
exec P_QueueMgt_Trips  
exec P_UpdCounts  
  
  
  
  
**/  
  
-- =============================================  
  
CREATE      Proc [dbo].[P_QueueMgt_TripsQueue]  
    (  
        @A_symbol        char(2) = null,  
        @R_RefNumb_Queue int     = null,  
        @TripDt_Queue    date    = null  
    )  
as  
  
    /*  
exec [dbo].[P_QueueMgt_TripsQueue] 'AA',-10131,'2024-01-10'  
  
declare @R_RefNumb int  
exec [dbo].[P_QueueMgt_TripsQueue] 'AA',-1002,'2023-12-02',@R_RefNumb  
  
  
declare @R_RefNumb int  
exec [dbo].[P_QueueMgt_TripsQueue] 'AA',-1003,'2023-12-20',@R_RefNumb  
select @R_RefNumb  
  
*/  
    Declare  
        @Cnt                 int,  
        @LocalDtTm           datetime,  
        @OnceLocalDtTm       datetime,  
        @LocalStaDtTm        datetime,  
        @iRet                int,  
        @RCnt                int,  
        @RCnt2               int,  
        @Err                 int,  
        @DiffTm              int,  
        @CalcDiffTm          int,  
        @BI_UIDOld           int,  
        @RefNumbOld          int,  
        @RefNumbNew          int,  
        @ErrorFlg            int,  
        @Msg                 varchar(255),  
        @ChkDtTm             datetime,  
        @ProvKey             int,  
        @T_UID               int,  
        @BI_UID              int,  
        @BI_UIDFoundExisting int,  
        @TP_Key              int,  
        @Symbol              char(2),  
        @AirTmp              char(2),  
        @TripCd              char(2),  
        @TripDtTm            datetime,  
        @AdjTripDtTm         datetime,  
        @CurrCode            char(3),  
        @TripDtTm_Old        datetime,  
        @ArrLimoFltNum       varchar(6), -- JB new 4/4/22  
        @StatusCd            char(1),  
        @FltNum              char(6),  
        @FltNum_Old          char(6),  
        @T_EmpId             char(12),  
        @T_EmpId_Old         char(12),  
        @T_SentToProvDtTm    datetime,  
        @PickUpKey           varchar(8),  
        @DropOffKey          varchar(8),  
        @HotelStationCd      char(4),  
        @PR_TripDt           datetime,  
        @Skip_MakeBillId     int,  
        @ProcName            varchar(128),  
        @BuffMins            int,  
        @BuffPOSNMins        int,  
        @BigBuffMins         int,  
        @CommissionRate      decimal(12, 4),  
        @CommissionFlat      money,  
        @FOP                 nchar(30),  
        @RateFlat            money,  
        @RateHead            money,  
        @TollAmtToDropOff    money,  
        @TollAmtFromDropOff  money,  
        @NoShowCharge        money,  
        @MiscTaxToDropOff    money,  
        @MiscTaxFromDropOff  money,  
        @Gratuity            money,  
        @TripTmi             int,  
        @TimeRatePerMin      money,  
        @WaitTimeRate        money,  
        @HasTiered           char(1),  
  @ByTierStart1        int,  
        @ByTierEnd1          int,  
        @ByTierRate1         money,  
        @ByTierStart2        int,  
        @ByTierEnd2          int,  
        @ByTierRate2         money,  
        @ByTierStart3        int,  
        @ByTierEnd3          int,  
        @ByTierRate3         money,  
        @ByTierStart4        int,  
        @ByTierEnd4          int,  
        @ByTierRate4         money,  
        @ByTierStart5        int,  
        @ByTierEnd5          int,  
        @ByTierRate5         money,  
        @ByTierStart6        int,  
        @ByTierEnd6          int,  
        @ByTierRate6         money,  
        @R_RefNumb           int,  
  @TP_PickupCD_New   char(1),  
  @TP_PickupKey_New   varchar(8),  
  @TP_DropOffCD_New   char(1),  
  @TP_FropOffKey_New   varchar(8),  
  @TP_Key_New     int,  
  @P_ProvKey_New    int,  
  @PA_Key_New     int  
    Set NOCOUNT ON  
    Set @iRet = 0  
    Set @DiffTm = 15 -- default  
    Set @RefNumbNew = 0  
    Set @BI_UIDOld = 0  
    Set @ErrorFlg = 0  
    Set @BigBuffMins = 14  
    -- THis needs to be bigger than the below 2 @Buffs.   -- JB 7/8/22 was 20, now 14.  We want deadheads to be separate (at least for JAL).  
    -- This number controls when 2 trips, same flt#, are merged or separate.  
    Set @BuffMins = 5 -- 5 min now, was 2 hours  (120)   JB 4/17/20  
    Set @BuffPOSNMins = 3 -- was 26, was 5 min, now 10 JB 4/4/22, now 3 JB 5/24/22  
    Set @AirTmp = '--'  
    exec U_ProcName  
        @ProcName output,  
        @@PROCID  
  
    ---  
    ---  
    exec U_LocalDtTm  
        @LocalDtTm output  
    Set @OnceLocalDtTm = @LocalDtTm  
  
    --/*****   
  
    --This logic, these tables are not currently used.    
    --They may be in the future, if we automate sending any reports.  
    --JB 5/11/22  
  
 DECLARE @TNotes varchar(50);

 select @TNotes = T_Notes from tblTravelTrips_Queue where R_RefNumb = @R_RefNumb_Queue  

 select TP_PickUpCd = @TP_PickupCD_New ,  
     TP_PickUpKey = @TP_PickupKey_New,  
     TP_DropOffCd = @TP_DropOffCD_New,  
     TP_DropOffKey = @TP_FropOffKey_New,  
     P_ProvKey = @P_ProvKey_New,  
     PA_Key = @PA_Key_New  
 from tblTravelTrips_Queue where R_RefNumb = @R_RefNumb_Queue  
  
  
    Update  
        T  
    Set  
        T.T_PendingCd = case  
                            when T.T_StatusCd in (  
                                                     'P', 'R', 'D'  
                                                 )  
                                then 'N'  
                            else  
                                'C'  
                        end,  
        T.BI_UID = null,  
        T.T_PendingDtTm = null,  
        T.T_SentToProvDtTm = null  
    From  
        dbo.tblTravelTrips_Queue T  
        LEFT Join  
            dbo.tblBillId_Trip   B  
                on T.BI_UID = B.BI_UID  
                   AND T.A_Symbol = B.A_Symbol  
    Where  
        T.BI_UID is not null -- Has value  
        And B.BI_UID is null  
  
  
 Update  
        T  
    Set  
        T.T_Notes = @R_RefNumb_Queue  
          
    From  
        dbo.tblTravelTrips_Queue T  
         
    Where  
        T.R_RefNumb = @R_RefNumb_Queue  
  
    Set @RCnt = @@ROWCOUNT  
    Set @Err = @@ERROR  
    If @RCnt > 0  
        Begin  
            Select  
                @Msg = 'Debug: Reset orphan data ' + convert(char(4), @RCnt) + ' bad TravelTrip BI_UID values.'  
            exec U_Debug  
                @AirTmp,  
                @Msg,  
                5,  
                @ProcName,  
                NULL,  
                NULL,  
                NULL,  
                NULL,  
                NULL  
        End  
  
    ---  
    --- Come in here to make or update ActiveQueueTMS records  
    ---  
    Declare Order_C Cursor Local Fast_Forward for  
        Select Distinct  
            T.P_ProvKey,  
            T.T_StatusCd,  
            T.T_UID,  
            T.TP_Key,  
            T.A_Symbol,  
            T.T_TripCd,  
            T.T_TripDtTm,  
            T.T_TripDtTm_Old,  
            T.T_ArrLimoFltNum,              -- New JB 4/4/22  
            T.T_FltNum,  
            T.T_FltNum_Old,  
            T.T_EmpId,  
            T.T_EmpId_Old,  
            T.T_SentToProvDtTm,  
            TP.TP_PickUpKey,  
            TP.TP_DropOffKey,  
            case  
                when TP.TP_HotelStationCd = ''  
                     or TP.TP_HotelStationCd is null  
                    then TP.TP_PickUpKey  
                else  
                    TP.TP_HotelStationCd  
            end,                            --  TP.TP_HotelStationCd,  
            null             as T_TripDt,   -- PR.T_TripDt, -- could be null (ok)  
            T.BI_UID,  
            T.R_RefNumb,                    -- Old RefNumb  
            TP_CommissionRate,  
            TP_CommissionFlat,  
            TP.TP_FOP,  
            TP.TP_RateFlat,  
            TP.TP_RateHead,  
            TP.TP_TollAmtToDropOff,  
            TP.TP_TollAmtFromDropOff,  
            TP.TP_NoShowCharge,  
            TP.TP_MiscTaxToDropOff,  
            TP.TP_MiscTaxFromDropOff,  
            TP.TP_Gratuity,  
            TP.TP_TripTmi,  
            TP.TP_TimeRatePerMin,  
            TP.TP_WaitTimeRate,  
            TP.TP_HasTiered,  
            TP.TP_ByTierStart1,  
            TP.TP_ByTierEnd1,  
            TP.TP_ByTierRate1,  
            TP.TP_ByTierStart2,  
            TP.TP_ByTierEnd2,  
            TP.TP_ByTierRate2,  
            TP.TP_ByTierStart3,  
            TP.TP_ByTierEnd3,  
            TP.TP_ByTierRate3,  
            TP.TP_ByTierStart4,  
            TP.TP_ByTierEnd4,  
            TP.TP_ByTierRate4,  
            TP.TP_ByTierStart5,  
            TP.TP_ByTierEnd5,  
            TP.TP_ByTierRate5,  
            TP.TP_ByTierStart6,  
            TP.TP_ByTierEnd6,  
            TP.TP_ByTierRate6,  
            TP.CC_CurrencyCd,               --- New JB 6/5/20  
            Case when T.A_Symbol='JL' then Case when(select isnull(S_CountryCd, 'X')  
                                                from dbo.tblStation  
                                                where S_StationCd in (T.S_StationCd))='JPN' then iif((T.T_TripCd in ('TH', 'OH')and T.T_FltNum not in ('POSN', 'LIMO')),  
                                                                                                     -- Adjust it using Release diff!  
                                                                                                     convert(datetime, convert(char(19), DateAdd(mi, datediff(mi, isnull(L.L_ArrDtTm, T.T_TripDtTm), isnull(L.L_ReleaseDtTm, isnull(L.L_ArrDtTm, T.T_TripDtTm))
), -- How much time betw Release/Arrive  50 mins?  
                                                                                                                                             dateadd(mi, (isnull(TP.TP_PickupAdjTmi, 15)), T.T_TripDtTm)))), -- TravePair additional time (datetime)  
                                                                                                     iif((T.T_TripCd in ('TA', 'OA')and T.T_FltNum not in ('POSN', 'LIMO', 'COD')),  
                                                                                                         -- Adjust it using Report diff!  
                                                                                                         convert(datetime, convert(char(19), DateAdd(mi, -- This should be a -neg number!  
                                                                                                  datediff(mi, isnull(L.L_DepDtTm, T.T_TripDtTm), isnull(L.L_ReportDtTm, isnull(L.L_DepDtTm, T.T_TripDtTm))),   
                                     dateadd(mi, (-isnull(TP.TP_DropOffAdjTmi, 60)), T.T_TripDtTm)))),  
                                                                                                         T.T_TripDtTm))else -- Not 'JPN'... so only care about Arrive / Release records (split them), if Report keep together.  
  
                                                                                                                           -- Arrive/Release split them!  
                                  iif((T.T_TripCd in ('TH', 'OH')and T.T_FltNum not in ('POSN', 'LIMO')),  
                                                                                                                               -- Adjust it using Release diff!  
                                                                                                                               convert(datetime, convert(char(19), DateAdd(mi, datediff(mi, isnull(L.L_ArrDtTm, T.T_TripDtTm), isnull(L.L_ReleaseDtTm, isnull(L
.L_ArrDtTm, T.T_TripDtTm))), -- How much time betw Release/Arrive  50 mins?  
                                                                                                                                                                       
																																									   dateadd(mi, (isnull(TP.TP_PickupAdjTmi, 15)), T.T_TripDtTm)))), -- TravePair additional time (datetime)  
                                                                                                                               -- Depart/Report or SS or HH or LIMO don't split them  
																															   T.T_TripDtTm)End -- 'JPN'  
   else -- All other airlines!  
   T.T_TripDtTm End as AdjTripDtTm -- Adjusted Trip Times...   End 'JL'  
        From  
            dbo.tblTravelTrips_Queue   T (nolock)  
            Join  
                dbo.tblTravelPair      TP (nolock)  
                    ON T.TP_Key = TP.TP_Key  
  
            -- New JB 4/17/20  
            Join  
                dbo.tblProv            as P (nolock)  
                    ON P.P_ProvKey = T.P_ProvKey  
            join  
                dbo.tblStation         as S (nolock)  
                    ON S.S_StationCd = P.P_NearestSta  
            left join  
                dbo.tblInv             as I (nolock)  
                    on I.I_UID = T.I_UID  
            left join  
                dbo.tblLayover         as L (nolock)  
                    on L.L_UID = I.L_UID  
            Join  
                dbo.tblAirline         as A (nolock)  
                    ON A.A_Symbol = T.A_Symbol  
            join  
                dbo.tblAirlineContract as AC (nolock)  
                    ON AC.A_Symbol = T.A_Symbol  
                       AND T.T_TripDtTm  
                       between AC.AC_StartDtTm and AC.AC_EndDtTm  
        Where  
            isnull(T_PendingDtTm, '1/1/2000') < @OnceLocalDtTm  
            And T_StatusCd in (  
                                  'P', 'D', 'R'  
                              ) -- 'P' Pending, 'D' Dropped or 'R' Revised  
            --  And T_PendingCd       = 'N'     -- 'N' Not yet, 'Y' means is pending  
            and T.R_RefNumb = @R_RefNumb_Queue  
            and T.A_Symbol = @A_symbol  
            and cast(T.T_TripDtTm as date) = cast(@TripDt_Queue as date)  
        Order by  
            T.A_Symbol,  
            T.P_ProvKey,  
            T.T_TripDtTm  
  
    ---  
    ---  
    ---  
    Open Order_C  
    ---  
    ---  
    ---  
    Fetch from Order_C  
    into  
        @ProvKey,  
        @StatusCd,  
        @T_UID,  
        @TP_Key,  
        @Symbol,  
        @TripCd,  
        @TripDtTm,      -- Start time for Trip  
 @TripDtTm_Old,  -- Start time for Trip  
        @ArrLimoFltNum, -- New Jb 4/4/22  
        @FltNum,  
        @FltNum_Old,  
        @T_EmpId,  
        @T_EmpId_Old,  
        @T_SentToProvDtTm,  
        @PickUpKey,  
        @DropOffKey,  
        @HotelStationCd,  
        @PR_TripDt,  
        @BI_UIDOld,  
        @RefNumbOld,  
        @CommissionRate,  
        @CommissionFlat,  
        @FOP,  
        @RateFlat,  
        @RateHead,  
        @TollAmtToDropOff,  
        @TollAmtFromDropOff,  
        @NoShowCharge,  
        @MiscTaxToDropOff,  
        @MiscTaxFromDropOff,  
        @Gratuity,  
        @TripTmi,  
        @TimeRatePerMin,  
        @WaitTimeRate,  
        @HasTiered,  
        @ByTierStart1,  
        @ByTierEnd1,  
        @ByTierRate1,  
        @ByTierStart2,  
        @ByTierEnd2,  
        @ByTierRate2,  
        @ByTierStart3,  
        @ByTierEnd3,  
        @ByTierRate3,  
        @ByTierStart4,  
        @ByTierEnd4,  
        @ByTierRate4,  
        @ByTierStart5,  
        @ByTierEnd5,  
        @ByTierRate5,  
        @ByTierStart6,  
        @ByTierEnd6,  
        @ByTierRate6,  
        @CurrCode,  
        @AdjTripDtTm  
  
    ---  
    ---  
    ---  
    Select  
        @Cnt = 0  
    WHILE @@FETCH_STATUS = 0  
        Begin  
  
            --select 'after fetch: ', @Cnt, case when @HotelStationCd is null then 'NULL STATION' else @HotelStationCd end, @T_UID, @BI_UIDOld, @RefNumbOld  
  
            ---  
            --- For new adhoc records book the LIMO!  
            ---  
            If @StatusCd = 'P'  
                Begin  
                    GoTo Tell_Vendor  
                End  
            ---  
            --- FILTER Un-necessary changes HERE....    
            ---  
  
            -- Status Flag  (P) Pending (new), (D) Dropped, (C) Confirmed (after pending), (R) Revised,   
            --       (N) Notified (after revise)), (I) Ignore (like a drop), (X) Cancelled w/ Vendor (after drop)  
            --    (T) Terminated (went away before confirmed - after 'P')  
            If @StatusCd in (  
                                'R', 'D'  
                            )  
                Begin  
  
                    --  
                    -- Dropped by Airline, try to cancel this!  
                    --  
                    If @StatusCd = 'D'  
                        Begin  
                            GoTo Tell_Vendor  
                        End  
  
                    -- If the trip is for the future or vendor has not seen DRR  
                    If @StatusCd = 'R'  
                       and (  
                               Convert(char(10), @TripDtTm, 112) > Convert(char(10), @PR_TripDt, 112)  
                               or @PR_TripDt is null  
                           )  
                        Begin  
                            Select  
                                @Msg  
                                = 'Debug: DRR not sent yet, so filter it, TripDt: ' + convert(char(16), @TripDtTm, 20)  
                                  + ' PRTripDt: ' + convert(char(10), isnull(@PR_TripDt, '1/1/00'), 20) + ' PickUp: '  
                                  + @PickUpKey + ' DropOff: ' + @DropOffKey + ' RefNumb: '  
                                  + convert(char(10), isnull(@RefNumbOld, 0)) + ' BI_UID: '  
                                  + convert(char(10), isnull(@BI_UIDOld, 0))  
                            exec U_Debug  
                                @Symbol,  
                                @Msg,  
                                5,  
                                @ProcName,  
                                NULL,  
                                @T_UID,  
                                NULL,  
                                NULL,  
                                NULL  
  
                            --select 'NoTell 1', @Msg  
                            GoTo NoTell_Vendor  
                        End  
  
                    ---  
                    --- Don't send if after the trip  
                    ---  
                    exec C_LocalStaTm  
                        @Symbol,  
                        @HotelStationCd,  
                        @LocalStaDtTm output  
  
                    --Set @LocalStaDtTm = '1/1/2003' -- temporary for testing  
                    If @StatusCd = 'R'  
                       and (@LocalStaDtTm > @TripDtTm)  
                        Begin  
                            Select  
                                @Msg  
                                = 'Debug: Not sending a deviation notice... too late, TripDt: '  
                                  + convert(char(7), @TripDtTm, 6) + ' ProvKey: ' + convert(char(5), @ProvKey)  
                                  + ' Sta: ' + @HotelStationCd + ' CrewId: ' + rtrim(@T_EmpId)  
                                  + convert(char(5), @LocalStaDtTm, 8) + ' > Trip: ' + convert(char(7), @TripDtTm, 6)  
                                + convert(char(5), @TripDtTm, 8) + ' RefNumb: '  
                                  + convert(char(10), isnull(@RefNumbOld, 0)) + ' BI_UID: '  
                                  + convert(char(10), isnull(@BI_UIDOld, 0))  
                            exec U_Debug  
                                @Symbol,  
                                @Msg,  
                                4,  
                                @ProcName,  
                                NULL,  
                                @T_UID,  
                                NULL,  
                                @ProvKey,  
                                NULL  
                            --select 'NoTell 2', @Msg  
                            GoTo NoTell_Vendor  
                        End  
  
                    ---  
                    --- If empid has changed, tell the vendor  
                    ---  if and only if, new emp-id is a good Id  
                    ---  
                    If @StatusCd = 'R'  
                       and (@T_EmpId <> @T_EmpId_Old) -- and @T_EmpId not in ('-999', '-007', '-888', '0'))  
                        Begin  
                            ---  
                            ---  
                            Select  
                                @Msg  
                                = 'Debug: EmpId is diff (New: ' + @T_EmpId + ' Old: ' + @T_EmpId_Old + ')'  
                                  + ' TripDt: ' + convert(char(10), @TripDtTm, 20) + ' ProvKey: '  
                                  + convert(char(5), @ProvKey) + ' Sta: ' + @HotelStationCd + ' RefNumb: '  
                                  + convert(char(10), isnull(@RefNumbOld, 0)) + ' BI_UID: '  
                                  + convert(char(10), isnull(@BI_UIDOld, 0))  
                            exec U_Debug  
                                @Symbol,  
                                @Msg,  
                                4,  
                                @ProcName,  
                                NULL,  
                                NULL,  
                                NULL,  
                                @ProvKey,  
                                NULL  
  
                            --select 'Tell 3', @Msg  
                            GoTo Tell_VendorRevised  
                        ---  
                        End  
  
                    ---  
                    --- If arrive time changed by more than X (see inside if statement), tell the vendor  
                    ---  
                    If @StatusCd = 'R'  
                       and (@TripDtTm <> @TripDtTm_Old)  
                        Begin  
                            Select  
                                @DiffTm = isnull(P_TimeChgFilter, 15)  
                            From  
                dbo.tblProv (nolock)  
                            Where  
                                P_ProvKey = @ProvKey  
                            Set @CalcDiffTm = ABS(DateDiff(mi, @TripDtTm, @TripDtTm_Old))  
                            If (@CalcDiffTm > @DiffTm)  
                                Begin  
  
                                    --select * from tblMesg with (nolock) where M_text like 'Debug: DRR not sent yet, so filter it, TripDt:%' and M_Posteddttm > '12/1/2010'  
                                    Select  
                                        @Msg  
                                        = 'Debug: TripDtTm is New: ' + convert(char(16), @TripDtTm, 20) + ' Old: '  
                                          + convert(char(16), @TripDtTm_Old, 20) + ' DiffTm: '  
                                          + convert(char(4), @DiffTm) + ' CalcDiffTm: ' + convert(char(4), @CalcDiffTm)  
                                          + ' RefNumb: ' + convert(char(10), isnull(@RefNumbOld, 0)) + ' BI_UID: '  
                                          + convert(char(10), isnull(@BI_UIDOld, 0))  
                                    exec U_Debug  
                                       @Symbol,  
                                     @Msg,  
                                        4,  
                                        @ProcName,  
                                        NULL,  
                                        NULL,  
                                        NULL,  
                                        @ProvKey,  
                                        NULL  
                                    ---  
                                    --select 'Tell 4', @Msg  
                                    GoTo Tell_VendorRevised  
                                End  
                        End  
  
                    ---  
                    --- If arrive flt # changed, tell the vendor  
                    ---  
                    If @StatusCd = 'R'  
                       and (@FltNum <> @FltNum_Old)  
                       And (@TripDtTm > @LocalStaDtTm)  
                        Begin  
                            Select  
                                @Msg  
                                = 'Debug: FltNum is diff New: ' + isnull(@FltNum, 'x') + ' Old: '  
                                  + isnull(@FltNum_Old, 'x') + ' RefNumb: ' + convert(char(10), isnull(@RefNumbOld, 0))  
                                  + ' BI_UID: ' + convert(char(10), isnull(@BI_UIDOld, 0))  
                            exec U_Debug  
                                @Symbol,  
                                @Msg,  
                                4,  
                                @ProcName,  
                                NULL,  
                                @T_UID,  
                                NULL,  
                                @ProvKey,  
                                NULL  
  
                            ---  
                            --select 'Tell 5', @Msg  
                            GoTo Tell_VendorRevised  
                        ---  
                        End  
                    Select  
                        @Msg  
                        = 'Debug: Fall thru, not enough chged, Sta: ' + isnull(@HotelStationCd, 'z') + ' FltNum: '  
                          + isnull(@FltNum, 'z') + ' Old: ' + isnull(@FltNum_Old, 'z') + ' Arr: '  
                          + convert(char(7), isnull(@TripDtTm, '1/1/03'), 6)  
                          + convert(char(5), isnull(@TripDtTm, '1/1/03'), 8) + ' OldA: '  
                          + convert(char(7), isnull(@TripDtTm_Old, '1/1/03'), 6)  
                          + convert(char(5), isnull(@TripDtTm_Old, '1/1/03'), 8) + ' RefNumb: '  
                          + convert(char(10), isnull(@RefNumbOld, 0)) + ' BI_UID: '  
                          + convert(char(10), isnull(@BI_UIDOld, 0))  
                    exec U_Debug  
                        @Symbol,  
                        @Msg,  
                        4,  
                        @ProcName,  
                        NULL,  
                        @T_UID,  
                        NULL,  
                        @ProvKey,  
                        NULL  
                    GoTo NoTell_Vendor  
                    Tell_Vendor:  
  
                    --  
                    -- Test if another prior record (all fields matching) already has a BI_UID?  
                    -- If another TravelTrip is created and should be merged with an existing Pending record, the LiteQueueMerge_Trips can merge them.  ((( NOT WRITTEN YET  4/4/22 JB)))  
                    --  
                    Set @RefNumbNew = 0  
     Select @BI_UIDFoundExisting=T.BI_UID --,  
     --                      @RefNumbNew          = T.R_RefNumb  
     From dbo.tblTravelTrips_Queue T  
       Join dbo.tblTravelPair TP ON TP.TP_Key=T.TP_Key  
  
       -- New JB 4/17/20  
       Join dbo.tblProv as P(nolock)ON P.P_ProvKey=T.P_ProvKey  
       join dbo.tblStation as S(nolock)ON S.S_StationCd=P.P_NearestSta  
       left join dbo.tblInv as I(nolock)on I.I_UID=T.I_UID  
       left join dbo.tblLayover as L(nolock)on L.L_UID=I.L_UID  
       Join dbo.tblAirline as A(nolock)ON A.A_Symbol=T.A_Symbol  
       join dbo.tblAirlineContract as AC(nolock)ON AC.A_Symbol=T.A_Symbol AND T.T_TripDtTm between AC.AC_StartDtTm and AC.AC_EndDtTm  
     Where T.P_ProvKey=@ProvKey And T.T_StatusCd not in ('X', 'D') -- Not one of these... 'X' Filtered, 'D' Dropped  - Steve 10/25/2023 Don't reuse a dropped/filtered BI_UID  
        --And T.T_StatusCd  not in ('P', 'R', 'D') -- Not one of these... 'P' Pending, 'R' Revised, 'D' Dropped  
        And T.T_PendingCd<>'N' -- This means it already has a RefNumb  
        And T.T_TripCd=@TripCd  
  
        -- Give it a little room for time changes  
        And((T.T_FltNum not in ('POSN', 'LIMO', 'DUTY') -- JB added Duty 7/8/22  
          and T.T_TripDtTm between DateAdd(mi, -@BuffMins, @TripDtTm)and DateAdd(mi, @BuffMins, @TripDtTm))  
  
         -- Same for LIMO trips?  
         or(T.T_FltNum in ('POSN', 'LIMO', 'DUTY') -- JB added Duty 7/8/22  
         and((T.T_TripDtTm=@TripDtTm -- Exact match  
           and T.T_ArrLimoFltNum<>@ArrLimoFltNum) -- Ok if these don't match... the pickup is the same.  Let them share!  
          or(T.T_TripDtTm between DateAdd(mi, -@BuffPOSNMins, @TripDtTm)and DateAdd(mi, @BuffPOSNMins, @TripDtTm)and T.T_ArrLimoFltNum=@ArrLimoFltNum) -- These should be together, so allow the wiggle.  
        ) -- Did this so Diff LIMO trips did not get grouped together if the ArrLimoFlt's don't match, except if the pickup matches exactly!  JB 4/4/22  
        ))  
  
        --- New JB 6/5/20  
        And Case when T.A_Symbol='JL' then Case when(select isnull(S_CountryCd, 'X')  
                    from dbo.tblStation  
                    where S_StationCd in (T.S_StationCd))='JPN' then iif((T.T_TripCd in ('TH', 'OH')and T.T_FltNum not in ('POSN', 'LIMO')),  
                               -- Adjust it using Release diff!  
                               convert(datetime, convert(char(19), DateAdd(mi, datediff(mi, isnull(L.L_ArrDtTm, T.T_TripDtTm), isnull(L.L_ReleaseDtTm, isnull(L.L_ArrDtTm, T.T_TripDtTm))), -- How much time betw Release/Arrive  50 mins?  
                                         dateadd(mi, (isnull(TP.TP_PickupAdjTmi, 15)), T.T_TripDtTm)))), -- TravePair additional time (datetime)  
                               iif((T.T_TripCd in ('TA', 'OA')and T.T_FltNum not in ('POSN', 'LIMO', 'COD')),  
                                -- Adjust it using Report diff!  
                                convert(datetime, convert(char(19), DateAdd(mi, -- This should be a -neg number!  
                                          datediff(mi, isnull(L.L_DepDtTm, T.T_TripDtTm), isnull(L.L_ReportDtTm, isnull(L.L_DepDtTm, T.T_TripDtTm))), dateadd(mi, (-isnull(TP.TP_DropOffAdjTmi, 60)), T.T_TripDtTm)))),  
                                T.T_TripDtTm))else -- Not 'JPN'... so only care about Arrive / Release records (split them), if Report keep together.  
  
                                      -- Arrive/Release split them!  
                                      iif((T.T_TripCd in ('TH', 'OH')and T.T_FltNum not in ('POSN', 'LIMO')),  
                                       -- Adjust it using Release diff!  
                                       convert(datetime, convert(char(19), DateAdd(mi, datediff(mi, isnull(L.L_ArrDtTm, T.T_TripDtTm), isnull(L.L_ReleaseDtTm, isnull(L.L_ArrDtTm, T.T_TripDtTm))), -- How much time betw Release/Arrive  50 mins?  
                                                 dateadd(mi, (isnull(TP.TP_PickupAdjTmi, 15)), T.T_TripDtTm)))), -- TravePair additional time (datetime)  
                                       -- Depart/Report don't split them  
                                       T.T_TripDtTm)End -- 'JPN'  
         else -- All other airlines!  
          T.T_TripDtTm End -- = @AdjTripDtTm   -- 'JL'   OLD WAY  JB 4/6/22  
  
        -- Keep this value (20) bigger then the @Buff fields... otherwise, they don't find anything to group.  
        between dateadd(mi, -@BigBuffMins, @AdjTripDtTm)and dateadd(mi, @BigBuffMins, @ADjtripdttm)  
        And T.T_FltNum=@FltNum   
        And T.TP_Key=@TP_Key   
        And T.A_Symbol=@Symbol   
        And T.R_RefNumb=@R_RefNumb_Queue   
        And isnull(T.BI_UID, 0)<>0 -- This is key.  If found, we have a match.  
  
                    Set @RCnt = @@Rowcount  
  
                    --select @RCnt as ZeroCnt, @BI_UIDFoundExisting as FoundExistBIUID, @AdjTripDtTm as AdjTripDtTm, @RefNumbNew as RN  
                    If @RCnt = 0  
                        Set @BI_UIDFoundExisting = null  
  
                    --select @BI_UIDFoundExisting as BI_UID  
  
  
                    Tell_VendorRevised:  
  
                    -- If the vendor has seen this RefNumb already, create a new one (everytime a report is sent, it should have a new RefNumb)  
                    If (  
                           isnull(@RefNumbOld, 0) <= 0  
                           or @StatusCd = 'R'  
                           or @T_SentToProvDtTm is null  
                       )  
                       and isnull(@RefNumbNew, 0) = 0  
                        exec @iRet = C_GetNextRef_T  
                            @Symbol,  
                            @RefNumbNew output  
                    Else  
                        Set @RefNumbNew = case  
                                              when isnull(@RefNumbOld, 0) <= 0  
                                                  then @RefNumbNew  
                                              else  
                                                  @RefNumbOld  
                                          end  
                    If @StatusCd = 'R'  
                        Begin  
                            Insert into dbo.tblTravelTripsHistory  
                                ( --  TH_UID,  Identity  
                                    T_UID,  
                                    A_Symbol,  
                                    R_RefNumb,  
                                    BI_UID,  
                                    T_TripCd,  
                                    T_UpdatedLastDtTm,  
                                    T_SentToProvDtTm,  
                                    T_StatusCd,  
                                    P_ProvKey,  
                                    T_TripDtTm,  
                                    T_TripDtTm_Old,  
                                    T_FltNum,  
                                    T_FltNum_Old,  
                                    T_EmpId,  
 T_EmpId_Old,  
                                    TH_Notes,  
                                    TH_PostedDtTm  
                                )  
                                        Select  
                                            T_UID,  
                                            A_Symbol,  
                                            R_RefNumb,  
                                            BI_UID,  
                                            T_TripCd,  
                                            T_UpdatedLastDtTm,  
                                            T_SentToProvDtTm,  
                                            T_StatusCd,  
                                            P_ProvKey,  
                                            T_TripDtTm,  
                                            T_TripDtTm_Old,  
                                            T_FltNum,  
                                            T_FltNum_Old,  
                                            T_EmpId,  
                                            T_EmpId_Old,  
                                            'Tell vendor',  
                                            GetDate()  
                                        From  
                                            dbo.tblTravelTrips_Queue T  
                                        Where  
                                            T.TP_Key = @TP_Key  
                                            And T.T_UID = @T_UID  
                                            And T.P_ProvKey = @ProvKey  
          --And  T.T_PendingCd  = 'N'  
                        End  
  
                    --- ---------------------------------------------------------------------------------------------  
                    --- ---------------------------------------------------------------------------------------------  
                    Begin Tran Create_AQ_Tran  
  
                    ---  
                    --- Note, this updates all records for this LIMO Trip (new only)  
                    ---  
     Update T  
     Set T.R_RefNumb=case when isnull(T.R_RefNumb, 0)<=0 then @RefNumbNew else T.R_RefNumb end, T.BI_UID=isnull(@BI_UIDFoundExisting, T.BI_UID),--T.T_SentToProvDtTm = case when T.T_SentToProvDtTm is not null    
      --        then '1/1/2007'  
      --        else null  
      --       end,  
      T.T_PendingDtTm=@LocalDtTm, T.T_PendingCd='Y' -- Yes, make it appear in the TMS pending queue!  
     From dbo.tblTravelTrips_Queue T  
       Join dbo.tblTravelPair TP ON TP.TP_Key=T.TP_Key  
  
       -- New JB 4/17/20  
       Join dbo.tblProv as P(nolock)ON P.P_ProvKey=T.P_ProvKey  
       join dbo.tblStation as S(nolock)ON S.S_StationCd=P.P_NearestSta  
       left join dbo.tblInv as I(nolock)on I.I_UID=T.I_UID  
       left join dbo.tblLayover as L(nolock)on L.L_UID=I.L_UID  
       Join dbo.tblAirline as A(nolock)ON A.A_Symbol=T.A_Symbol  
       join dbo.tblAirlineContract as AC(nolock)ON AC.A_Symbol=T.A_Symbol AND T.T_TripDtTm between AC.AC_StartDtTm and AC.AC_EndDtTm  
     Where T.P_ProvKey=@ProvKey And T.T_StatusCd in ('P', 'R', 'D') -- 'P' Pending, 'R' Revised, 'D' Dropped  
        --                   And T.T_PendingCd <> 'Y' -- A little insurance here.  
        And T.T_TripCd=@TripCd  
  
        -- Give it a little room for time changes  
        And((T.T_FltNum not in ('POSN', 'LIMO', 'DUTY')and T.T_TripDtTm between DateAdd(mi, -@BuffMins, @TripDtTm)and DateAdd(mi, @BuffMins, @TripDtTm))  
  
         -- Same for LIMO trips?  
         or(T.T_FltNum in ('POSN', 'LIMO', 'DUTY')and((T.T_TripDtTm=@TripDtTm -- Exact match  
                   and T.T_ArrLimoFltNum<>@ArrLimoFltNum) -- Ok if these don't match... the pickup is the same.  Let them share!  
                     or(T.T_TripDtTm between DateAdd(mi, -@BuffPOSNMins, @TripDtTm)and DateAdd(mi, @BuffPOSNMins, @TripDtTm)and T.T_ArrLimoFltNum=@ArrLimoFltNum) -- These should be together, so allow the wiggle.  
        ) -- Did this so Diff LIMO trips did not get grouped together if the ArrLimoFlt's don't match, except if the pickup matches exactly!  JB 4/4/22  
        ))  
  
        --- New JB 6/5/20  
        And Case when T.A_Symbol='JL' then Case when(select isnull(S_CountryCd, 'X')  
                    from dbo.tblStation  
                    where S_StationCd in (T.S_StationCd))='JPN' then iif((T.T_TripCd in ('TH', 'OH')and T.T_FltNum not in ('POSN', 'LIMO')),  
                               -- Adjust it using Release diff!  
                               convert(datetime, convert(char(19), DateAdd(mi, datediff(mi, isnull(L.L_ArrDtTm, T.T_TripDtTm), isnull(L.L_ReleaseDtTm, isnull(L.L_ArrDtTm, T.T_TripDtTm))), -- How much time betw Release/Arrive  50 mins?  
                                         dateadd(mi, (isnull(TP.TP_PickupAdjTmi, 15)), T.T_TripDtTm)))), -- TravePair additional time (datetime)  
                               iif((T.T_TripCd in ('TA', 'OA')and T.T_FltNum not in ('POSN', 'LIMO', 'COD')),  
                                -- Adjust it using Report diff!  
                                convert(datetime, convert(char(19), DateAdd(mi, -- This should be a -neg number!  
                                          datediff(mi, isnull(L.L_DepDtTm, T.T_TripDtTm), isnull(L.L_ReportDtTm, isnull(L.L_DepDtTm, T.T_TripDtTm))), dateadd(mi, (-isnull(TP.TP_DropOffAdjTmi, 60)), T.T_TripDtTm)))),  
                                T.T_TripDtTm))else -- Not 'JPN'... so only care about Arrive / Release records (split them), if Report keep together.  
  
                                      -- Arrive/Release split them!  
                                      iif((T.T_TripCd in ('TH', 'OH')and T.T_FltNum not in ('POSN', 'LIMO')),  
                                       -- Adjust it using Release diff!  
                                       convert(datetime, convert(char(19), DateAdd(mi, datediff(mi, isnull(L.L_ArrDtTm, T.T_TripDtTm), isnull(L.L_ReleaseDtTm, isnull(L.L_ArrDtTm, T.T_TripDtTm))), -- How much time betw Release/Arrive  50 mins?  
                                                 dateadd(mi, (isnull(TP.TP_PickupAdjTmi, 15)), T.T_TripDtTm)))),-- TravePair additional time (datetime)  
                                       -- Depart/Report don't split them  
                                       T.T_TripDtTm)End -- 'JPN'  
         else -- All other airlines!  
          T.T_TripDtTm End  
  
        -- Keep this value bigger then the @Buff fields... otherwise, they don't find anything to group.  
        between dateadd(mi, -@BigBuffMins, @AdjTripDtTm)and dateadd(mi, @BigBuffMins, @ADjtripdttm)And T.T_FltNum=@FltNum And T.TP_Key=@TP_Key And T.A_Symbol=@Symbol  
     --And T.T_UID    = @T_UID  -- New JB 4/6/22  Now it's one at a time.                      
  
                    ---  
                    ---  
                    Set @RCnt = @@ROWCOUNT  
                    Set @Err = @@ERROR  
  
                    --select @RCnt as FirstCnt, @BI_UIDFoundExisting as FoundExistBIUID, @AdjTripDtTm as AdjTripDtTm,  
                    --@ProvKey,@TripCd, @BuffMins as BufM, @ArrLimoFltNum as ARRL, @BuffPOSNMins as BuffPo, @BigBuffMins as BigB  
                    Set @BI_UIDFoundExisting = null  
                    If @ERR <> 0  
                        Begin  
                            RollBack Tran Create_AQ_Tran  
                            Select  
                                @Msg  
                                = 'Error: Updating TravelTrip QueueMgt_Trips() for RefNumb: '  
                                  + convert(char(10), isnull(@RefNumbNew, 0)) + ' Error: ' + convert(char(5), @ERR)  
                            exec U_Debug  
                                @Symbol,  
                                @Msg,  
                                0,  
                                @ProcName,  
                               NULL,  
                                @T_UID,  
                                NULL,  
                                @ProvKey,  
                                NULL  
                        End  
                    Else  
                        Begin  
                            Commit Tran Create_AQ_Tran  
                            Select  
                                @BI_UIDFoundExisting = T.BI_UID  
                            From  
                                dbo.tblTravelTrips_Queue T  
                                Join  
                                    dbo.tblTravelPair    TP  
                                        ON TP.TP_Key = T.TP_Key  
                            Where  
                                T.T_UID = @T_UID -- This is really the only one that matters  
                                And T.P_ProvKey = @ProvKey  
                                And T.T_TripCd = @TripCd  
                                And T.A_Symbol = @Symbol  
                            If isnull(@BI_UIDFoundExisting, 0) = 0  
                                Set @Skip_MakeBillId = 0 -- Need to still assign a new BI_UID  
                            Else  
                                Set @Skip_MakeBillId = 1 -- No need to assign, already has one!  
                        End  
                    If @Skip_MakeBillId = 0  
                        Begin  
                            ---  
                            --- Make (Or Update) the ActiveQueue record for this Group of orders.  
                            ---  
                            exec @iRet = C_MakeBillId  
                                @BI_UID output,  
                                @Symbol,  
                                @TripCd,  
                          @RefNumbNew,  
@StatusCd,  
                                @ProvKey,  
                                @HotelStationCd,  
                                @LocalDtTm,  
                                @TripDtTm,     -- TripDtTm  
                                @FltNum,       -- FltNum  
                                @TripDtTm_Old, -- Old TripDtTm  
                                @FltNum_OLd,   -- Old FltNum  
                                @CommissionRate,  
                                @CommissionFlat,  
                                @FOP,  
                                @RateFlat,  
                                @RateHead,  
                                @TollAmtToDropOff,  
                                @TollAmtFromDropOff,  
                                @NoShowCharge,  
                                @MiscTaxToDropOff,  
                                @MiscTaxFromDropOff,  
                                @Gratuity,  
                                @TripTmi,  
                                @TimeRatePerMin,  
                                @WaitTimeRate,  
                                @HasTiered,  
                                @ByTierStart1,  
                                @ByTierEnd1,  
                                @ByTierRate1,  
                                @ByTierStart2,  
                                @ByTierEnd2,  
                                @ByTierRate2,  
                                @ByTierStart3,  
                                @ByTierEnd3,  
                                @ByTierRate3,  
                                @ByTierStart4,  
                                @ByTierEnd4,  
                                @ByTierRate4,  
                                @ByTierStart5,  
                                @ByTierEnd5,  
                                @ByTierRate5,  
                                @ByTierStart6,  
                                @ByTierEnd6,  
                                @ByTierRate6,  
                                @CurrCode  
                            If @iRet <> 0  
                              Begin  
                                    ---  
                                    --- So the Filter code below does not kick in...  
                                    ---  
                                    Select  
                                        @Msg  
                                        = 'Error: BillId_Trip insert failed in QueueMgt_Trips() for RefNumb: '  
                                          + convert(char(10), isnull(@RefNumbNew, 0)) + ' ErrorRet: '  
                                          + convert(char(5), @iRet)  
                                    exec U_Debug  
                                        @Symbol,  
                                        @Msg,  
                                        0,  
                                        @ProcName,  
                                        NULL,  
                                        @T_UID,  
                                        NULL,  
                                        @ProvKey,  
                                        NULL  
                                End  
                            If @BI_UID > 0  
                                Begin  
  
                                    --  
                                    -- This finds the current record (T_UID) in certain situations also (when the new TripDtTm is > 120 min from existing TravelTrips records - it gets it's own BI_UID  
                                    --  
                                    Update  
                                        T  
                                    Set  
                                        T.BI_UID = @BI_UID  
                                    From  
                                        dbo.tblTravelTrips_Queue T  
                                    Where  
                                        T.TP_Key = @TP_Key  
                       And T.T_TripCd = @TripCd  
  
  -- Give it a little room for time changes  
                                        And (  
                                                (  
                                                    T.T_FltNum not in (  
                                                                          'POSN', 'LIMO'  
                                                                      )  
                                                    and T.T_TripDtTm  
                                        between DateAdd(mi, -@BuffMins, @TripDtTm) and DateAdd(mi, @BuffMins, @TripDtTm)  
                                                )  
  
                                                -- Same for LIMO trips?  
                                                or (  
                                                       T.T_FltNum in (  
                                                                         'POSN', 'LIMO'  
                                                                     )  
                                                       and (  
                                                               (  
                                                                   T.T_TripDtTm = @TripDtTm -- Exact match  
                                                                   and T.T_ArrLimoFltNum <> @ArrLimoFltNum  
                                                               ) -- Ok if these don't match... the pickup is the same.  Let them share!  
                                                               or (  
                                                                      T.T_TripDtTm  
                                        between DateAdd(mi, -@BuffPOSNMins, @TripDtTm) and DateAdd(  
                                                                                                      mi,  
                                                                                                      @BuffPOSNMins,  
                                                                                     @TripDtTm  
                                                                                                  )  
                                                                      and T.T_ArrLimoFltNum = @ArrLimoFltNum  
                                                                  ) -- These should be together, so allow the wiggle.  
                                                           ) -- Did this so Diff LIMO trips did not get grouped together if the ArrLimoFlt's don't match, except if the pickup matches exactly!  JB 4/4/22  
                                                   )  
                                            )  
                                        And T.T_FltNum = @FltNum  
                                        And T.A_Symbol = @Symbol  
                                        And T.P_ProvKey = @ProvKey  
                                        And T.R_RefNumb <> 0  
                                        And T.T_PendingCd = 'Y'  
                                        And isnull(T.BI_UID, 0) = 0 -- Don't do it if it already has a BI_UID  
                                    Set @RCnt = @@RowCount  
  
                                    --select @RCnt as SecondCnt, @BI_UID as NewBIUID  
                                    If @RCnt = 0  
                                        Begin  
                                            ---  
                                            --- If update fails?  
                                            ---  
                                            Select  
                                                @Msg  
                                                = 'Warning: Update to BillId_Trip failed in QueueMgt_Trips() for RefNumb: '  
                                                  + convert(char(10), isnull(@RefNumbNew, 0)) + ' ErrorRet: '  
                    + convert(char(5), @RCnt)  
                                            exec U_Debug  
                                  @Symbol,  
                                                @Msg,  
                                                2,  
                                                @ProcName,  
                                                NULL,  
                                                @T_UID,  
                                                NULL,  
                                                @ProvKey,  
                                                NULL  
                                        End  
  
  
                                End -- end @BI_UID > 0  
                        End -- end If @Skip_MakeBillId = 0  
                    Select  
                        @iRet = 1  
  
                    --- ---------------------------------------------------------------------------------------------   
                    --- ---------------------------------------------------------------------------------------------  
                    GoTo SkipToNextRec  
                End -- If in ('R', 'D') StatusCd  
            NoTell_Vendor:  
  
            -- If Revised, clean up flag if not telling vendor!  
            If @StatusCd = 'R'  
                Begin  
  
                    -- Keep history of what happened.  
                    Insert into dbo.tblTravelTripsHistory  
                        ( --  TH_UID,  Identity  
                            T_UID,  
                            A_Symbol,  
                            R_RefNumb,  
                            BI_UID,  
                            T_TripCd,  
                            T_UpdatedLastDtTm,  
                            T_SentToProvDtTm,  
                            T_StatusCd,  
                            P_ProvKey,  
                            T_TripDtTm,  
                            T_TripDtTm_Old,  
       T_FltNum,  
                            T_FltNum_Old,  
                            T_EmpId,  
                            T_EmpId_Old,  
                            TH_Notes,  
                            TH_PostedDtTm  
                        )  
                                Select  
                                    T_UID,  
                                    A_Symbol,  
                                    R_RefNumb,  
                                    BI_UID,  
                                    T_TripCd,  
                                    T_UpdatedLastDtTm,  
                                    T_SentToProvDtTm,  
                                    T_StatusCd,  
                                    P_ProvKey,  
                                    T_TripDtTm,  
                                    T_TripDtTm_Old,  
                                    T_FltNum,  
                                    T_FltNum_Old,  
                                    T_EmpId,  
                                    T_EmpId_Old,  
                                    'NoTell vendor',  
                                    GetDate()  
                                From  
                                    dbo.tblTravelTrips_Queue T  
                                Where  
                                    T.TP_Key = @TP_Key  
                                    And T.T_UID = @T_UID  
                                    And T.P_ProvKey = @ProvKey  
                    --And  T.T_PendingCd  = 'N'  
  
                    -- Update the Pending flag to Confirmed (they don't need to be notified for this trip)  
                    Update  
                        T  
                    Set  
                        T.T_PendingCd = 'C',  
                        T.T_TimeChgInd = case  
                                             when T.T_TripDtTm_Old <> T.T_TripDtTm  
                                                 then 1  
                                             else  
                                                 0  
                    end,  
                        T.T_FltNumChgInd = case  
                                               when T.T_FltNum_Old <> T.T_FltNum  
                                                   then 1  
                                               else  
                                                   0  
                                           end,  
                        T.T_EmpChgInd = case  
                                            when T.T_EmpId_Old <> T.T_EmpId  
                                                then 1  
                                            else  
                                                0  
                                        end,  
                        T.T_FltNum_Old = T.T_FltNum,  
                        T.T_TripDtTm_Old = T.T_TripDtTm,  
                        T.T_EmpId_Old = T.T_EmpId  
  
                    --T.T_SentToProvDtTm = null  
                    From  
                        dbo.tblTravelTrips_Queue T  
                    Where  
                        T.TP_Key = @TP_Key  
                        And T.T_UID = @T_UID  
                        And T.P_ProvKey = @ProvKey  
                        And T.T_PendingCd = 'N'  
                    Set @RCnt = @@RowCount  
                    If @RCnt > 0  
                        Begin  
                            Update  
                                BI  
                            Set  
                                BI.T_FltNum_Prior = BI.T_FltNum,  
                                BI.T_TripDtTm_Prior = BI.T_TripDtTm  
                            From  
                                dbo.tblBillId_Trip BI  
                            Where  
                                BI.BI_UID = @BI_UIDOld  
                                And BI.P_ProvKey = @ProvKey  
             And (  
                                        BI.T_FltNum_Prior <> BI.T_FltNum  
                                        Or BI.T_TripDtTm_Prior <> BI.T_TripDtTm  
                                    )  
                            Set @RCnt2 = @@RowCount  
  
                            ---  
                            --- If update fails?  
                            ---  
                            Select  
                                @Msg  
                                = 'Debug: Set PendingCd to C, No need to notify vendor, TripId: '  
                                  + convert(char(10), isnull(@BI_UIDOld, 0)) + ' T_UID: '  
                                  + convert(char(10), isnull(@T_UID, 0)) + ' TripCd: ' + convert(char(3), @TripCd)  
                                  + ' TripDt: ' + convert(char(16), @TripDtTm, 20) + ' ProvKey: '  
                                  + convert(char(5), @ProvKey) + ' Sta: ' + @HotelStationCd + ' CountT: '  
                                  + convert(char(5), isnull(@RCnt, 0)) + ' CountBI: '  
                                  + convert(char(5), isnull(@RCnt2, 0))  
                            exec U_Debug  
                                @Symbol,  
                                @Msg,  
                                5,  
                                @ProcName,  
                                NULL,  
                                @T_UID,  
                                NULL,  
                                @ProvKey,  
                                NULL  
                        End  
                End  
            SkipToNextRec:  
            Set @BI_UIDOld = 0  
            ---  
            --- Get NEXT record  
            ---  
            Fetch from Order_C  
            into  
                @ProvKey,  
                @StatusCd,  
                @T_UID,  
                @TP_Key,  
                @Symbol,  
                @TripCd,  
                @TripDtTm,      -- Start time for Trip  
                @TripDtTm_Old,  -- Start time for Trip  
                @ArrLimoFltNum, -- New JB 4/4/22  
                @FltNum,  
                @FltNum_Old,  
                @T_EmpId,  
                @T_EmpId_Old,  
                @T_SentToProvDtTm,  
                @PickUpKey,  
                @DropOffKey,  
                @HotelStationCd,                  @PR_TripDt,  
                @BI_UIDOld,  
                @RefNumbOld,  
                @CommissionRate,  
                @CommissionFlat,  
                @FOP,  
                @RateFlat,  
                @RateHead,  
                @TollAmtToDropOff,  
                @TollAmtFromDropOff,  
                @NoShowCharge,  
                @MiscTaxToDropOff,  
                @MiscTaxFromDropOff,  
                @Gratuity,  
                @TripTmi,  
                @TimeRatePerMin,  
                @WaitTimeRate,  
                @HasTiered,  
                @ByTierStart1,  
                @ByTierEnd1,  
                @ByTierRate1,  
                @ByTierStart2,  
                @ByTierEnd2,  
                @ByTierRate2,  
                @ByTierStart3,  
                @ByTierEnd3,  
                @ByTierRate3,  
                @ByTierStart4,  
                @ByTierEnd4,  
                @ByTierRate4,  
                @ByTierStart5,  
                @ByTierEnd5,  
                @ByTierRate5,  
                @ByTierStart6,  
                @ByTierEnd6,  
                @ByTierRate6,  
                @CurrCode,  
                @AdjTripDtTm  
            Select  
                @Cnt = @Cnt + 1  
  
        --if @Cnt > 3 break  
        End  
    -- End while CC loop  
  
    ---  
    ---  
    Close Order_C  
    Deallocate Order_C  
  
    --  
    -- Fix/Heal miss matched BillingTrip records with TravelTrips records.  
    --  
 Declare @UpdTable table  
        (  
            BI_UID  int,  
            RefNumb int  
        )  
    Insert into @UpdTable  
        (  
            BI_UID,  
            RefNumb  
        )  
                Select  
                    B.BI_UID,  
                    B.R_RefNumb  
                FROM  
                    tblBillId_Trip           AS B  
                    LEFT JOIN  
                        tblTravelTrips_queue AS T  
                            ON T.R_RefNumb = B.R_RefNumb  
                               AND T.A_Symbol = B.A_Symbol  
                WHERE  
                    (T.R_RefNumb IS NULL)  
    UPDATE  
        T  
    Set  
        T.R_RefNumb = Tmp.RefNumb,  
        T.T_UpdatedLastDtTm = getdate()  
    From  
        @UpdTable                    as Tmp  
        JOIN  
            dbo.tblTravelTrips_Queue as T  
                ON T.BI_UID = Tmp.BI_UID  
    --Where T.BI_UID = 14204  
    Set @RCnt = @@RowCount  
    If @RCnt > 0  
        Begin  
            ---  
            --- If update fails?  
            ---  
            Select  
                @Msg  
                = 'Debug: Updated TravelTrips using BillId_Trip RefNumbs: ' + ' CntRet: ' + convert(char(5), @RCnt)  
            exec U_Debug  
                '**',  
                @Msg,  
                5,  
                @ProcName,  
                NULL,  
                NULL,  
                NULL,  
                NULL,  
                NULL  
        End  
    INSERT INTO [dbo].[tblTravelTrips]  
        (  
            [TP_Key],  
            [I_UID],  
            [CP_UID],  
            [R_RefNumb],  
            [BI_UID],  
            [T_TripCd],  
            [T_UpdatedLastDtTm],  
            [T_SentToProvDtTm],  
            [T_PendingDtTm],  
            [T_PendingCd],  
            [T_StatusCd],  
            [P_ProvKey],  
            [T_SourceCd],  
            [T_CreatedByWho],  
            [T_ClearCustomsInd],  
            [S_StationCd],  
            [T_TripDtTm],  
            [T_TripDtTm_Old],  
            [MTF_UID],  
            [A_Symbol],  
            [T_FltNum],  
            [T_FltNum_Old],  
            [T_DeadHeadInd],  
            [T_ArrLimoFltNum],  
            [T_EmpId],  
            [T_EmpId_Old],  
            [T_CrewType],  
            [T_TimeChgInd],  
            [T_FltNumChgInd],  
            [T_EmpChgInd],  
            [T_HeadCountChgInd],  
            [T_WaitTmi],  
   [T_TZOffset],  
            [T_CostCenter],  
            [PA_Key],  
            [T_RateHeadOverRide],  
            [T_ConfNumb],  
            [T_ConfName],  
            [T_ConfDtTm],  
            [T_ConfByCSR],  
            [T_NotifiedDtTm],  
            [T_NotifiedByCSR],  
            [T_CancelNumb],  
            [T_CancelName],  
            [T_CancelDtTm],  
            [T_CancelByCSR],  
            [T_CancelResultCd],  
            [T_IgnoreFlg],  
            [T_CancelDeadlineDtTm],  
            [T_NoShowDtTm],  
            [T_Notes],  
            [T_PostedDtTm]  
        )  
                select  
                    [TP_Key],  
                    [I_UID],  
                    [CP_UID],  
                    [R_RefNumb],  
                    [BI_UID],  
                    [T_TripCd],  
                    [T_UpdatedLastDtTm],  
                    [T_SentToProvDtTm],  
                    [T_PendingDtTm],  
                    [T_PendingCd],  
                    [T_StatusCd],  
                    [P_ProvKey],  
                    [T_SourceCd],  
                    [T_CreatedByWho],  
                    [T_ClearCustomsInd],  
                    [S_StationCd],  
                    [T_TripDtTm],  
                    [T_TripDtTm_Old],  
                    [MTF_UID],  
                    [A_Symbol],  
                    [T_FltNum],  
            [T_FltNum_Old],  
                    [T_DeadHeadInd],  
                    [T_ArrLimoFltNum],  
                    [T_EmpId],  
                    [T_EmpId_Old],  
                    [T_CrewType],  
                    [T_TimeChgInd],  
                    [T_FltNumChgInd],  
                    [T_EmpChgInd],  
                    [T_HeadCountChgInd],  
                    [T_WaitTmi],  
                    [T_TZOffset],  
                    [T_CostCenter],  
                    [PA_Key],  
                    [T_RateHeadOverRide],  
                    [T_ConfNumb],  
                    [T_ConfName],  
                    [T_ConfDtTm],  
                    [T_ConfByCSR],  
                    [T_NotifiedDtTm],  
                    [T_NotifiedByCSR],  
                    [T_CancelNumb],  
                    [T_CancelName],  
                    [T_CancelDtTm],  
                    [T_CancelByCSR],  
                    [T_CancelResultCd],  
                    [T_IgnoreFlg],  
                    [T_CancelDeadlineDtTm],  
                    [T_NoShowDtTm],  
                    @TNotes,  
                    getdate()  
                from  
                    tblTravelTrips_Queue  
                where  
                    R_RefNumb > 0 
                    and cast(T_TripDtTm as date) = @TripDt_Queue  
                    and TP_Key is not null;  
  
    select distinct  
        R_RefNumb as RefNumb  
    from  
        tblTravelTrips_Queue  
    where  
        T_Notes  = cast(@R_RefNumb_Queue as varchar)  
        and cast(T_TripDtTm as date) = @TripDt_Queue  
        and TP_Key is not null;  
   
 Insert into  [dbo].[tblTravelTrips](  
   --[T_UID] [int] IDENTITY(10000,1) NOT NULL,  
   [TP_Key],    [I_UID],   [CP_UID],   
   [R_RefNumb],     
   [T_TripCd],  
   [T_UpdatedLastDtTm], [T_SentToProvDtTm], [T_PendingDtTm],  
   [T_PendingCd],  
   [T_StatusCd],   [P_ProvKey],  [T_SourceCd],  
   [T_ClearCustomsInd],  
   [S_StationCd],  
   [T_TripDtTm],   [T_TripDtTm_Old], [MTF_UID],  
   [A_Symbol],    [T_FltNum],   [T_FltNum_Old],  
   [T_ArrLimoFltNum],  [T_EmpId],     
   [T_EmpId_Old],   
   [T_CrewType],  
   [T_TimeChgInd],  
   [T_FltNumChgInd],  [T_HeadCountChgInd],[T_WaitTmi],  
   [T_TZOffset],   [T_CostCenter],  [PA_Key],  
   [T_RateHeadOverRide],   
   [T_CreatedByWho],  
   [T_ConfNumb],    
   [T_ConfName],     
   [T_ConfDtTm],    
   [T_ConfByCSR],    
   [T_CancelNumb],     
   [T_CancelName],    
   [T_CancelDtTm],    
   [T_CancelByCSR],    
   [T_CancelResultCd],   
   [T_CancelDeadlineDtTm], -- More on this later  
   [T_NoShowDtTm],     
   [T_Notes],  
   [T_PostedDtTm]  
  )  
  
 SELECT Distinct  
   @TP_Key_New,    [I_UID],   [CP_UID],   
   0,     
   [T_TripCd],  
   [T_UpdatedLastDtTm], [T_SentToProvDtTm], [T_PendingDtTm],  
   [T_PendingCd],  
   [T_StatusCd],   @P_ProvKey_New,  [T_SourceCd],  
   [T_ClearCustomsInd],  
   [S_StationCd],  
   [T_TripDtTm],   [T_TripDtTm_Old], [MTF_UID],  
   [A_Symbol],    [T_FltNum],   [T_FltNum_Old],  
   [T_ArrLimoFltNum],  [T_EmpId],     
   [T_EmpId_Old],   
   [T_CrewType],  
   [T_TimeChgInd],  
   [T_FltNumChgInd],  [T_HeadCountChgInd],[T_WaitTmi],  
   [T_TZOffset],   [T_CostCenter],  @PA_Key_New,  
   [T_RateHeadOverRide],   
   [T_CreatedByWho],  
   [T_ConfNumb],    
   [T_ConfName],     
   [T_ConfDtTm],    
   [T_ConfByCSR],    
   [T_CancelNumb],     
   [T_CancelName],    
   [T_CancelDtTm],    
   [T_CancelByCSR],    
   [T_CancelResultCd],   
   [T_CancelDeadlineDtTm], -- More on this later  
   [T_NoShowDtTm],     
   @TNotes,  
   [T_PostedDtTm]  
  
  From tblTravelTrips_Queue  
   where A_Symbol = @A_symbol  
   and TP_PickUpCd = @TP_PickupCD_New  
   and TP_PickUpKey = @TP_PickupKey_New  
   and TP_DropOffCd = @TP_DropOffCD_New  
   and TP_DropOffKey = @TP_FropOffKey_New  
  
     Insert into  [dbo].[tblTravelTrips_Queue_Arch](  
            --[T_UID] [int] IDENTITY(10000,1) NOT NULL,  
            [TP_Key],               [I_UID],            [CP_UID],   
            [R_RefNumb],              
            [T_TripCd],  
            [T_UpdatedLastDtTm],    [T_SentToProvDtTm], [T_PendingDtTm],  
            [T_PendingCd],  
            [T_StatusCd],           [P_ProvKey],        [T_SourceCd],  
            [T_ClearCustomsInd],  
            [S_StationCd],  
            [T_TripDtTm],           [T_TripDtTm_Old],   [MTF_UID],  
            [A_Symbol],             [T_FltNum],         [T_FltNum_Old],  
            [T_ArrLimoFltNum],      [T_EmpId],            
            [T_EmpId_Old],    
            [T_CrewType],  
            [T_TimeChgInd],  
            [T_FltNumChgInd],       [T_HeadCountChgInd],[T_WaitTmi],  
            [T_TZOffset],           [T_CostCenter],     [PA_Key],  
            [T_RateHeadOverRide],     
            [T_CreatedByWho],  
            [T_ConfNumb],         
            [T_ConfName],             
            [T_ConfDtTm],         
            [T_ConfByCSR],        
            [T_CancelNumb],           
            [T_CancelName],       
            [T_CancelDtTm],       
            [T_CancelByCSR],          
            [T_CancelResultCd],   
            [T_CancelDeadlineDtTm], -- More on this later  
            [T_NoShowDtTm],           
            [T_Notes],  
            [T_PostedDtTm]  
        )  
        SELECT Distinct  
            @TP_Key_New,                [I_UID],            [CP_UID],   
            0,            
            [T_TripCd],  
            [T_UpdatedLastDtTm],    [T_SentToProvDtTm], [T_PendingDtTm],  
            [T_PendingCd],  
            [T_StatusCd],           @P_ProvKey_New,     [T_SourceCd],  
            [T_ClearCustomsInd],  
            [S_StationCd],  
            [T_TripDtTm],           [T_TripDtTm_Old],   [MTF_UID],  
            [A_Symbol],             [T_FltNum],         [T_FltNum_Old],  
            [T_ArrLimoFltNum],      [T_EmpId],            
            [T_EmpId_Old],    
            [T_CrewType],  
            [T_TimeChgInd],  
            [T_FltNumChgInd],       [T_HeadCountChgInd],[T_WaitTmi],  
            [T_TZOffset],           [T_CostCenter],     @PA_Key_New,  
            [T_RateHeadOverRide],     
            [T_CreatedByWho],  
            [T_ConfNumb],         
            [T_ConfName],             
            [T_ConfDtTm],         
            [T_ConfByCSR],        
            [T_CancelNumb],           
            [T_CancelName],       
            [T_CancelDtTm],       
            [T_CancelByCSR],          
            [T_CancelResultCd],   
            [T_CancelDeadlineDtTm], -- More on this later  
            [T_NoShowDtTm],           
            [T_Notes],  
            [T_PostedDtTm]  
        From    tblTravelTrips_Queue  
            where A_Symbol = @A_symbol  
            and TP_PickUpCd = @TP_PickupCD_New  
            and TP_PickUpKey = @TP_PickupKey_New  
            and TP_DropOffCd = @TP_DropOffCD_New  
            and TP_DropOffKey = @TP_FropOffKey_New  
  
    Delete from tblTravelTrips_Queue  
    where A_Symbol = @A_symbol  
            and TP_PickUpCd = @TP_PickupCD_New  
            and TP_PickUpKey = @TP_PickupKey_New  
            and TP_DropOffCd = @TP_DropOffCD_New  
            and TP_DropOffKey = @TP_FropOffKey_New;  


Completion time: 2025-06-06T00:43:19.2941368-04:00
