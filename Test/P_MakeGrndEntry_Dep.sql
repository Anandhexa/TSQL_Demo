Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE       PROC [dbo].[P_MakeGrndEntry_Dep]
    (
        @A_Symbol             char(2),
        @R_RefNumb            int,
        @R_RefNumber_Grnd_Dep int output,
        @R_RefNumber_Exists   int output
    )


/*
	declare @R_RefNumber_Grnd_Arr int, @R_RefNumber_Exists int
	exec [dbo].[P_MakeGrndEntry_Arr] 'AA',1167822,@R_RefNumber_Grnd_Arr output,@R_RefNumber_Exists output
	select @R_RefNumber_Grnd_Arr,@R_RefNumber_Exists

*/

 /****************************************************************************
 * Revisions:
 * Date			By			Description
 * 12/10/2024	Chris A		LOD-32085 using O_UID for mockRefNumb to avoid collision with the mockRefNumb generated on the arrival side
							Passing CP_UID of -1 to avoid incorrect cancelations
 ****************************************************************************/

AS
    DECLARE
		@Debug			 int = 0,
		@ProcFlag		 int,
        @LocalDtTm       datetime,
        @Msg             varchar(200),
        @RCntSS          int,
        @RCntTATH        int,
        @Err             int,
        @BuffMin         int,
        @ProcName        varchar(128),
        @T_UID           int,
        @TxtStr          varchar(500),
        @TripCd          char(2),
        @DepStationCd    char(5),
        @ArrStationCd    char(5),
        @LvrStationCd    char(5),
        @HotelKey        varchar(8), --Changed length 6 to 8 7/7/2022 Subhrajit
        @TimeZone        int,
        @CountryCd       char(3),
        @DepFltNum       FlightNumb,
        @ArrFltNum       FlightNumb,
        @ArrDtTm         FlightDtTm,
        @DepDtTm         FlightDtTm,
        @CostCenter      char(10),
        @Notes           varchar(255),
        @BidPeriod       char(10),
        @EmpId           char(12),
        @CrewPos         char(4),
        @NameFirst       char(15),
        @NameLast        char(20),
        @ArrDeadhead     varchar(2),
        @DepDeadhead     varchar(2),
        @HotCrew         varchar(2),
        @Domicile        char(4),
        @EnterByWho      ByWho,
        @ArrDt           date,
        @DepDt           date,
        @TP_Key_1W       int,
        @TP_Key_2W       int,
        @P_ProvKey_1W    int,
        @P_ProvKey_2W    int,
        @P_ProvAssign_1W int,
        @P_ProvAssign_2W int,
        @iRet            int,
        @MockRef         int,
        @ExistingRef     int;


    Set @BuffMin = 180 -- 3 Hours
    exec U_ProcName
        @ProcName output,
        @@PROCID
    SET NOCOUNT ON
    Set @T_UID = -2
    EXEC dbo.U_LocalDtTm
        @LocalDtTm OUTPUT

    select
        @ArrStationCd = O.L_ArrStaCd,
        @DepStationCd = O.L_DepStaCd,
        @LvrStationCd = H.H_NearestSta,
        @ArrStationCd = O.L_ArrStaCd,
        @DepStationCd = O.L_DepStacd,
        @ArrDt        = cast(O.L_Arrdttm as date),
        @DepDt        = cast(O.L_DepDtTm as date),
        @ArrDtTm      = O.L_ArrDttm,
        @DepDtTm      = O.L_DepDttm,
        @MockREf      = cast(O.O_UID * -1 as int), --12/12/24 - LOD-32085 - using O_UID to avoid same mock ref number as Arrival leg travelTrip_queue records
        @DepFltNum    = O.L_DepFltNum,
        @ArrFltNum    = O.L_Arrfltnum,
        @EmpId        = O.L_Empid,
        @TripCd       = case
                            when O.L_ArrStaCd = H.H_NearestSta
                                then 'TA'
                            else
                                'OA'
                        end
    from
        tblOrder     O
        join
            tblHotel H
                on H.H_HotelKey = O.H_HotelKey
    where
        O.A_Symbol = @A_Symbol
        and O.R_RefNumb = @R_RefNumb



    --Validation to find valid trips with matching trips dates and trip times
    IF EXISTS
        (
            SELECT
                1
            from
                tbltraveltrips TT
                join
                    tblOrder  O
                        on O.I_UID = TT.I_UID
                           and O.A_Symbol = TT.A_Symbol
            where
                O.R_RefNumb = @R_RefNumb
                and TT.T_TripCd in (
                                       'TA', 'OA'
                                   )
                and TT.T_CancelResultCd = 0
                and TT.T_FltNum = @DepFltNum
                and cast(TT.T_TRipdttm as date) = @DepDt
				And TT.T_StatusCd			not in ('X', 'D')

        )
        begin --FOUND MATCH Validation to find valid trips with matching trips dates and trip times 
		if @Debug = 1
			begin
            select
                'Found Match'
			end
            set @R_RefNumber_Exists = 1;

        /*
 Update TD
	
	Set	T_StatusCd			= case when TD.T_StatusCd in ('C', 'N', 'R') or RN.R_RefNumb is not null    -- Removed the T_ConfDtTm (everywhere) since the StatusCd can't get set without this also getting set!  JB 11/8/21
									then 'D'		-- Dropped
									else 'X'		-- Cancelled, since vendor did NOT know about it yet.
							  end,
		T_CancelResultCd	= case when TD.T_StatusCd in ('C', 'N', 'R') or RN.R_RefNumb is not null
									then T_CancelResultCd		-- Don't update it
									else 3						-- Hardcoded - before vendor knew about it
							  end,

		T_Notes						= case when TD.T_TripCd = 'TA' then 'DepSta Swap Drop: ' else 'DepSta Swap Drop: ' end + trim(TP.TP_PickUpKey),							  

	  	T_CancelByCSR		= case when TD.T_StatusCd in ('C', 'N', 'R') or RN.R_RefNumb is not null
									then T_CancelByCSR			-- Don't update it
									else 'dbo'					-- Hardcoded - who did it
							  end,
		T_PendingCd			= case when TD.T_StatusCd in ('C', 'N', 'R') or RN.R_RefNumb is not null
									then 'Y'
									else TD.T_PendingCd  --'N'
							  end,
		T_UpdatedLastDtTm	= @LocalDtTm



	From		dbo.tblInv				I	(nolock)
	Join		dbo.tblLayover			L	(nolock) ON L.L_UID				= I.L_UID
													AND L.A_Symbol			= I.A_Symbol
	Join		dbo.tblAirlineContract	AC  (nolock) ON AC.A_Symbol			= I.A_Symbol	
	Join		dbo.tblTravelTrips		TD	(nolock) ON I.I_UID				= TD.I_UID
													AND I.A_Symbol			= TD.A_Symbol
	Join		dbo.tblTravelPair		TP	(nolock) ON TP.A_Symbol			= I.A_Symbol			
                                                    AND TD.TP_Key			= TP.TP_Key         
													AND isnumeric(TP.TP_DropOffKey) = 1	-- This must be a HotelKey
													AND ((TD.T_TripCd		= 'TA'
													AND TP.TP_PickUpKey		<> L.L_DepStaCd)    -- Layover record was updated with new DepStaCd (so drop this one)!
													Or (TD.T_TripCd			= 'TA'
													AND TP.TP_PickUpKey		<> L.L_DepStaCd))   -- Layover record was updated with new DepStaCd (so drop this one)!
													AND TP.TP_PickUpCd		= 'A'	-- From Sta from Hotel (for Hotel's Sta (normal))
													AND TP.TP_DropOffCd		= 'A'	-- 'H'

	Left Join dbo.tblRefNotes RN with (nolock) ON RN.R_RefNumb  = TD.R_RefNumb
											  AND RN.RN_Type	= 'G'


	Where I.A_Symbol			= isnull(@Airline, I.A_Symbol)
	and L.A_Symbol				= isnull(@Airline, L.A_Symbol)

	and L.L_DepDtTm				between @FromDt and @ToDt

	-- Not already cancelled
	And TD.T_StatusCd			not in ('X', 'D')

	AND L.L_ArrFltNum			not in ('NOGT','GTRN', 'LIMO', 'AVAL', 'POSN', 'DUTY')   -- Added POSN JB 7/1/20, DUTY JB 12/15/21
--	And	I.I_CancelResultCd		= 0
	And I.I_ConfDtTm			is not null
	And I.I_StayCd				= 1
	And I.A_Symbol				= AC.A_Symbol  --@Airline
	And I.I_InvType				= 0
	And	AC.AC_TMS_TurnedON		= 1	
	And	TD.T_TripCd				in ('TA', 'TA')
--	And L.L_DepDtTm				 between TP.TP_StartDtTm and TP.TP_EndDtTm

	And L.L_DepStaCd			= isnull(@StaReProcess, L.L_DepStaCd)

*/
/*
 ON the matching record, the trip needs to match the reservation details exactly
  it can either match on 
  1. the resid and the flight number and the crewid,	--> Use the existing B_UID cancel the old trips and add the new trip
  2. only the flight number								--> Use the existing B_UID cancel the old trips and add the new trip  
  3. only the rezid										--> Drop the old trip and create new trips

*/
	--		Update TD
	
	--Set TD.T_StatusCd			= 'D',
	--TD.T_UpdatedLastDtTm		= @LocalDtTm,
	--T_Notes						= 'RezQueue Drop',
	--T_PendingCd					= 'Y'  /* case when TD.T_ConfDtTm is null and TD.T_PendingCd = 'Y'
	--										then TD.T_PendingCd   --'Y'	-- Keep it Yes
	--										else TD.T_PendingCd   --'N'	-- So the P_QueueMgt_Trips() code will read these!
	--									  end	 */ 
							 
	--From dbo.tblTravelTrips	TD	(nolock)
	
	--Join dbo.tblOrder				O	(nolock)	ON TD.I_UID			= O.I_UID
	

	--Where TD.T_StatusCd			not in ('D', 'X')	-- Cancel (X) or Trying to cancel (D)
	--And O.A_Symbol				= isnull(@A_Symbol, O.A_Symbol)
	--and TD.T_TripCd in (
 --                                      'TH', 'OH'
 --                                  )
	--And 
	--(
	--TD.T_EmpId				<> O.L_EmpId
	--or
	--TD.T_FltNum				<>	@ArrFltNum
	--or
	--cast(TD.T_TRipdttm as date) = @ArrDt
	--)

		
		
		
		select @ExistingRef = TT.R_RefNumb  
		from tblTravelTrips TT 
		 join
                    tblOrder   O
                        on O.I_UID = TT.I_UID
                           and O.A_Symbol = TT.A_Symbol
		where TT.A_Symbol = @A_Symbol
		  and TT.T_TripCd in (
                                       'TA', 'OA'
                                   )
          and TT.T_CancelResultCd = 0
          and TT.T_FltNum = @ArrFltNum
          and cast(TT.T_TRipdttm as date) = @ArrDt
		  and TT.T_EmpId = O.L_EmpId
		  And TT.T_StatusCd			not in ('X', 'D')

		

		Insert into  [dbo].[tblTravelTrips](
			--[T_UID] [int] IDENTITY(10000,1) NOT NULL,
			[TP_Key],				[I_UID],			[CP_UID], 
			[R_RefNumb],			
			[T_TripCd],
			[T_UpdatedLastDtTm],	[T_SentToProvDtTm],	[T_PendingDtTm],
			[T_PendingCd],
			[T_StatusCd],			[P_ProvKey],		[T_SourceCd],
			[T_ClearCustomsInd],
			[S_StationCd],
			[T_TripDtTm],			[T_TripDtTm_Old],	[MTF_UID],
			[A_Symbol],				[T_FltNum],			[T_FltNum_Old],
			[T_ArrLimoFltNum],		[T_EmpId],			
			[T_EmpId_Old],	
			[T_CrewType],
			[T_TimeChgInd],
			[T_FltNumChgInd],		[T_HeadCountChgInd],[T_WaitTmi],
			[T_TZOffset],			[T_CostCenter],		[PA_Key],
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
			[T_CancelDeadlineDtTm],	-- More on this later
			[T_NoShowDtTm],			
			[T_Notes],
			[T_PostedDtTm]
			)

			select
			[TP_Key],				O.[I_UID],			-1, 
			@ExistingRef,			
			[T_TripCd],
			[T_UpdatedLastDtTm],	[T_SentToProvDtTm],	[T_PendingDtTm],
			'Y',
			'P',			[P_ProvKey],		[T_SourceCd],
			[T_ClearCustomsInd],
			[S_StationCd],
			[T_TripDtTm],			[T_TripDtTm_Old],	[MTF_UID],
			O.A_Symbol,				[T_FltNum],			[T_FltNum_Old],
			[T_ArrLimoFltNum],		L.L_EmpId,			
			L.L_EmpId,	
			[T_CrewType],
			[T_TimeChgInd],
			[T_FltNumChgInd],		[T_HeadCountChgInd],[T_WaitTmi],
			[T_TZOffset],			[T_CostCenter],		[PA_Key],
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
			[T_CancelDeadlineDtTm],	-- More on this later
			[T_NoShowDtTm],			
			[T_Notes],
			[T_PostedDtTm]
			from tbltraveltrips T
			join
                    tblOrder   O
                        on O.I_UID = T.I_UID
                           and O.A_Symbol = T.A_Symbol
			join 
					tbllayover L 
						on L.L_UID = O.L_UID
							and L.A_Symbol = O.A_Symbol
			where T.A_Symbol = @A_Symbol
			and   T.R_RefNumb = @ExistingRef
			and	  O.O_EachDay = 1
		
		GoTo ExitProc
        end --FOUND MATCH Validation to find valid trips with matching trips dates and trip times 

    else
   begin --NO MATCH (Create Trip) Validation to find valid trips with matching trips dates and trip times 



            set @R_RefNumber_Exists = -1;

			IF EXISTS
				(
            SELECT
                1
            from
                tblTravelTrips_Queue TT
                join
                    tblOrder   O
                        on O.I_UID = TT.I_UID
                           and O.A_Symbol = TT.A_Symbol
            where
                O.R_RefNumb = @R_RefNumb
                and TT.T_TripCd in (
                                       'TA', 'OA'
                                   )
                and TT.T_CancelResultCd = 0
                and TT.T_FltNum = @DepFltNum
                and cast(TT.T_TRipdttm as date) = @DepDt
				)
			begin

			if @Debug = 1
			begin
			select 'Found Matching Trip in Queue'
			end


			delete from tblTravelTrips_Queue 
			where A_Symbol = @A_Symbol
			and T_TripCd in (
                                       'TA', 'OA'
                                   )
			and T_FltNum = @DepFltNum
            and cast(T_TRipdttm as date) = @DepDt


			end
			else

			begin


			if @Debug = 1
			begin
			select 'No Matching Trip Will create new Trip in Queue'
			End

			end

            IF EXISTS
                (
                    SELECT
                        1
                    from
                        tbltravelpair TP
                        join
                            tblOrder  O
                                on O.L_DepStaCd = TP.TP_PickUpKey
                                   and cast(O.H_HotelKey as char) = TP.TP_DropOffKey
                                   and O.A_Symbol = TP.A_Symbol
                    where
                        O.R_RefNumb = @R_RefNumb
                        and isnull(TP.TP_OrderBy, 0) = 0
                        and O.L_DepDtTm
                        between TP.TP_StartDtTm and TP.TP_EndDtTm
                        and (
                                (
                                    TP.TP_PickUpCd = 'A'
                                    and TP.TP_DropOffCd = 'A'
                                )
                               
                            )
					union all
					SELECT
                        1
                    from
                        tbltravelpair TP
                        join
                            tblOrder  O
                                on O.L_DepStaCd = TP.TP_DropOffKey 
                                   and cast(O.H_HotelKey as char) = TP.TP_PickUpKey
                                   and O.A_Symbol = TP.A_Symbol
                    where
                        O.R_RefNumb = @R_RefNumb
                        and isnull(TP.TP_OrderBy, 0) = 0
                        and O.L_DepDtTm
                        between TP.TP_StartDtTm and TP.TP_EndDtTm
                        and (
                                (
                                    TP.TP_PickUpCd = 'H'
                                    and TP.TP_DropOffCd = 'O'
                                )
                               
                            )
                )
                BEGIN --logic to insert the record into the traveltrips table in the event the ground trip DOES*** not find a matching travel pair
				
                    SELECT top 1
                        @TP_Key_1W       = TP.TP_Key,
                        @P_ProvKey_1W    = TP.P_ProvKey,
                        @P_ProvAssign_1W = TP.PA_Key
                    from
                        tbltravelpair TP
                        join
                            tblOrder  O
                                on O.L_DepStaCd = TP.TP_DropOffKey 
                                   and cast(O.H_HotelKey as char) = TP.TP_PickUpKey
                                   and O.A_Symbol = TP.A_Symbol
                    where
                        O.R_RefNumb = @R_RefNumb
                        and isnull(TP.TP_OrderBy, 0) = 0
                        and O.L_DepDtTm
                        between TP.TP_StartDtTm and TP.TP_EndDtTm
                        and (
                                TP.TP_PickUpCd = 'H'
                                and TP.TP_DropOffCd = 'O'
                            )

                    SELECT top 1
                        @TP_Key_2W       = TP.TP_Key,
                        @P_ProvKey_2W    = TP.P_ProvKey,
                        @P_ProvAssign_2W = TP.PA_Key
                    from
                        tbltravelpair TP
                        join
                            tblOrder  O
                                on O.L_DepStaCd = TP.TP_PickUpKey
                                   and cast(O.H_HotelKey as char) = TP.TP_DropOffKey
                                   and O.A_Symbol = TP.A_Symbol
                    where
                        O.R_RefNumb = @R_RefNumb
                        and isnull(TP.TP_OrderBy, 0) = 0
                        and O.L_DepDtTm
                        between TP.TP_StartDtTm and TP.TP_EndDtTm
                        and (
                                TP.TP_PickUpCd = 'A'
                                and TP.TP_DropOffCd = 'A'
                            )


                    --***************************************************************************************************************
                    -- Insert Single Record Into TravelTrip Table  -- These are between Station and Hotel
                    If @DepStationCd = @LvrStationCd
                        Begin
						set @ProcFlag = 1;
						if @Debug = 1
						begin
						select 1 as flag,@MockREf
						end
                            Insert into [dbo].[tblTravelTrips_queue]
                                (
                                    --[T_UID] [int] IDENTITY(10000,1) NOT NULL,
                                    [TP_Key],
                                    [I_UID],
                                    [CP_UID],
                                    [R_RefNumb],
                                    [T_TripCd],
                                    [T_UpdatedLastDtTm],
                                    [T_SentToProvDtTm],
                                    [T_PendingDtTm],
                                    [T_PendingCd],
                                    [T_StatusCd],
                                    [P_ProvKey],
                                    [T_SourceCd],
                                    [T_ClearCustomsInd],
                                    [S_StationCd],
                                    [T_TripDtTm],
                                    [T_TripDtTm_Old],
                                    [MTF_UID],
                                    [A_Symbol],
                                    [T_FltNum],
                                    [T_FltNum_Old],
                                    [T_ArrLimoFltNum],
                                    [T_EmpId],
                                    [T_EmpId_Old],
                                    [T_CrewType],
                                    [T_TimeChgInd],
                                    [T_FltNumChgInd],
                                    [T_HeadCountChgInd],
                                    [T_WaitTmi],
                                    [T_TZOffset],
                                    [T_CostCenter],
                                    [PA_Key],
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
                                    [T_PostedDtTm],
									[TP_PickUpCd],	
									[TP_DropOffCd],	
									[TP_PickUpKey],	
									[TP_DropOffKey]
                                )
                                        SELECT Distinct
                                            @TP_Key_2W,
                                            O.I_UID,       -- I_UID
											-1,			   --L.DF_AISUID,   -- CP_UID
                                            @MockREf,      -- R_RefNumb]
                                                           -- See below...
                                                           --@TripCd,					-- 'TA'	-- T_TripCd,
                                            'TA'            as TripCd,
                                            @LocalDtTm,
                                            NULL,
                                            NULL,          -- T_PendingDtTm
                                            'N',           -- T_PendingCd
                                            'P',           -- StatusCd	'P' = Pending Adhoc
                                            @P_ProvKey_2W,
                                            'RQ',
                                            'N'             as T_ClearCustomsInd,
                                            @DepStationCd, -- L.L_DepStaCd,
                                            @DepDtTm,
                                            @DepDtTm,      -- Old
                                            0,             -- MTF_UID
                                            @A_Symbol,
                                            @DepFltNum,
                                            @DepFltNum,    -- Old
                                            NULL,
                                            L.L_EmpId,
                                            L.L_EmpId,        -- Old EmpId
                                            @CrewPos,
                                            NULL,          --		[T_TimeChgInd],
                                            NULL,          --		[T_FltNumChgInd],		
                                            NULL,          --		[T_HeadCountChgInd],	
                                            NULL,          --		[T_WaitTmi],
                                            @TimeZone * 60,
                                            @CostCenter,
                                            @P_ProvAssign_2W,
                                            0,             -- 		[T_RateHeadOverRide],	
                                            @EnterByWho,
                                            NULL,          --		[T_ConfNumb],		
                                            NULL,          --		[T_ConfName],			
                                            NULL,          --		[T_ConfDtTm],		
                                            NULL,          --		[T_ConfByCSR],		
                                            NULL,          --		[T_CancelNumb],			
                                            NULL,          -- 		[T_CancelName],		
                                            NULL,          --		[T_CancelDtTm],		
                                            NULL,          -- 		[T_CancelByCSR],		
                                            0,             -- 		[T_CancelResultCd],	
                                            NULL,          -- 		[T_CancelDeadlineDtTm],	-- More on this later
                                            NULL,          -- 		[T_NoShowDtTm],			
                                            NULL,          -- 		[T_Notes],
                  @LocalDtTm,     -- 		[T_PostedDtTm]
											'A'                        as TP_PickUpCd,
                                            'A'                        as TP_DropOffCd,
                                            cast(L.L_DepStaCd as char) as TP_PickUpKey,
                                            cast(O.H_HotelKey as char) as TP_DropOffKey
                                        From
                                            dbo.tblOrder       O (NOLOCK)
                                            Join
                                                dbo.tblLayover L (NOLOCK)
                                                    on L.L_UID = O.L_UID
                                                       and L.A_Symbol = O.A_Symbol
                                        Where
                                            O.R_RefNumb = @R_RefNumb
                                            and O.A_Symbol = @A_Symbol
                                            And O.O_EachDay = 1


                            Set @RCntSS = @@ROWCOUNT
                            Set @Err = @@ERROR
                            If @Err > 0
                                Begin
                                    Select
                                        @Msg
                                        = 'Error: Insert into TravelTrips failed on Manual (TA/OA)' + ' for Sta: '
                                          + @DepStationCd + ' Airline: ' + @A_Symbol + ' DepDtTm: '
                                          + convert(char(16), @DepDtTm, 21) + ' Error: ' + convert(char(6), @Err)
                                    Exec U_Debug
                                        @A_Symbol,
                                        @Msg,
                                        0,
                                        @ProcName,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL
                                    GoTo ExitProc
                                End
                            If @RCntSS > 0
                                Begin
                                    Select
                                        @Msg
                                        = 'Debug: Inserted new Manual into TravelTrip (TA/OA), RCnt: '
                                          + convert(char(3), @RCntSS)
                                    exec U_Debug
                                        @A_Symbol,
                                        @Msg,
                                        5,
                                        @ProcName,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL
                                End
                            Else
                                Begin
                                    INSERT INTO dbo.tblMesg
                                        (
                                            --        M_UID , 
                                            L_UID,
                                            I_UID,
                                            DF_UID,
                                            A_Symbol,
                                            H_HotelKey,
                                            M_Text,
                                            M_Level,
                                            M_ResolvedInd,
                                            M_ResolveComment,
                                            M_ResolvedByWho,
                                            M_ResolvedDtTm,
                                            M_ErrorCode,
                                       M_ProcName,
                                            M_PostedDtTm
                                        )
                                                SELECT --    @M_UID , 	-- Identity column
                                                    NULL, -- @L_UID , 
                                                    NULL, -- @I_UID , 
                                                    NULL, -- @DF_UID,
                                                    @A_Symbol,
                                                    NULL, -- @H_HotelKey , 
                                                    'Action: Need to create missing TravelPair for: DepSta:('
                                                    + rtrim(@DepStationCd) + ') LIMO to Hotel:(' + rtrim(@HotelKey)
                                                    + ') Pairing: ' + ' ManualEntry ' + ' DepDtTm: '
                                                    + convert(
                                                                 char(20),
                                                                 DateAdd(
                                                                            mi,
                                                                            isnull(
                                                                                      dbCommon.dbo.uFN_GetLocalTime(
                                                                                                                       @DepStationCd,
                                                                                                                       @DepDtTm
                                                                                                                   ), 0
                                                                                  ), @DepDtTm
                                                                        )
                                                             ) + ' Sta-HotelArrSide  Airport to Hotel ('
                                                    + rtrim(@TripCd) + ')',
                                                    1,    -- @M_Level , 
                                                    0,    -- @M_ResolvedInd , 
                                                    NULL, -- @M_ResolveComment , 
                                                    NULL, -- @M_ResolvedByWho , 
                                                    NULL, -- @M_ResolvedDtTm , 
                                                    NULL, -- @M_ErrorCode , 
                                                    'P_MakeGrndEntry_Dep',
                                                    @LocalDtTm
                                                Where
                                                    @TripCd in (
                                                                   'TA', 'OA'
                                                               )
                                    If @@ROWCOUNT > 0
                                        GOTO ExitProc
                                End
                        End -- If TripCd = 'TA'

                    else
                        Begin
						set @ProcFlag = 2;
						if @Debug = 1
						begin
						select 2 as flag,@MockREf
						end
                            Insert into [dbo].[tblTravelTrips_queue]
                                (
                                    --[T_UID] [int] IDENTITY(10000,1) NOT NULL,
                                    [TP_Key],
                                    [I_UID],
                                    [CP_UID],
                                    [R_RefNumb],
                                    [T_TripCd],
                                    [T_UpdatedLastDtTm],
                                    [T_SentToProvDtTm],
                                    [T_PendingDtTm],
                                    [T_PendingCd],
                                    [T_StatusCd],
                                    [P_ProvKey],
                                    [T_SourceCd],
                                    [T_ClearCustomsInd],
                                    [S_StationCd],
                                    [T_TripDtTm],
                                    [T_TripDtTm_Old],
                                    [MTF_UID],
                                    [A_Symbol],
                                    [T_FltNum],
                                    [T_FltNum_Old],
                                    [T_ArrLimoFltNum],
                                    [T_EmpId],
                                    [T_EmpId_Old],
                                    [T_CrewType],
                                    [T_TimeChgInd],
                                    [T_FltNumChgInd],
                                    [T_HeadCountChgInd],
                                    [T_WaitTmi],
                                    [T_TZOffset],
                                    [T_CostCenter],
                                    [PA_Key],
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
                                    [T_PostedDtTm],
									[TP_PickUpCd],	
									[TP_DropOffCd],	
									[TP_PickUpKey],	
									[TP_DropOffKey]
                                )
                                        SELECT Distinct
                                            @TP_Key_1W,
                                            O.I_UID,       -- I_UID
											-1,			   --L.DF_AISUID,   -- CP_UID
                                            @MockREf,      -- R_RefNumb]
                                                           -- See below...
                                                           --@TripCd,					-- 'TA'	-- T_TripCd,
                                            'OA'            as TripCd,
                                            @LocalDtTm,
                                            NULL,
                                            NULL,          -- T_PendingDtTm
                                            'N',           -- T_PendingCd
                                            'P',           -- StatusCd	'P' = Pending Adhoc
                                            @P_ProvKey_1W,
                                            'RQ',
                                            'N'             as T_ClearCustomsInd,
                                            @DepStationCd, -- L.L_DepStaCd,
                                            @DepDtTm,
                                            @DepDtTm,      -- Old
                                            0,             -- MTF_UID
                                            @A_Symbol,
                                            @DepFltNum,
                                            @DepFltNum,    -- Old
                                            NULL,
                                            L.L_EmpId,
                                            L.L_EmpId,        -- Old EmpId
                                            @CrewPos,
                                            NULL,       --		[T_TimeChgInd],
                                            NULL,          --		[T_FltNumChgInd],		
                                            NULL,          --		[T_HeadCountChgInd],	
                                            NULL,          --		[T_WaitTmi],
                                            @TimeZone * 60,
                                            @CostCenter,
                                            @P_ProvAssign_1W,
                                            0,             -- 		[T_RateHeadOverRide],	
                                            @EnterByWho,
                                            NULL,          --		[T_ConfNumb],		
                                            NULL,          --		[T_ConfName],			
                                            NULL,          --		[T_ConfDtTm],		
                                            NULL,          --		[T_ConfByCSR],		
                                            NULL,          --		[T_CancelNumb],			
                                            NULL,          -- 		[T_CancelName],		
                                            NULL,          --		[T_CancelDtTm],		
                                            NULL,          -- 		[T_CancelByCSR],		
                                            0,             -- 		[T_CancelResultCd],	
                                            NULL,          -- 		[T_CancelDeadlineDtTm],	-- More on this later
                                            NULL,          -- 		[T_NoShowDtTm],			
                                            NULL,          -- 		[T_Notes],
                                            @LocalDtTm,     -- 		[T_PostedDtTm]
											'H'                        as TP_PickUpCd,
                                            'O'                        as TP_DropOffCd,
                                            cast(O.H_HotelKey as char) as TP_PickUpKey,
                                            cast(L.L_DepStaCd as char )as TP_DropOffKey
                                        From
                                            dbo.tblOrder       O (NOLOCK)
                                            Join
                                                dbo.tblLayover L (NOLOCK)
                                                    on L.L_UID = O.L_UID
                                                       and L.A_Symbol = O.A_Symbol
                                        Where
                                            O.R_RefNumb = @R_RefNumb
                                            and O.A_Symbol = @A_Symbol
                                            And O.O_EachDay = 1

                            Set @RCntSS = @@ROWCOUNT
                            Set @Err = @@ERROR
                            If @Err > 0
                                Begin
                                    Select
                                        @Msg
                                        = 'Error: Insert into TravelTrips failed on Manual (TA/OA)' + ' for Sta: '
                                          + @DepStationCd + ' Airline: ' + @A_Symbol + ' DepDtTm: '
                                          + convert(char(16), @DepDtTm, 21) + ' Error: ' + convert(char(6), @Err)
                                    Exec U_Debug
                                        @A_Symbol,
                                        @Msg,
                                        0,
                                        @ProcName,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL
                                    GoTo ExitProc
                                End
                            If @RCntSS > 0
                                Begin
                                    Select
              @Msg
                                        = 'Debug: Inserted new Manual into TravelTrip (TA/OA), RCnt: '
                                          + convert(char(3), @RCntSS)
                                    exec U_Debug
                                        @A_Symbol,
                                        @Msg,
                                        5,
                                        @ProcName,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL
                                End
                            Else
                                Begin
                                    INSERT INTO dbo.tblMesg
                                        (
                                            --        M_UID , 
                                            L_UID,
                                            I_UID,
                                            DF_UID,
                                            A_Symbol,
                                            H_HotelKey,
                                            M_Text,
                                            M_Level,
                                            M_ResolvedInd,
                                            M_ResolveComment,
                                            M_ResolvedByWho,
                                            M_ResolvedDtTm,
                                            M_ErrorCode,
                                            M_ProcName,
                                            M_PostedDtTm
                                        )
                                                SELECT --    @M_UID , 	-- Identity column
                                                    NULL, -- @L_UID , 
                                                    NULL, -- @I_UID , 
                                                    NULL, -- @DF_UID,
                                                    @A_Symbol,
                                                    NULL, -- @H_HotelKey , 
                                                    'Action: Need to create missing TravelPair for: DepSta:('
                                                    + rtrim(@DepStationCd) + ') LIMO to Hotel:(' + rtrim(@HotelKey)
                                                    + ') Pairing: ' + ' ManualEntry ' + ' DepDtTm: '
                                                    + convert(
                                                                 char(20),
                                                                 DateAdd(
                                                                            mi,
                                                                            isnull(
                                                                                      dbCommon.dbo.uFN_GetLocalTime(
                                                                                                                       @DepStationCd,
                                                                                                                       @DepDtTm
                                                                                                                   ), 0
                                                                                  ), @DepDtTm
                                                                        )
                                                             ) + ' Sta-HotelArrSide  Airport to Hotel ('
                                                    + rtrim(@TripCd) + ')',
                                                    1,    -- @M_Level , 
                                                    0,    -- @M_ResolvedInd , 
          NULL, -- @M_ResolveComment , 
                                                    NULL, -- @M_ResolvedByWho , 
                                                    NULL, -- @M_ResolvedDtTm , 
                                                    NULL, -- @M_ErrorCode , 
                                                    'P_MakeGrndEntry_Dep',
                                                    @LocalDtTm
                                                Where
                                                    @TripCd in (
                                                                   'TA', 'OA'
                                                               )
                                    If @@ROWCOUNT > 0
                                        GOTO ExitProc


                                End

                        End -- If TripCd = 'TA'

                END --logic to insert the record into the traveltrips table in the event the ground trip DOES*** not find a matching travel pair



            ELSE
                begin
                    BEGIN --logic to insert the record into the traveltrips table in the event the ground trip DOES*** not find a matching travel pair



                        --***************************************************************************************************************
                        -- Insert Single Record Into TravelTrip Table  -- These are between Station and Hotel
                        If @DepStationCd = @LvrStationCd
                            Begin
							set @ProcFlag = 3;
							if @Debug = 1
							begin
							select 3 as flag,@MockREf
							end
                                Insert into [dbo].[tblTravelTrips_queue]
                                    (
                                        --[T_UID] [int] IDENTITY(10000,1) NOT NULL,
                                        [TP_Key],
                                        [I_UID],
                                        [CP_UID],
                                        [R_RefNumb],
                                        [T_TripCd],
                                        [T_UpdatedLastDtTm],
                                        [T_SentToProvDtTm],
                                        [T_PendingDtTm],
                                        [T_PendingCd],
                                        [T_StatusCd],
                                        [P_ProvKey],
                                        [T_SourceCd],
                                        [T_ClearCustomsInd],
                                        [S_StationCd],
                                        [T_TripDtTm],
                                        [T_TripDtTm_Old],
                                        [MTF_UID],
                                        [A_Symbol],
                                        [T_FltNum],
                                        [T_FltNum_Old],
                                        [T_ArrLimoFltNum],
                                        [T_EmpId],
                                        [T_EmpId_Old],
                                        [T_CrewType],
                                        [T_TimeChgInd],
                                        [T_FltNumChgInd],
                                        [T_HeadCountChgInd],
                                        [T_WaitTmi],
                                        [T_TZOffset],
                                        [T_CostCenter],
                                        [PA_Key],
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
                                        [T_PostedDtTm],
                                        [TP_PickUpCd],
                                        [TP_DropOffCd],
                                        [TP_PickUpKey],
                                        [TP_DropOffKey]
                                    )
                                            SELECT Distinct
                                                NULL,
                                                O.I_UID,       -- I_UID
												-1,			   --L.DF_AISUID,   -- CP_UID
                                                @MockREf,      -- R_RefNumb]
                                                               -- See below...
                                                               --@TripCd,					-- 'TA'	-- T_TripCd,
                                                'TA'                       as TripCd,
                                                @LocalDtTm,
                                                NULL,
                                                NULL,          -- T_PendingDtTm
                                                'N',           -- T_PendingCd
                                                'P',           -- StatusCd	'P' = Pending Adhoc
                                                NULL,
                                                'RQ',
                                                'N'                        as T_ClearCustomsInd,
                                                @DepStationCd, -- L.L_DepStaCd,
                                                @DepDtTm,
                                                @DepDtTm,      -- Old
                                                0,             -- MTF_UID
                                                @A_Symbol,
                                                @DepFltNum,
                                                @DepFltNum,    -- Old
                                                NULL,
                                                L.L_EmpId,
                                                L.L_EmpId,        -- Old EmpId
                                                @CrewPos,
                                                NULL,          --		[T_TimeChgInd],
                                                NULL,          --		[T_FltNumChgInd],		
                                                NULL,          --		[T_HeadCountChgInd],	
                                                NULL,          --		[T_WaitTmi],
                                                @TimeZone * 60,
                                                @CostCenter,
                                                NULL,
                                                0,             -- 		[T_RateHeadOverRide],	
                                                @EnterByWho,
                                                NULL,          --		[T_ConfNumb],		
                                                NULL,          --		[T_ConfName],			
                                                NULL,          --		[T_ConfDtTm],		
                                                NULL,          --		[T_ConfByCSR],		
                                                NULL,          --		[T_CancelNumb],			
                                                NULL,          -- 		[T_CancelName],		
                                                NULL,          --		[T_CancelDtTm],		
                                                NULL,      -- 		[T_CancelByCSR],		
                                                0,             -- 		[T_CancelResultCd],	
                                                NULL,          -- 		[T_CancelDeadlineDtTm],	-- More on this later
                                                NULL,          -- 		[T_NoShowDtTm],			
                                                NULL,          -- 		[T_Notes],
                                                @LocalDtTm,    -- 		[T_PostedDtTm]
                                                'A'                        as TP_PickUpCd,
                                                'A'                        as TP_DropOffCd,
                                                cast(L.L_DepStaCd as char) as TP_PickUpKey,
                                                cast(O.H_HotelKey as char) as TP_DropOffKey
                                            From
                                                dbo.tblOrder       O (NOLOCK)
                                                Join
                                                    dbo.tblLayover L (NOLOCK)
                                                        on L.L_UID = O.L_UID
                                                           and L.A_Symbol = O.A_Symbol
                                            Where
                                                O.R_RefNumb = @R_RefNumb
                                                and O.A_Symbol = @A_Symbol
                                                And O.O_EachDay = 1


                                Set @RCntSS = @@ROWCOUNT
                                Set @Err = @@ERROR
                                If @Err > 0
                                    Begin
                                        Select
                                            @Msg
                                            = 'Error: Insert into TravelTrips failed on Manual (TA/OA)' + ' for Sta: '
                                              + @DepStationCd + ' Airline: ' + @A_Symbol + ' DepDtTm: '
                                              + convert(char(16), @DepDtTm, 21) + ' Error: ' + convert(char(6), @Err)
                                        Exec U_Debug
                                            @A_Symbol,
                                            @Msg,
                                            0,
                                            @ProcName,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL
                                        GoTo ExitProc
                                    End
                                If @RCntSS > 0
                                    Begin
                                        Select
                                            @Msg
                                            = 'Debug: Inserted new Manual into TravelTrip (TA/OA), RCnt: '
                                              + convert(char(3), @RCntSS)
                                        exec U_Debug
                                            @A_Symbol,
                                            @Msg,
                                            5,
                                            @ProcName,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL
                                    End
                                Else
                                    Begin
                                        INSERT INTO dbo.tblMesg
                                            (
                                                --        M_UID , 
                                                L_UID,
                                                I_UID,
                                                DF_UID,
                                                A_Symbol,
                                                H_HotelKey,
                                                M_Text,
                                                M_Level,
                                                M_ResolvedInd,
                                                M_ResolveComment,
                                                M_ResolvedByWho,
                                                M_ResolvedDtTm,
                                                M_ErrorCode,
                                                M_ProcName,
                                                M_PostedDtTm
                                            )
                                                    SELECT --    @M_UID , 	-- Identity column
                                                        NULL, -- @L_UID , 
                                                        NULL, -- @I_UID , 
                                                        NULL, -- @DF_UID,
                                                        @A_Symbol,
                                                        NULL, -- @H_HotelKey , 
                                                        'Action: Need to create missing TravelPair for: DepSta:('
                                                        + rtrim(@DepStationCd) + ') LIMO to Hotel:(' + rtrim(@HotelKey)
                                                        + ') Pairing: ' + ' ManualEntry ' + ' DepDtTm: '
                                                        + convert(
                                                                     char(20),
                                                                     DateAdd(
                                                                                mi,
                                                                                isnull(
                                                                                          dbCommon.dbo.uFN_GetLocalTime(
                                                                                                                           @DepStationCd,
                                                                                                                           @DepDtTm
                                                                                                                       ),
                                                                                          0
                                                                                      ), @DepDtTm
                                                                            )
                                                                 ) + ' Sta-HotelArrSide  Airport to Hotel ('
                                                        + rtrim(@TripCd) + ')',
                                                        1,    -- @M_Level , 
                                                        0,    -- @M_ResolvedInd , 
                                                        NULL, -- @M_ResolveComment , 
                                                        NULL, -- @M_ResolvedByWho , 
                                                        NULL, -- @M_ResolvedDtTm , 
                                                        NULL, -- @M_ErrorCode , 
                                                        'P_MakeGrndEntry_Dep',
                                                        @LocalDtTm
                                                    Where
                                                        @TripCd in (
                                                                       'TA', 'OA'
                            )
                                        If @@ROWCOUNT > 0
										GoTo ExitProc	                                       
                                    End
                            End -- If TripCd = 'TA'

                        else
                            Begin
							set @ProcFlag = 4;
							if @Debug = 1
							begin
							select 4 as flag,@MockREf
							end
                                Insert into [dbo].[tblTravelTrips_queue]
                                    (
                                        --[T_UID] [int] IDENTITY(10000,1) NOT NULL,
                                        [TP_Key],
                                        [I_UID],
                                        [CP_UID],
                                        [R_RefNumb],
                                        [T_TripCd],
                                        [T_UpdatedLastDtTm],
                                        [T_SentToProvDtTm],
                                        [T_PendingDtTm],
                                        [T_PendingCd],
                                        [T_StatusCd],
                                        [P_ProvKey],
                                        [T_SourceCd],
                                        [T_ClearCustomsInd],
                                        [S_StationCd],
                                        [T_TripDtTm],
                                        [T_TripDtTm_Old],
                                        [MTF_UID],
                                        [A_Symbol],
                                        [T_FltNum],
                                        [T_FltNum_Old],
                                        [T_ArrLimoFltNum],
                                        [T_EmpId],
                                        [T_EmpId_Old],
                                        [T_CrewType],
                                        [T_TimeChgInd],
                                        [T_FltNumChgInd],
                                        [T_HeadCountChgInd],
                                        [T_WaitTmi],
                                        [T_TZOffset],
                                        [T_CostCenter],
                                        [PA_Key],
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
                                        [T_PostedDtTm],
                                        [TP_PickUpCd],
                                        [TP_DropOffCd],
                                        [TP_PickUpKey],
                                        [TP_DropOffKey]
                                    )
                                            SELECT Distinct
                                                NULL,
                                                O.I_UID,       -- I_UID
												-1,			   --L.DF_AISUID,   -- CP_UID
                                                @MockREf,      -- R_RefNumb]
                                                               -- See below...
                                                               --@TripCd,					-- 'TA'	-- T_TripCd,
                                            'OA'                       as TripCd,
                                                @LocalDtTm,
                                                NULL,
                                                NULL,          -- T_PendingDtTm
                                                'N',           -- T_PendingCd
                                                'P',           -- StatusCd	'P' = Pending Adhoc
                                                NULL,
                                                'RQ',
                                                'N'                        as T_ClearCustomsInd,
                                                @DepStationCd, -- L.L_DepStaCd,
                                                @DepDtTm,
                                                @DepDtTm,      -- Old
                                                0,             -- MTF_UID
                                                @A_Symbol,
                                                @DepFltNum,
                                                @DepFltNum,    -- Old
                                                NULL,
                                                L.L_EmpId,
                                                L.L_EmpId,        -- Old EmpId
                                                @CrewPos,
                                                NULL,          --		[T_TimeChgInd],
                                                NULL,          --		[T_FltNumChgInd],		
                                                NULL,          --		[T_HeadCountChgInd],	
                                                NULL,          --		[T_WaitTmi],
                                                @TimeZone * 60,
                                                @CostCenter,
                                                NULL,
                                                0,             -- 		[T_RateHeadOverRide],	
                                                @EnterByWho,
                                                NULL,          --		[T_ConfNumb],		
                                                NULL,          --		[T_ConfName],			
                                                NULL,          --		[T_ConfDtTm],		
                                                NULL,          --		[T_ConfByCSR],		
                                                NULL,          --		[T_CancelNumb],			
                                                NULL,          -- 		[T_CancelName],		
                                                NULL,          --		[T_CancelDtTm],		
                                                NULL,          -- 		[T_CancelByCSR],		
                                                0,             -- 		[T_CancelResultCd],	
                                                NULL,          -- 		[T_CancelDeadlineDtTm],	-- More on this later
                                                NULL,          -- 		[T_NoShowDtTm],			
                                                NULL,          -- 		[T_Notes],
                                                @LocalDtTm,    -- 		[T_PostedDtTm]
                                                'H'                        as TP_PickUpCd,
                                                'O'                        as TP_DropOffCd,
                                                cast(O.H_HotelKey as char) as TP_PickUpKey,
                                                cast(L.L_DepStaCd as char )as TP_DropOffKey
                                            From
                                                dbo.tblOrder       O (NOLOCK)
                                                Join
                                                    dbo.tblLayover L (NOLOCK)
                                                        on L.L_UID = O.L_UID
                                                           and L.A_Symbol = O.A_Symbol
                                            Where
                                                O.R_RefNumb = @R_RefNumb
                                                and O.A_Symbol = @A_Symbol
                                                And O.O_EachDay = 1

                                Set @RCntSS = @@ROWCOUNT
                                Set @Err = @@ERROR
                                If @Err > 0
                                    Begin
                                        Select
                                            @Msg
                                            = 'Error: Insert into TravelTrips failed on Manual (TA/OA)' + ' for Sta: '
                                              + @DepStationCd + ' Airline: ' + @A_Symbol + ' DepDtTm: '
                                              + convert(char(16), @DepDtTm, 21) + ' Error: ' + convert(char(6), @Err)
                                        Exec U_Debug
                                            @A_Symbol,
                                            @Msg,
                                            0,
                                            @ProcName,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL
                                        GoTo ExitProc
                                    End
                                If @RCntSS > 0
                                    Begin
                                        Select
                                            @Msg
                                            = 'Debug: Inserted new Manual into TravelTrip (TA/OA), RCnt: '
                                              + convert(char(3), @RCntSS)
                                        exec U_Debug
                                            @A_Symbol,
                                            @Msg,
                                            5,
                                            @ProcName,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL
                                    End
                                Else
                                    Begin
                                        INSERT INTO dbo.tblMesg
                                            (
                                                --        M_UID , 
                                                L_UID,
                                                I_UID,
                                                DF_UID,
                                                A_Symbol,
                                                H_HotelKey,
                                                M_Text,
                                                M_Level,
                                                M_ResolvedInd,
                                                M_ResolveComment,
                                                M_ResolvedByWho,
                                                M_ResolvedDtTm,
                                                M_ErrorCode,
                                                M_ProcName,
                                                M_PostedDtTm
                                            )
                                                    SELECT --    @M_UID , 	-- Identity column
                                                        NULL, -- @L_UID , 
                                                        NULL, -- @I_UID , 
                                                        NULL, -- @DF_UID,
            @A_Symbol,
                                                        NULL, -- @H_HotelKey , 
                                                        'Action: Need to create missing TravelPair for: DepSta:('
                                                        + rtrim(@DepStationCd) + ') LIMO to Hotel:(' + rtrim(@HotelKey)
                                                        + ') Pairing: ' + ' ManualEntry ' + ' DepDtTm: '
                                                        + convert(
                                                                     char(20),
                                                                     DateAdd(
                                                                                mi,
                                                                                isnull(
                                                                                          dbCommon.dbo.uFN_GetLocalTime(
                                                                                                                           @DepStationCd,
                                                                                                                           @DepDtTm
                                                                                                                       ),
                                                                                          0
                                                                                      ), @DepDtTm
                                                                            )
                                                                 ) + ' Sta-HotelArrSide  Airport to Hotel ('
                                                        + rtrim(@TripCd) + ')',
                                                        1,    -- @M_Level , 
                                                        0,    -- @M_ResolvedInd , 
                                                        NULL, -- @M_ResolveComment , 
                                                        NULL, -- @M_ResolvedByWho , 
                                                        NULL, -- @M_ResolvedDtTm , 
                                                        NULL, -- @M_ErrorCode , 
                                                        'P_MakeGrndEntry_Dep',
                                                        @LocalDtTm
                                                    Where
                                                        @TripCd in (
                                                                       'TA', 'OA'
                                                                   )
                                        If @@ROWCOUNT > 0
                                            GoTo ExitProc



                                    End

                            End -- If TripCd = 'TA'

                    END --logic to insert the record into the traveltrips table in the event the ground trip DOES*** not find a matching travel pair
                end


        END --NO MATCH (Create Trip) Validation to find valid trips with matching trips dates and trip times 
    --SELECT
    --    @T_UID = IDENT_CURRENT('dbo.tblTravelTrips')

    --*********************************************************************************************************
    -- Return Identity Value
    ExitProc:

    declare @A int;

	if @ProcFlag in (1,2)
	begin
	if @Debug = 1
	begin
	select 'Created Trip with Travel Pair'
	end
    exec @Iret = P_QueueMgt_TripsResQueue
        @A_symbol,
        @MockREf,
        @DepDtTm,
        @A

    --

    set @R_RefNumber_Grnd_Dep = @Iret
	end
	else if @ProcFlag in (3,4)
	begin
	if @Debug = 1
	begin
	select 'Created Trip without Travel Pair'
	end
	set @R_RefNumber_Grnd_Dep = @MockREf
	end
	else 
	begin
	if @Debug = 1
	begin
	select 'Pulled Existing Trip'
	end
	set @R_RefNumber_Grnd_Dep = @ExistingRef
	end


--	return @R_RefNumber_Grnd_Arr;
--Select
--    @T_UID as T_UID
--RETURN 0


Completion time: 2025-06-06T00:45:05.7105696-04:00
