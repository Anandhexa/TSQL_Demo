Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE                        Proc [dbo].[wspCrewSchedule] ( 		
						@Airline A_Symbol,
						@FltDtTm datetime,
						@EmpId char(12),
						@GMTFlg int = 1,	-- Default to local (show output in local)
						@NumbDays int = 15
				)
as

/**


declare @D int, @Days int, @Hours int, @Mins int
set @D = 3001

select @Days = @D / 1440
select @Hours = case when (@D - (@Days * 1440)) >= 60 then (@D - (@Days * 1440)) / 60 else 0 end  
select @Mins = (@D - (@Days * 1440)) % 60
Select @Days, @Hours, @Mins, (@D - (@Days * 1440))

select @Hours = case when @Mins >= 60 then @Mins else 0 end % 60
select @Mins = ((case when @Hours >= 24 then @Hours - (@Hours * 24) else @Hours end) % 60)

select case when @Days >= 1 then @D - (@Days * 1440) else @D end % 60
select case when @Hours >= 24 then @Hours - (@Hours * 24) else @Hours end
select * from tblLayover where L_Source = 'me' and a_symbol = '5x' and l_posteddttm > '1/20/10'

Select @Days, @Hours, @Mins
Select convert(char(3), @Days) + ' ' + case when @Hours < 10 then '0' + convert(char(1), @Hours) else convert(char(2), @Hours) end + ':' + case when @Mins < 10 then '0' + convert(char(1), @mins) else convert(char(2), @mins) end 

EXECUTE [wSP_CrewSched_DN_RDTest] 'rd', '2/26/2011', '1930',  0,  45
EXECUTE [wSP_CrewSched_DN] 'WQ', '2/26/2011', '1930',  0,  45
select * from dbNA.dbo.tblCityPair where CP_CrewId = '1855' and cp_station = 'dfw'
EXECUTE F_11_CrewSched 'TZ', '12/1/2007', '98909',  0,  15
EXECUTE wSP_CrewSched_DN '5X', '12/1/2009', '556719', 1, 15
select * from dbRD.dbo.tblCityPair where CP_CREWID = '2951'


EXECUTE F_11_CrewSched '5X',  '6/30/08', '554998', 1, 60
EXECUTE F_11_CrewSched_test '5X', '4/15/2006 6:27:00 AM', '554517', 1, 15
exec F_11_CrewSched '5X', '8/4/02', '1030', 0
exec [wspCrewSchedule] 'F9', '2022-11-30', '425516', 0, 30
exec [wspCrewSchedule] 'PT',  '9/1/2024', '216070', 1, 60
select * From dbUPS.dbo.tblCityPair(1234, '5/20/08', '5/31/08') CP
**/

/* ************************************************************************** */
/* F_11_CrewSched()                                                           */
/*                                                                            */
/* Created on: 11/20/02                                                       */
/* Author: JB                                                                 */
/* Last modified: 07/01/2019 JLB                                                                          */
/*                                                                            */
/* Notes:  This brings back Flight Info for a crewmember                      */
/*                                                                            */
/*                                                                            */
/* ************************************************************************** */



Declare @ProcName varchar(128),
        @Msg 		varchar(200),
        @iRet 		int,
		@StartDt 	datetime,
		@EndDt		datetime,
		@iEmpId		int,
		@Hrs		int

	set nocount on

	exec U_ProcName @ProcName output, @@PROCID

	Set @Hrs = 8

	--
	-- change to the correct db below...  (Will need some dynamic code when new airlines are added !!!)
	--	


	Select @StartDt = @FltDtTm, @EndDt = DateAdd(dd, @NumbDays, @FltDtTm)

--
-- Spirit
--
If @Airline = 'NK'
	Begin
        Select        Distinct
            CP.CP_UID,
            case when CP.CP_SourceCd = 'ME'
                    then 'ME' 
                    ELSE CP.CP_TripCd
            End as TripCd,
            DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) AS 'ArrTime',
            CASE   WHEN CP.CP_ArrFlightNum NOT IN ('NOGT','HTL', 'CAR', 'LIMO', 'FAKE', 'HOM', 'LIM') --Added 'NOGT' by yashree vyas 6/10/2019 - Added LIM Steve 8/6/2019
                            AND ((CP.CP_ArrAirline NOT IN ('NK') OR ascii(substring(CP.CP_ArrAirline, 3, 1)) = 0)
        OR     ((Len(CP.CP_ArrAirline) = 2 AND ascii(substring(CP.CP_ArrAirline, 3, 1)) <> 0) and CP.CP_ArrAirline not in ('NK')))
                            AND CP_ArrAirline not in ('RSV', 'POS', 'TNG')
                            THEN RTrim(isnull(convert(char(2), CP.CP_ArrAirline), ''))
                            ELSE ''
            end + ltrim(isnull(CP.CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
            isnull(CP.CP_ArrFromStation, 'N/A')      as 'From',
            isnull(CP.CP_Station, 'N/A') as 'Sta',
            isnull(CP.CP_DepToStation, 'N/A') as 'To',
            DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm)    AS 'DepTime',
            case when CP.CP_DepFlightNum not in ('NOGT','HTL', 'CAR', 'LIMO', 'FAKE', 'HOM', 'LIM') --Added 'NOGT' by yashree vyas 6/10/2019 - Added LIM Steve 8/6/2019
                            and ((CP.CP_DepAirline not in ('NK', 'RSV') 
                            or ascii(substring(CP.CP_DepAirline, 3, 1)) = 0) 
                            or ((Len(CP.CP_DepAirline) = 2 
                            and ascii(substring(CP.CP_DepAirline, 3, 1)) <> 0) 
                            and CP.CP_DepAirline <> 'NK'))
                            AND CP_DepAirline not in ('RSV', 'POS', 'TNG')
                    then rtrim(isnull(convert(char(2), CP.CP_DepAirline), ''))
                    else ''
            end + ltrim(isnull(CP.CP_DepFlightNum, 'N/A'))  as 'DepFlt',
            IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
            case	when isnull(CP.CP_LayoverInd, 1) = 1 -- Changed 2/14/2018 Steve - No Longer Using Nearest Airport Domicile Rule ** See Above **
                    then 'Yes'
					when exists (select TOP 1 1 from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																		and T_EmpId				= @EmpId
																		and A_Symbol			= @Airline																					
																		and CP.CP_LayoverInd	<> 1
																		and T_TripCd			= 'SS'
																		and T_CancelResultCd	= 0
																		and T_ConfDtTm			is not null
																		and TT.CP_UID			= CP.CP_UID
/*
																		-- Some wiggle room for updates?
																		and ((CP.CP_ArrFlightNum = 'LIMO'
																		AND   CP.CP_ArrFltSeq	= 10
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm)))
																		or  (CP.CP_DepFlightNum	= 'LIMO'
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm)))
																	)
*/
																	)
						--
						-- Find Airport to Airport ground trips.
						--
					then 'Grd'
					---------------------------------------------------------------------
					----Travel Trips details added for  other Trip code - LOD-33783-----START
					---------------------------------------------------------------------
					WHEN EXISTS (SELECT TOP 1 1  FROM dbo.tblTravelTrips TT 
																WHERE  T_EmpId				= @EmpId
																and A_Symbol			= @Airline																					
																and CP.CP_LayoverInd	<> 1																
																and T_CancelResultCd	= 0
																and T_ConfDtTm			is not null
																AND CP.CP_UID =-1 AND TT.I_UID=I.I_UID)
					THEN 'Grd'

					---------------------------------------------------------------------
					----Travel Trips details added for  other Trip code - LOD-33783-----END
					---------------------------------------------------------------------

                    else ''       
            end as 'Layover',
            CP.CP_ArrTailNumber  as 'ArrTail',
          CP.CP_DepTailNumber  as 'DepTail',
            CP.CP_ArrEquipmentCd as 'ArrEquip',
            CP.CP_DepEquipmentCd as 'DepEquip',
            CP.CP_HotCrew        as 'HotCrew',
            CP.CP_ArrDeadhead as 'ArrDead',
            CP.CP_DepDeadhead as 'DepDead',
            isnull(CP.CP_CrewPos, 'N/A')      as 'Pos',
            CP.CP_BidPeriod            as 'BidPeriod',
            CP.CP_CostCenter           as 'CostCenter',
            DateAdd(MI, 420, COALESCE(CP.CP_UpdateDtTm, CP.CP_PostedDtTm)) as 'Posted', --yv 10/14/2019
            CP.CP_UpdateDtTm           as 'Updated',
            C.CP_NameLast        as 'LastName',
            C.CP_NameFirst             as 'FirstName',
            isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
 Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
                                        Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
            isnull(X.L_UID, isnull(L.L_UID, L2.L_UID)) as L_UID,   -- L.L_UID,
            CP.CP_ArrDtTm,
            isnull(X.L_UID, 0)   as X_LUID,
            case when CP.CP_Domicile = CP.CP_ArrFromStation
                    and CP.CP_Domicile <> CP.CP_DepToStation
                    AND CP.CP_ArrFromLayoverInd <> 10
                    then '*'
                    else ''
            end as 'TripStart',
        CP.CP_Op,
        case when CP.CP_SourceCd = 'ME'
                    then CP.CP_PostedId
                    else CP.CP_AssignCd
        end as Assign,
        CP.CP_Domicile,
        @Airline as Air,
        0 AS RecSort

        From dbNK.dbo.tblCityPair CP (NOLOCK)
    Left Join dbo.tblLayover  L       (nolock) 
                                    ON    (L.DF_AISUID = CP.CP_UID
                                --AND   L.L_CancelCd is null			--Commented on 4/22/2021 Subhrajit
                                AND   L.A_Symbol    = @Airline
                                AND   L.L_EmpId     = @EmpId
                                AND   (L.L_UID      In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
                                OR    L.L_UID              In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X')) )

        -- This is used when the CityPair continues to get updated, but since the data is in the past, it is not sent to the LMS (so find this way instead) JB 11/23/09
    Left Join dbo.tblLayover  L2      (nolock) 
                                    ON    L2.L_ArrStaCd = CP.CP_Station
                                AND   L2.L_EmpId           = CP.CP_CrewID       
                                AND   L2.L_ArrDtTm  between dateadd(hh, -2, dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
                                                                            and dateadd(hh, 2, dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
                                    --AND   L2.L_CancelCd        is null		--Commented on 4/22/2021 Subhrajit
                                AND   L2.A_Symbol   = @Airline
                                AND   L2.L_EmpId           = @EmpId
                                AND      L2.L_ArrDtTm  between @StartDt and @EndDt
                                AND   L2.L_UID      In (Select L_UID from dbo.tblInv (nolock) where L_UID = L2.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808

        Left Join dbo.tblCrewProfile C    (nolock) ON C.CP_EmpId = CP.CP_CrewId
                                                                            and C.A_Symbol = CP.CP_AirCustomer

        ---
        --- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
        ---
        Left Join dbo.tblCrewXL         X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
                                Where CX_EmpId       = @EmpId 
                                                                And A_Symbol       = @Airline
                                                                And CX_ArrStaCd    = CP.CP_Station
                                                                And CX_ArrDtTm       between 
                                                                                DateAdd(hh, -@Hrs, 
                                                                    dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
                                                                                and DateAdd(hh, @Hrs, 
                                                                                dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)))

   Left Join dbo.tblInv      I  (nolock) ON (I.L_UID     = isnull(L.L_UID, L2.L_UID)
                                                                            OR  I.L_UID       = X.L_UID)   

        Where  CP.CP_AirCustomer    = @Airline
        And    CP.CP_ArrDtTm between @StartDt and @EndDt
        And    CP.CP_CrewId  = @EmpId      
        And    CP.CP_Op             not in (20, 40)      -- Not dropped or UnAssigned.

        ORDER BY CP.CP_ArrDtTm
END
  -- end 'NK'

	--
	-- ATI
	--
	If @Airline = '8C'
	Begin
			Select 	Distinct
				CP.CP_UID,
				case when CP.CP_SourceCd = 'ME'
					then 'M' + CP.CP_TripCd
					else case when CP.CP_TripCd = CP.CP_CrewId
								then 'Non-Pair'
								else CP.CP_TripCd
						 end
				End as TripCd,
				--************ Jira 1516 - Update For Local Times In tblCityPair ************
				--CASE	WHEN	CP.CP_TripCd	= CP.CP_CrewID 
				--		THEN	DateAdd(mi, (CP.CP_ArrFromGMTOffset * case when @GMTFlg = 1 then 0 else -1 end), CP.CP_ArrFromOnDtTm) 
				--		ELSE	DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm)
				--END	AS 'ArrTime',

				--CP.CP_ArrDtTm AS 'ArrTime',

				case when @GMTFlg = 1	-- 8C is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
							end
				end		as 'ArrTime',


				-----------------------------------------------------------------------------
				--DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm)	AS 'ArrTime',

				CASE	WHEN CP.CP_ArrFlightNum NOT IN ('NOGT','HTL', 'CAR', 'LIMO', 'FAKE', 'HOM') --Added 'NOGT' by yashree vyas 6/10/2019
						AND ((CP.CP_ArrAirline NOT IN ('8C') OR ascii(substring(CP.CP_ArrAirline, 3, 1)) = 0)
						OR	((Len(CP.CP_ArrAirline) = 2 AND ascii(substring(CP.CP_ArrAirline, 3, 1)) <> 0) and CP.CP_ArrAirline not in ('8C')))
						AND CP_ArrAirline not in ('RSV', 'POS', 'TNG')
						THEN RTrim(isnull(convert(char(2), CP.CP_ArrAirline), ''))
						ELSE ''
				end + ltrim(isnull(CP.CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				
				isnull(CP.CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP.CP_Station, 'N/A') as 'Sta',
				isnull(CP.CP_DepToStation, 'N/A')	as 'To',
				--case	when @GMTFlg = 0
				--		then CP.CP_DepDtTm							      -- this is GMT time
				--		else dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_DepDtTm)			-- this is the normal station
				--end			as 'DepTime',
				--************ Jira 1516 - Update For Local Times In tblCityPair ************
				--CASE	WHEN	CP.CP_TripCd	= CP.CP_CrewID 
				--		THEN	DateAdd(mi, (CP.CP_DepToGMTOffset * @GMTFlg), CP.CP_DepToOffDtTm)	
				--		ELSE	DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm)	
				--END AS 'DepTime',

				--CASE	WHEN	CP.CP_TripCd	= CP.CP_CrewID 
				--		THEN	CP.CP_DepToOffDtTm
				--		ELSE	CP.CP_DepDtTm	
				--END AS 'DepTime',

				case when @GMTFlg = 1	-- 8C is in local time
					then CP_DepDtTm	      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
							end
				end		as 'DepTime',

				-----------------------------------------------------------------------------
				case when CP.CP_DepFlightNum not in ('NOGT','HTL', 'CAR', 'LIMO', 'FAKE', 'HOM') --Added 'NOGT' by yashree vyas 6/10/2019
						and ((CP.CP_DepAirline not in ('8C', 'RSV') 
						or ascii(substring(CP.CP_DepAirline, 3, 1)) = 0) 
						or ((Len(CP.CP_DepAirline) = 2 
						and ascii(substring(CP.CP_DepAirline, 3, 1)) <> 0) 
						and CP.CP_DepAirline <> '8C'))
						AND CP_DepAirline not in ('RSV', 'POS', 'TNG')
					then rtrim(isnull(convert(char(2), CP.CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP.CP_DepFlightNum, 'N/A'))	as 'DepFlt',


				case when (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) >= 60 
									  then (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) - (isnull(CP.CP_GroundTmi, isnull(L.L_GroundTmi, isnull(L2.L_GroundTmi, 0))) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

/*
				case when isnull(CP.CP_LayoverInd, 1) = 1	-- Changed 2/14/2018 Steve - No Longer Using Nearest Airport Domicile Rule ** See Above **
						then 'Yes'
						else ''	
				end as 'Layover',
*/
				--Added on 3/30/2022 Start
				case	when isnull(CP.CP_LayoverInd, 1) = 1	-- Changed 2/14/2018 Steve - No Longer Using Nearest Airport Domicile Rule ** See Above **
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						else ''	
				end as 'Layover',
				--Added on 3/30/2022 End			

				CP.CP_ArrTailNumber	as 'ArrTail',
				CP.CP_DepTailNumber	as 'DepTail',
				CP.CP_ArrEquipmentCd	as 'ArrEquip',
				CP.CP_DepEquipmentCd	as 'DepEquip',
				CP.CP_HotCrew		as 'HotCrew',
				case when CP.CP_ArrDeadhead in ('D','F','P','S') then 'COM'  --'C' then 'COM'
				     when CP.CP_ArrDeadhead = 'G' then 'GRD'
				     when CP.CP_ArrDeadhead = 'A' then CP.CP_AirCustomer
							       else NULL
				end			as 'ArrDead',
				case when CP.CP_DepDeadhead in ('D','F','P','S') then 'COM'  --= 'C' then 'COM'
				     when CP.CP_DepDeadhead = 'G' then 'GRD'
				     when CP.CP_DepDeadhead = 'A' then CP.CP_AirCustomer
							       else NULL
				end			as 'DepDead',
				isnull(CP.CP_CrewPos, 'N/A')	as 'Pos',
				CP.CP_BidPeriod 		as 'BidPeriod',
				CP.CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP.CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, isnull(L.L_UID, L2.L_UID)) as L_UID,	-- L.L_UID,
				CP.CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
				      AND CP.CP_ArrFromLayoverInd	<> 10
					then '*'
					else ''
				end as 'TripStart',
			CP.CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,
			CP.CP_Domicile,
			@Airline as Air,
			0 AS RecSort

			From db8C.dbo.tblCityPair CP (NOLOCK)
	 		Left Join dbo.tblLayover  L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X')) )

			-- This is used when the CityPair continues to get updated, but since the data is in the past, it is not sent to the LMS (so find this way instead) JB 11/23/09
	 		Left Join dbo.tblLayover  L2 	(nolock) 
							 ON 	L2.L_ArrStaCd	= CP.CP_Station
							 AND	L2.L_EmpId		= CP.CP_CrewID	
							 
							 --************ Jira 1516 - Update For Local Times In tblCityPair ************
							 AND	L2.L_ArrDtTm	BETWEEN dateadd(hh, -2, CP.CP_ArrDtTm) AND dateadd(hh, 2,CP.CP_ArrDtTm) -- AIS In Local Time
							 --AND	L2.L_ArrDtTm	between dateadd(hh, -2, dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
								--					  and dateadd(hh, 2, dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
							 --AND 	L2.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L2.A_Symbol 	= @Airline
							 AND 	L2.L_EmpId		= @EmpId
						     AND	L2.L_ArrDtTm	between @StartDt and @EndDt
							 AND	L2.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L2.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
													and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
																		Where CX_EmpId 	= @EmpId 
																		  And A_Symbol 	= @Airline
																		  And CX_ArrStaCd 	= CP.CP_Station
																		  --************ Jira 1516 - Update For Local Times In tblCityPair ************
																		  And CX_ArrDtTm	between  DATEADD(hh, -@Hrs,CP.CP_ArrDtTm) AND 	DATEADD(hh, @Hrs, CP.CP_ArrDtTm ) )-- AIS In Local Time
																		--DATEADD(hh, -@Hrs, 
																		--dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
														
																		-- DateAdd(hh, @Hrs, 
																		--dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = isnull(L.L_UID, L2.L_UID)
													 OR  I.L_UID	 = X.L_UID)	

			Where	CP.CP_AirCustomer 	= @Airline
			And	CP.CP_ArrDtTm	between @StartDt and @EndDt
			And	CP.CP_CrewId	= @EmpId	
			And	CP.CP_Op		not in (20, 40)	-- Not dropped or UnAssigned.

			Order by CP.CP_ArrDtTm, RecSort
	End  -- end '8C'


-- --*************************************************************************************************************************************
-- Republic Airlines (YX) - (CrewTrac/UTC - dbYX)

	If @Airline = 'YX'
	Begin
        Select        Distinct
            CP.CP_UID,
            case when CP.CP_SourceCd = 'ME'
                    then 'ME' 
                    ELSE CP.CP_TripCd
            End as TripCd,
            DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) AS 'ArrTime',
            CASE   WHEN CP.CP_ArrFlightNum NOT IN ('NOGT','HTL', 'CAR', 'LIMO', 'FAKE', 'HOM', 'LIM') --Added 'NOGT' by yashree vyas 6/10/2019 - Added LIM Steve 8/6/2019
                            AND ((CP.CP_ArrAirline NOT IN ('YX') OR ascii(substring(CP.CP_ArrAirline, 3, 1)) = 0)
                            OR     ((Len(CP.CP_ArrAirline) = 2 AND ascii(substring(CP.CP_ArrAirline, 3, 1)) <> 0) and CP.CP_ArrAirline not in ('YX')))
                            AND CP_ArrAirline not in ('RSV', 'POS', 'TNG')
                            THEN RTrim(isnull(convert(char(2), CP.CP_ArrAirline), ''))
                            ELSE ''
            end + ltrim(isnull(CP.CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
            isnull(CP.CP_ArrFromStation, 'N/A')      as 'From',
            isnull(CP.CP_Station, 'N/A') as 'Sta',
			isnull(CP_Station, 'N/A')	as 'DepSta',
            isnull(CP.CP_DepToStation, 'N/A') as 'To',
            DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm)    AS 'DepTime',
            case when CP.CP_DepFlightNum not in ('NOGT','HTL', 'CAR', 'LIMO', 'FAKE', 'HOM', 'LIM') --Added 'NOGT' by yashree vyas 6/10/2019 - Added LIM Steve 8/6/2019
                            and ((CP.CP_DepAirline not in ('YX', 'RSV') 
                            or ascii(substring(CP.CP_DepAirline, 3, 1)) = 0) 
                            or ((Len(CP.CP_DepAirline) = 2 
                            and ascii(substring(CP.CP_DepAirline, 3, 1)) <> 0) 
                            and CP.CP_DepAirline <> 'YX'))
                            AND CP_DepAirline not in ('RSV', 'POS', 'TNG')
                    then rtrim(isnull(convert(char(2), CP.CP_DepAirline), ''))
                    else ''
            end + ltrim(isnull(CP.CP_DepFlightNum, 'N/A'))  as 'DepFlt',
   IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
            case	when isnull(CP.CP_LayoverInd, 1) = 1 -- Changed 2/14/2018 Steve - No Longer Using Nearest Airport Domicile Rule ** See Above **
                    then 'Yes'
					when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																		and T_EmpId				= @EmpId
																		and A_Symbol			= @Airline																					
																		and CP.CP_LayoverInd	<> 1
																		and T_TripCd			= 'SS'
																		and T_CancelResultCd	= 0
																		and T_ConfDtTm			is not null
																		and TT.CP_UID			= CP.CP_UID
/*
																		-- Some wiggle room for updates?
																		and ((CP.CP_ArrFlightNum = 'LIMO'
																		AND   CP.CP_ArrFltSeq	= 10
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm)))
																		or  (CP.CP_DepFlightNum	= 'LIMO'
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm)))
																	)
*/																	
																	)
						--
						-- Find Airport to Airport ground trips.
						--
					then 'Grd'
                    else ''       
            end as 'Layover',
            CP.CP_ArrTailNumber  as 'ArrTail',
            CP.CP_DepTailNumber  as 'DepTail',
            CP.CP_ArrEquipmentCd as 'ArrEquip',
            CP.CP_DepEquipmentCd as 'DepEquip',
            CP.CP_HotCrew        as 'HotCrew',
            CP.CP_ArrDeadhead as 'ArrDead',
            CP.CP_DepDeadhead as 'DepDead',
            isnull(CP.CP_CrewPos, 'N/A')      as 'Pos',
            CP.CP_BidPeriod            as 'BidPeriod',
            CP.CP_CostCenter           as 'CostCenter',
            COALESCE(CP.CP_UpdateDtTm, CP.CP_PostedDtTm, getdate()) as 'Posted',
--            isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
            CP.CP_UpdateDtTm           as 'Updated',
            C.CP_NameLast        as 'LastName',
            C.CP_NameFirst             as 'FirstName',
            isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
                                        Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
                                        Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
            isnull(X.L_UID, isnull(L.L_UID, L2.L_UID)) as L_UID,   -- L.L_UID,
            CP.CP_ArrDtTm,
            isnull(X.L_UID, 0)   as X_LUID,
            case when CP.CP_Domicile = CP.CP_ArrFromStation
                    and CP.CP_Domicile <> CP.CP_DepToStation
                    AND CP.CP_ArrFromLayoverInd <> 10
                    then '*'
                    else ''
            end as 'TripStart',
        CP.CP_Op,
        case when CP.CP_SourceCd = 'ME'
                    then CP.CP_PostedId
                    else CP.CP_AssignCd
        end as Assign,
        CP.CP_Domicile,
        @Airline as Air,
        0 AS RecSort

        From dbYX_NB.dbo.tblCityPair CP (NOLOCK)
    Left Join dbo.tblLayover  L       (nolock) 
                                    ON    (L.DF_AISUID = CP.CP_UID
                                --AND   L.L_CancelCd is null			--Commented on 4/22/2021 Subhrajit
                                AND   L.A_Symbol    = @Airline
                                AND   L.L_EmpId     = @EmpId
                                AND   (L.L_UID      In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
                                OR    L.L_UID              In (Select
 L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X')) )

        -- This is used when the CityPair continues to get updated, but since the data is in the past, it is not sent to the LMS (so find this way instead) JB 11/23/09
    Left Join dbo.tblLayover  L2      (nolock) 
                                    ON    L2.L_ArrStaCd = CP.CP_Station
                      AND   L2.L_EmpId           = CP.CP_CrewID       
                                AND   L2.L_ArrDtTm  between dateadd(hh, -2, dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
                                                                            and dateadd(hh, 2, dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
                    --AND   L2.L_CancelCd        is null		--Commented on 4/22/2021 Subhrajit
                                AND   L2.A_Symbol   = @Airline
                                AND   L2.L_EmpId           = @EmpId
                                AND      L2.L_ArrDtTm  between @StartDt and @EndDt
                                AND   L2.L_UID      In (Select L_UID from dbo.tblInv (nolock) where L_UID = L2.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808

        Left Join dbo.tblCrewProfile C    (nolock) ON C.CP_EmpId = CP.CP_CrewId
                                                                            and C.A_Symbol = CP.CP_AirCustomer

        ---
        --- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
        ---
        Left Join dbo.tblCrewXL         X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
                                                            Where CX_EmpId       = @EmpId 
                                                                And A_Symbol       = @Airline
                                                                And CX_ArrStaCd    = CP.CP_Station
                                                                And CX_ArrDtTm       between 
                                                                                DateAdd(hh, -@Hrs, 
                                                                                dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)) 
                                                                                and DateAdd(hh, @Hrs, 
                                                                                dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_ArrDtTm)))

        Left Join dbo.tblInv      I  (nolock) ON (I.L_UID     = isnull(L.L_UID, L2.L_UID)
                                                                            OR  I.L_UID       = X.L_UID)   

        Where  CP.CP_AirCustomer    = @Airline
        And    CP.CP_ArrDtTm between @StartDt and @EndDt
        And    CP.CP_CrewId  = @EmpId      
        And    CP.CP_Op             not in (20, 40)      -- Not dropped or UnAssigned.

        ORDER BY CP.CP_ArrDtTm
END
  -- end 'YX'


	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- Etihad  2/7/19 JB  -- Update 4/20/2019 - EY IS NOT IN GMT!!
	If @Airline = 'EY'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'Manual'
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- EY is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- EY is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				
				
				
				
				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',
				case when isnull(CP_LayoverInd, 1) = 1
					then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
					WHEN CP.CP_GroundTmi	> 509
					AND	 CP.CP_DomicileInd	= 1
					THEN 'Dom'
					else ''
				end			as 'Layover',


				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'EY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'EY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'EY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'EY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbEY.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End -- 'EY'


	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- Omni 5/2/2019 Steve -- OY IS LOCAL!!
	If @Airline = 'OY'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- OY is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- OY is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case when isnull(CP_LayoverInd, 1) = 1
					then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
					WHEN CP.CP_GroundTmi	> 509
					AND	 CP.CP_DomicileInd	= 1
					THEN 'Dom'
					else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'OY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'OY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'OY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'OY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbOY.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'OY'


		-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- CommutAir 10/29/2019 JB -- C5 IS LOCAL!!
	If @Airline = 'C5'
	Begin
			Select 	Distinct
				CP_UID,
				CP.CP_TripCd as TripCd,
				case when @GMTFlg = 1	-- C5 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- C5 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end + 

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +
				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +
				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				IIF(NullIf(CP_ArrDeadhead, '') IS NOT NULL, 'DH', NULL)		AS 'ArrDead',
				IIF(NullIf(CP_DepDeadHead, '') IS NOT NULL, 'DH', NULL)		AS 'DepDead',

				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,
			CP.CP_Domicile,
			@Airline as Air,
			DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm) AS GMTArr

			From dbC5.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'C5'

	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------

	If @Airline = 'PT'
	Begin

			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,

			DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) AS 'ArrTime',

				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('PT') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'PT'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',


				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

					DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm) AS 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('PT') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'PT')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',


				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',


				--isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0))		as 'GrndTime',


				case	when isnull(CP_LayoverInd, 1)		= 1		then 'Yes'
						when substring(CP_TripCd, 1, 1)	= 'T'	then 'No'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																		and T_EmpId				= @EmpId
																		and A_Symbol			= @Airline																					
																		and CP.CP_LayoverInd	<> 1
																		and T_TripCd			= 'SS'
																		and T_CancelResultCd	= 0
																		and T_ConfDtTm			is not null
																		and TT.CP_UID			= CP.CP_UID
/*
																		-- Some wiggle room for updates?
																		and ((CP.CP_ArrFlightNum = 'LIMO'
																		AND   CP.CP_ArrFltSeq	= 10
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm)))
																		or  (CP.CP_DepFlightNum	= 'LIMO'
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm)))
																	)
*/																	
																	)
						--
						-- Find Airport to Airport ground trips.
						--
					then 'Grd'
					 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
					WHEN CP.CP_GroundTmi	> 509
					AND	 CP.CP_DomicileInd	= 1
					THEN 'Dom'
					-- End Add
					else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbPT.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X')
							 )




			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON ((I.L_UID     = L.L_UID and I_CancelResultCd not in (1,3))
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				
			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'PT'


	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------

	If @Airline = 'HA'
	Begin

			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,

				case when @GMTFlg = 0
					then CP_ArrDtTm	      -- this is GMT time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) --dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)   -- this is local
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',

				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('HA') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'HA'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',


				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 0
					then CP_DepDtTm							      -- this is GMT time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm)  --dbo.uFN_GetLocalStaTime(CP.CP_Station, CP.CP_DepDtTm)   -- this is local
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('HA') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'HA')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',


				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',


				--isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0))		as 'GrndTime',


				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																		and T_EmpId				= @EmpId
																		and A_Symbol			= @Airline																					
																		and CP.CP_LayoverInd	<> 1
																		and T_TripCd			= 'SS'
																		and T_CancelResultCd	= 0
																		and T_ConfDtTm			is not null
																		and TT.CP_UID			= CP.CP_UID
/*
																		-- Some wiggle room for updates?
																		and ((CP.CP_ArrFlightNum = 'LIMO'
																		AND   CP.CP_ArrFltSeq	= 10
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm)))
																		or  (CP.CP_DepFlightNum	= 'LIMO'
																		and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm))
																								and     dateadd(mi, 10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm)))
																	)
*/																	
																	)
						--
						-- Find Airport to Airport ground trips.
						--
						then 'Grd'
						when substring(CP_TripCd, 1, 1)	= 'T'		
						then 'No'
						else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbHA.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )


			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			--And CP_TripCd			<> CP_CrewId	-- Hide these	--Commented on 4/22/2021 Subhrajit

			Order by CP_ArrDtTm

	End  -- end 'HA'



	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------

	If @Airline = 'OH'
	Begin

			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,

				case when @GMTFlg = 0	
					then CP_ArrDtTm	   
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',

				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('OH') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'OH'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',


				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

					case when @GMTFlg = 0
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm)  --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('OH') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'OH')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',


				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',


				--isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0))		as 'GrndTime',


				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 10
																			and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm))
																									and     dateadd(mi, 10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm)))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm))
																									and     dateadd(mi, 10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm)))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						when substring(CP_TripCd, 1, 1)	= 'T'	
						then 'No'
						else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer
				       else CP_ArrDeadhead
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'
				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
					 else CP_DepDeadhead
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				COALESCE(CP.CP_UpdateDtTm, CP.CP_PostedDtTm, getdate()) as Posted, 
--				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbOH.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )




			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'OH'


	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- Volaris (LOCAL TIME dbY4!)
	If @Airline = 'Y4'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- Y4 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('Y4') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'Y4'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',

				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 1	-- Y4 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('Y4') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'Y4')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',


				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
				    -- when substring(CP_TripCd, 1, 1)	= 'T'	then 'No'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
					 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
					WHEN CP.CP_GroundTmi	> 509
					AND	 CP.CP_DomicileInd	= 1
					THEN 'Dom'
					-- End Add
					else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbY4.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				
			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'

	End  -- end 'Y4'


	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- JAL (LOCAL TIME dbJL?)
	If @Airline = 'JL'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- Y4 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('JL') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'JL'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',

				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 1	-- JL is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('JL') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'JL')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',


				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
				    -- when substring(CP_TripCd, 1, 1)	= 'T'	then 'No'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
					 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
					WHEN CP.CP_GroundTmi	> 509
					AND	 CP.CP_DomicileInd	= 1
					THEN 'Dom'
					-- End Add
					else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer
					 when CP_ArrDeadhead is not null then 'DH'			-- Added Steve 2/12/2020

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
					 when CP_DepDeadhead is not null then 'DH'			-- Added Steve 2/12/2020
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbJL.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'JL'

--*************************************************************************************************************************************

	-- Scoot (LOCAL TIME dbTR!)
	If @Airline = 'TR'
	Begin

		DECLARE	@CrewCount	INT = IIF(CharIndex('/',@EmpId) = 0, 1, 2);
		DECLARE @EE1 varchar(12);
		DECLARE @EE2 varchar(12);
		DECLARE	@CurCrewID VarChar(12);

		SET		@EE1		= RTrim(IIF(CharIndex('/',@EmpId) > 0, Left(@EmpId, CharIndex('/',@EmpId) - 1), @EmpId));
		SET		@EE2		= RTrim(IIF(CharIndex('/',@EmpId) > 0, Right(@EmpId, IsNull(Len(@EmpId) - CharIndex('/',@EmpId),0)), @EmpId));
		SET		@CurCrewID	= @EE1;

		WHILE	@CrewCount > 0
		BEGIN
			Select 	Distinct
				IsNull(CS.CS_UID, CP_UID) AS CP_UID,
				case when CP_SourceCd	= 'ME' 		then 'M' + CP_TripCd
				     when CP_TripCd		= CP_CrewId then 'NonPRG'
													else CP.CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- TR is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				case when ((CP_ArrAirline not in ('TR') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) 
							or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) 
							and CP_ArrAirline <> 'TR')) and ltrim(CP_ArrFlightNum) <> 'LIMO'
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), ''))
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 1	-- TR is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when ((CP_DepAirline not in ('TR') or ascii(substring(CP_DepAirline, 3, 1)) = 0) 
							or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) 
							and CP_DepAirline <> 'TR')) and ltrim(CP_DepFlightNum) <> 'LIMO'
					then rtrim(isnull(convert(char(2), CP.CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
	
				--case when case when (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) = 0
				--			then ''
				--			else right(rtrim(convert(char(5), isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440)), 2) + 'D ' 
				--		  end = ''
				--		then '   '
				--		else ''
				--end +

				--right(rtrim(case when case when (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) >= 60 
				--					  then (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) / 60
				--					  else '0' 
				--		  end		  < 10
				--			then '0' + case when (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) >= 60 
				--						then convert(char(2), (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) / 60)
				--						else '0' 
				--					   end
				--			else case when (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) >= 60 
				--					  then convert(char(2), (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) / 60)
				--					  else '0' 
				--				 end
				--end), 2)
				--+ ':' +

				--case when ((isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) % 60) < 10
				--		then '0' + convert(char(5), (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) % 60)
				--		else convert(char(5), (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) - (isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) / 1440) * 1440) % 60)
				--end
				
				--as 'GrndTime',
				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',



--				isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0))		as 'GrndTime',
	
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbTR.dbo.tblCityPair CP (nolock)
			LEFT JOIN	dbTR.dbo.tblCrewShare	AS CS	ON ((CP.CP_UID = CS.CP_UID1 OR (CP.CP_UID = CS.CP_UID2))) AND ((CS.CP_CrewID1 IN (@CurCrewID)) OR (CS.CP_CrewID2 IN (@CurCrewID)))
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= IsNull(CS.CS_UID, CP_UID)
							 --ON		(L.DF_AISUID 	= CP.CP_UID		--Changed 05/31/2021 Steve - Remove Share-with ID 
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	((RTrim(IIF(CharIndex('/',L.L_EmpId) > 0, Left(RTrim(L.L_EmpId), CharIndex('/',L.L_EmpId) - 1), L.L_EmpId)) = @CurCrewID)
							 OR		 (RTrim(IIF(CharIndex('/',L.L_EmpId) > 0, Right(RTrim(L.L_EmpId), IsNull(Len(L.L_EmpId) - CharIndex('/',L.L_EmpId),0)), L.L_EmpId)) = @CurCrewID)
									)
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where A_Symbol 	= @Airline
											 AND 	((RTrim(IIF(CharIndex('/',X.CX_EmpId) > 0, Left(RTrim(X.CX_EmpId), CharIndex('/',X.CX_EmpId) - 1), X.CX_EmpId)) = @CurCrewID)
											 OR		 (RTrim(IIF(CharIndex('/',X.CX_EmpId) > 0, Right(RTrim(X.CX_EmpId), IsNull(Len(X.CX_EmpId) - CharIndex('/',X.CX_EmpId),0)), X.CX_EmpId)) = @CurCrewID)
													)
											  --And CX_EmpId 	in (@EmpId, @CurCrewID)
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @CurCrewID --  in (@EE1, @EE2)	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				
			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
			SET	@CrewCount	= @CrewCount -1
			IF	@CrewCount	> 0 SET	@CurCrewID	= @EE2
		END
	End  -- 'TR'

	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- Interjet (LOCAL TIME db40!)
	If @Airline = '4O'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- 4O is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('4O') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> '4O'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',

				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 1	-- 4O is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('4O') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> '4O')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
				    -- when substring(CP_TripCd, 1, 1)	= 'T'	then 'No'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						-- End Add
						else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				  when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From db4O.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null	-- 8/30/2018 - Need To Always Show L_UID In tblInv/tblOrder; Might Not Be Active L_UID
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end '4O'


	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- easyjet (LOCAL TIME dbU2???)

	If @Airline = 'U2'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- U2 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('U2') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'U2'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',

				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 1	-- U2 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('U2') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'U2')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
				    -- when substring(CP_TripCd, 1, 1)	= 'T'	then 'No'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						-- End Add
						else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbU2.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'U2'


	-- ------------------------------------------------------------------------------------------------------------
	-- Swift (LOCAL TIME dbWQ)

	If @Airline = 'WQ'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				 							 else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- WQ is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('WQ') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',

				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				case when @GMTFlg = 1	-- WQ is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('WQ') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
				    -- when substring(CP_TripCd, 1, 1)	= 'T'	then 'No'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						-- End Add
						else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbWQ.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'WQ'

			--*************************************************************************************************************************************
	--*************************************************************************************************************************************
	-- ------------------------------------------------------------------------------------------------------------
	-- Western Global (LOCAL TIME dbKD)

	If @Airline = 'KD'
	Begin
			Select 	Distinct
				CP_UID,
				case	when CP_SourceCd = 'ME'      
						then 'Manual'
						when CP_TripCd   = CP_CrewId 
						then 'NonPrg'
						else CP_TripCd
				End as TripCd,
				case	when @GMTFlg = 1	-- KD is in local time
						then CP_ArrDtTm		-- this is local time
						else case	when CP_ArrDtTm is not null 
									then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
									else L.L_ArrDtTm   -- this is local
					     end
				end		as 'ArrTime',
				case	when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('KD') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
						then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
						else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case	when @GMTFlg = 1	-- KD is in local time
						then CP_DepDtTm		-- this is local time
						else	case when CP_DepDtTm is not null
								then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
								else L.L_DepDtTm   -- this is local
					     end
				end		as 'DepTime',
				case	when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('KD') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
						then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
						else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''	
				end as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CP_ArrDeadhead		as 'ArrDead',
				CP_DepDeadhead		as 'DepDead',
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbKD.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR		L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And		CP_ArrDtTm			between @StartDt and @EndDt
			And		CP_CrewId			= @EmpId	
			And		CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'KD'

--*************************************************************************************************************************************
-- Eastern Airlines (LOCAL TIME db2D)

	If @Airline = '2D'
	Begin
			Select 	Distinct
				CP_UID,
				case	when CP_SourceCd = 'ME'      
						then 'Manual'
						when CP_TripCd   = CP_CrewId 
						then 'NonPrg'
						else CP_TripCd
				End as TripCd,
				case	when @GMTFlg = 1	-- 2D is in local time
						then CP_ArrDtTm		-- this is local time
						else case	when CP_ArrDtTm is not null 
									then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
									else L.L_ArrDtTm   -- this is local
					     end
				end		as 'ArrTime',
				case	when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('2D') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
						then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
						else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case	when @GMTFlg = 1	-- 2D is in local time
						then CP_DepDtTm		-- this is local time
						else	case when CP_DepDtTm is not null
								then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
								else L.L_DepDtTm   -- this is local
					     end
				end		as 'DepTime',
				case	when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('2D') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
						then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
						else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''	
				end as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CP_ArrDeadhead		as 'ArrDead',
				CP_DepDeadhead		as 'DepDead',
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From db2D.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR		L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And		CP_ArrDtTm			between @StartDt and @EndDt
			And		CP_CrewId			= @EmpId	
			And		CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end '2D'

--*************************************************************************************************************************************
-- START Air Arabia
--*************************************************************************************************************************************
-- Air Arabia (GMT TIME dbG9)

	If @Airline = 'G9'
	Begin
			Select 	Distinct
				CP_UID,
				case	when CP_SourceCd = 'ME'      
						then 'Manual'
						else CP_TripCd
				End as TripCd,
				DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) as 'ArrTime',				
				case	when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('G9') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
						then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
						else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepStation, 'N/A')	as 'DepSta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm) as 'DepTime',
				case	when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('G9') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
						then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
						else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''	
				end as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CP_ArrDeadhead		as 'ArrDead',
				CP_DepDeadhead		as 'DepDead',
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbG9.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
--							 AND 	L.L_CancelCd 	is null
							 AND 	L.A_Symbol 		= @Airline
							 AND 	L.L_EmpId		= @EmpId
							 AND	(L.L_UID		In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR		L.L_UID			In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
																		Where CX_EmpId 	= @EmpId 
																		  And A_Symbol 	= @Airline
																		  And CX_ArrStaCd 	= CP.CP_Station
																		  And CX_ArrDtTm	between 
																			DateAdd(hh, -@Hrs, 
																			dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
																			and DateAdd(hh, @Hrs, 
																			dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And		CP_ArrDtTm			between @StartDt and @EndDt
			And		CP_CrewId			= @EmpId	
			And		CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'G9'
--*************************************************************************************************************************************
--*************************************************************************************************************************************
-- Air Arabia Egypt (GMT TIME dbE5)

	If @Airline = 'E5'
	Begin
			Select 	Distinct
				CP_UID,
				case	when CP_SourceCd = 'ME'      
						then 'Manual'
						else CP_TripCd
				End as TripCd,
				DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) as 'ArrTime',				
				case	when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('E5') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
						then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
						else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepStation, 'N/A')	as 'DepSta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm) as 'DepTime',
				case	when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('E5') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
						then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
						else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''	
				end as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CP_ArrDeadhead		as 'ArrDead',
				CP_DepDeadhead		as 'DepDead',
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbE5.dbo.tblCityPair CP (nolock)

	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
--							 AND 	L.L_CancelCd 	is null
							 AND 	L.A_Symbol 		= @Airline
							 AND 	L.L_EmpId		= @EmpId
							 AND	(L.L_UID		In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR		L.L_UID			In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
													AND C.A_Symbol = CP.CP_AirCustomer
			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID in (Select distinct L_UID From dbo.tblCrewXL 
																		Where CX_EmpId 	= @EmpId 
																		And A_Symbol 	= @Airline
																		And CX_ArrStaCd 	= CP.CP_Station
																		And CX_ArrDtTm	between 
																				DateAdd(hh, -@Hrs, 
																				dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
																				and DateAdd(hh, @Hrs, 
																				dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And		CP_ArrDtTm		between @StartDt and @EndDt
			And		CP_CrewId		= @EmpId	
			And		CP_Op			not in (20, 40)	-- Not dropped or UnAssigned.

			order by 'ArrTime'
	End  -- end 'E5'
--*************************************************************************************************************************************
--*************************************************************************************************************************************
-- Air Arabia Maroc (GMT TIME db3O)

	If @Airline = '3O'
	Begin
			Select 	Distinct
				CP_UID,
				case	when CP_SourceCd = 'ME'      
						then 'Manual'
						else CP_TripCd
				End as TripCd,
				DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) as 'ArrTime',				
				case	when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('3O') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
						then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
						else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepStation, 'N/A')	as 'DepSta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm) as 'DepTime',
				case	when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('3O') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
						then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
						else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and  dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''	
				end as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CP_ArrDeadhead		as 'ArrDead',
				CP_DepDeadhead		as 'DepDead',
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From db3O.dbo.tblCityPair CP (nolock)

	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
--							 AND 	L.L_CancelCd 	is null
							 AND 	L.A_Symbol 		= @Airline
							 AND 	L.L_EmpId		= @EmpId
							 AND	(L.L_UID		In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR		L.L_UID			In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
													AND C.A_Symbol = CP.CP_AirCustomer
			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
																		Where CX_EmpId 	= @EmpId 
																		And A_Symbol 	= @Airline
																		And CX_ArrStaCd 	= CP.CP_Station
																		And CX_ArrDtTm	between 
																				DateAdd(hh, -@Hrs, 
																				dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
																				and DateAdd(hh, @Hrs, 
																				dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And		CP_ArrDtTm		between @StartDt and @EndDt
			And		CP_CrewId		= @EmpId	
			And		CP_Op			not in (20, 40)	-- Not dropped or UnAssigned.

			order by 'ArrTime'
	End  -- end '3O'
--*************************************************************************************************************************************
--*************************************************************************************************************************************
-- Air Arabia Maroc (GMT TIME db3L)

	If @Airline = '3L'
	Begin
			Select 	Distinct
				CP_UID,
				case	when CP_SourceCd = 'ME'      
						then 'Manual'
						else CP_TripCd
				End as TripCd,
				DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) as 'ArrTime',				
				case	when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('3L') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'WQ'))
						then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
						else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepStation, 'N/A')	as 'DepSta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm) as 'DepTime',
				case	when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('3L') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'WQ')) 
						then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
						else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				IIF(CP.CP_GroundTmi < 600, ('0' + CAST(CP.CP_GroundTmi/60 AS VarChar(5))), CAST(CP.CP_GroundTmi/60 AS VarChar(5))) + ':' + RIGHT('0' + CAST(CP.CP_GroundTmi%60 AS VarChar(2)),2) AS GrndTime,
				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						 -- Added 5/16/2016 Steve - Show "Dom" When Crewmember Domicile
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''	
				end as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CP_ArrDeadhead		as 'ArrDead',
				CP_DepDeadhead		as 'DepDead',
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From db3L.dbo.tblCityPair CP (nolock)

	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
--							 AND 	L.L_CancelCd 	is null
							 AND 	L.A_Symbol 		= @Airline
							 AND 	L.L_EmpId		= @EmpId
							 AND	(L.L_UID		In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR		L.L_UID			In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )

			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
													AND C.A_Symbol = CP.CP_AirCustomer
			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
																		Where CX_EmpId 	= @EmpId 
																		And A_Symbol 	= @Airline
																		And CX_ArrStaCd 	= CP.CP_Station
																		And CX_ArrDtTm	between 
																				DateAdd(hh, -@Hrs, 
																				dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
																				and DateAdd(hh, @Hrs, 
																				dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And		CP_ArrDtTm		between @StartDt and @EndDt
			And		CP_CrewId		= @EmpId	
			And		CP_Op			not in (20, 40)	-- Not dropped or UnAssigned.

			order by 'ArrTime'
	End  -- end '3L'
--*************************************************************************************************************************************
-- END Air Arabia
--*****************************************************************************************************************************

-- --*************************************************************************************************************************************
-- Vueling Airlines (VY) --Added on 9/13/2021 Subhrajit --Local Time

	If @Airline = 'VY'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- VY is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- VY is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'VY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'VY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'VY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'VY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbVY.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'VY'
  -- end 'VY'

  -- --*************************************************************************************************************************************
-- European Cargo (PS) --Added on 9/30/2021 Subhrajit --Local Time

	If @Airline = 'SE'		--Replaced PS with SE on 4/7/2022 Subhrajit
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- SE is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- SE is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'SE'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'SE'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'SE'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'SE'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbSE.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'SE'
  -- end 'SE'

-- --*************************************************************************************************************************************
-- Wizz Air (W6) --Added on 2/28/2022 Subhrajit --Local Time

	If @Airline = 'W6'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- W6 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- W6 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'W6'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'W6'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'W6'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'W6'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbW6_CLW.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'W6'
  -- end 'W6'

  -- --*************************************************************************************************************************************
-- ASL Airlines France (5O) --Added on 5/9/2022 Subhrajit --Local Time

	If @Airline = '5O'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- 5O is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- 5O is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> '5O'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= '5O'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> '5O'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= '5O'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From db5O.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- '5O'
  -- end '5O'
	-- ---------------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------
	-- ------------------------------------------------------------------------------------------------------------


--	exec [wspCrewSchedule] 'F9', '2022-12-01', '411061', 0,30
--  select * from dbF9.dbo.tblCitypair where CP_UID = 106418
-- F9 is in GMT on CityPair table!
--
	If @Airline = 'F9'
	Begin

			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'      then 'Manual'
				     when CP_TripCd   = CP_CrewId then 'NonPrg'
				     							  else CP_TripCd
				End as TripCd,

				DateAdd(mi, (CP.CP_ArrGMTOffset * @GMTFlg), CP.CP_ArrDtTm) AS 'ArrTime',

				/** wrong  JB 11/30/22
				case when @GMTFlg = 1	-- Want it in GMT time
					then CP_ArrDtTm	      -- this is GMT time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm), CP_ArrDtTm)   -- this is Local
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				**/

				case when Len(CP_ArrAirline) <> 3 and ((CP_ArrAirline not in ('F9') or ascii(substring(CP_ArrAirline, 3, 1)) = 0) or ((Len(CP_ArrAirline) = 2 and ascii(substring(CP_ArrAirline, 3, 1)) <> 0) and CP_ArrAirline <> 'F9'))
					then rtrim(isnull(convert(char(2), CP.CP_ArrAirline), '')) 
					else ''
				end + ltrim(isnull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',


				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

				DateAdd(mi, (CP.CP_DepGMTOffset * @GMTFlg), CP.CP_DepDtTm) AS 'DepTime',
							   
				/* wrong JB 11/30/22
				case when @GMTFlg = 1	-- Want it in GMT time
					then CP_DepDtTm	      -- this is GMT time
					else case when CP_DepDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm), CP_DepDtTm)   -- this is Local
							else L.L_DepDtTm   -- this is local
					     end
				end as 'DepTime',
				*/


				case when Len(CP_DepAirline) <> 3 and ((CP_DepAirline not in ('F9') or ascii(substring(CP_DepAirline, 3, 1)) = 0) or ((Len(CP_DepAirline) = 2 and ascii(substring(CP_DepAirline, 3, 1)) <> 0) and CP_DepAirline <> 'F9')) 
					then rtrim(isnull(convert(char(2), CP_DepAirline), ''))
					else ''
				end + ltrim(isnull(CP_DepFlightNum, 'N/A'))	as 'DepFlt',
				--isnull(CP_DepFlightNum, 'N/A')	as 'DepFlt',


				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull
(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',


				--isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0))		as 'GrndTime',


				case	when isnull(CP_LayoverInd, 1)		= 1		
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 10
																			and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm))
																									and     dateadd(mi, 10, DateAdd(mi, CP.CP_ArrFromGMTOffset, CP.CP_ArrFromDepDtTm)))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm))
																									and     dateadd(mi, 10, DateAdd(mi, CP.CP_DepGMTOffset, CP.CP_DepDtTm)))
																		)
*/
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						when substring(CP_TripCd, 1, 1)	= 'T'	
						then 'No'
						else ''	
				end as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer
				       else CP_ArrDeadhead
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'
				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
					 else CP_DepDeadhead
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				COALESCE(CP.CP_UpdateDtTm, CP.CP_PostedDtTm, getdate()) as Posted, 
--				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			From dbF9.dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )




			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
				

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end 'F9'

-- --*************************************************************************************************************************************
-- LynxAir (Y9) --Added on 31/1/2023 Subhrajit --Local Time

	If @Airline = 'Y9'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- Y9 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- Y9 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'Y9'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'Y9'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'Y9'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'Y9'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbY9.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'Y9'
  -- end 'Y9'

-- --*************************************************************************************************************************************
-- Volotea Airlines (V7) --Added on 5/29/2023 Subhrajit --Local Time

	If @Airline = 'V7'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- V7 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- V7 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'V7'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'V7'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'V7'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'V7'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock) 
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbV7.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'V7'
  -- end 'V7'

  -- --*************************************************************************************************************************************
-- JetSmart (JA) --Added on 12/18/2023 Subhrajit --Local Time

	If @Airline = 'JA'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- JA is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				--LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				CASE	WHEN CP.CP_SourceCd						<> 'ME'
						AND  LEN(IsNull(CP.CP_ArrAirline,''))	= 2
						THEN Left(IsNull(CP.CP_ArrAirline,''),2) +	-- Operating Airline
							 Left(TRIM(CP.CP_ArrFlightNum),4)		-- + Flight Number
						ELSE TRIM(CP.CP_ArrFlightNum)				-- Just Flight Number
				END AS 'ArrFlt',											-- Arrive Flight Number	
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- JA is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				--LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CASE	WHEN CP.CP_SourceCd						<> 'ME'
						AND  LEN(IsNull(CP.CP_DepAirline,''))	= 2
						THEN Left(IsNull(CP.CP_DepAirline,''),2) +	-- Operating Airline
							 Left(TRIM(CP.CP_DepFlightNum),4)		-- + Flight Number
						ELSE TRIM(CP.CP_DepFlightNum)				-- Just Flight Number
				END AS 'DepFlt',											-- Depart Flight Number	
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	>= 480
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',                                           --updated as per customer request Ram, 06_17_2024
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'JA'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'JA'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'JA'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'JA'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbJA.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'JA'
  -- end 'JA'
-- --*************************************************************************************************************************************
-- --*************************************************************************************************************************************
-- Sun country (SY) --Added on 02/022024 Ram --

	If @Airline = 'SY'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- SY is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- SY is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'SY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'SY'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'SY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'SY'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbSY.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'SY'
  -- end 'SY'
 -- --*************************************************************************************************************************************
-- NORSER (N0) --Added RAM ON 02/15/2024 --Local Time

	If @Airline = 'N0'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- N0 is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- N0 is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> 'N0'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= 'N0'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> 'N0'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= 'N0'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From dbN0.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- 'N0'
  -- end 'N0'
  -- --*************************************************************************************************************************************
-- --*************************************************************************************************************************************
-- ASL Airlines Belgium SA(3V) --Added on 24/10/2024 Mounika --

	If @Airline = '3V'
	Begin
			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'M' + CP_TripCd
					else CP_TripCd
				End as TripCd,
				case when @GMTFlg = 1	-- 3V is in local time
					then CP_ArrDtTm	      -- this is local time
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
				LTrim(IsNull(CP_ArrFlightNum, 'N/A')) as 'ArrFlt',
				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',
				case when @GMTFlg = 1	-- 3V is in local time
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',
				LTrim(IsNull(CP_DepFlightNum, 'N/A')) as 'DepFlt',
				CAST(isnull(CP_GroundTmi, isnull(L.L_GroundTmi,  0)) AS Varchar(10))		as 'GrndTime',
				case	when isnull(CP_LayoverInd, 1) = 1
						then 'Yes'
						when exists (select * from dbo.tblTravelTrips TT where T_TripDtTm			between	@StartDt and @EndDt
																			and T_EmpId				= @EmpId
																			and A_Symbol			= @Airline																					
																			and CP.CP_LayoverInd	<> 1
																			and T_TripCd			= 'SS'
																			and T_CancelResultCd	= 0
																			and T_ConfDtTm			is not null
																			and TT.CP_UID			= CP.CP_UID
/*
																			-- Some wiggle room for updates?
																			and ((CP.CP_ArrFlightNum = 'LIMO'
																			AND   CP.CP_ArrFltSeq	= 1
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_ArrFromDepDtTm)
																									and     dateadd(mi, 10, CP.CP_ArrFromDepDtTm))
																			or  (CP.CP_DepFlightNum	= 'LIMO'
																			and T_TripDtTm			between dateadd(mi, -10, CP.CP_DepDtTm)
																									and     dateadd(mi, 10, CP.CP_DepDtTm))
																		)
*/																		
																		)
							--
							-- Find Airport to Airport ground trips.
							--
						then 'Grd'
						WHEN CP.CP_GroundTmi	> 509
						AND	 CP.CP_DomicileInd	= 1
						THEN 'Dom'
						else ''
				end			as 'Layover',
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
				CP_HotCrew			as 'HotCrew',
				CASE	WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	<> '3V'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_ArrDeadhead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_ArrFlightNum, '')), 2)	= '3V'
						AND  LTrim(IsNull(CP_ArrFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_ArrFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'ArrDead',
				CASE	WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	<> '3V'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN 'COM'
						WHEN CP_DepDeadHead									= 'D' 
						AND	 Left(LTrim(IsNull(CP_DepFlightNum, '')), 2)	= '3V'
						AND	 LTrim(IsNull(CP_DepFlightNum, ''))				<> 'LIMO' 
						THEN CP_AirCustomer
						WHEN LTrim(IsNull(CP_DepFlightNum, ''))				= 'LIMO' 
						THEN 'GRD'
						ELSE NULL
				END		AS 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',
				isnull(CP.CP_PostedDtTm, getdate()) as 'Posted',
				CP_UpdateDtTm		as 'Updated',
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct max(I2.H_HotelKey) from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',
				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case --
					when CP.CP_ArrFltSeq = 1
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			case when CP.CP_SourceCd = 'ME'
					then CP.CP_PostedId
					else CP.CP_AssignCd
			end as Assign,

			CP.CP_Domicile,
			@Airline as Air

			From db3V.dbo.tblCityPair CP (nolock)
 			---
			---
	 		Left Join dbo.tblLayover          L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null   -- JB 8/29/18 ... If Layover is morphed, the old Layover UID stays on the Inventory record, AND is marked Cancelled!  Should mark it as Morphed??
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 --OR	L.L_UID		In (Select L_UID from dbo.tblOrder_arch (nolock) where L_UID = L.L_UID))
							 )
	
			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
										 OR  I.L_UID	 = X.L_UID)	

			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.
			

			Order by CP_ArrDtTm --DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!

	End -- '3V'
  -- end '3V'
-- --*************************************************************************************************************************************
-- --*************************************************************************************************************************************
	If @Airline in ('IE', 'XP', 'IC', 'IS', 'IF', 'ST', 'EC', 'DC', 'MD', 'CS', 'MS', 'G4', 'SQ', 'CB', 'LC')
	Begin

			Select 	Distinct
				CP_UID,
				case when CP_SourceCd = 'ME'
					then 'Manual'
					else CP_TripCd
				End as TripCd,

				case when @GMTFlg = 0
					then CP_ArrDtTm	      
					else case when CP_ArrDtTm is not null 
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)   -- this is GMT
							else L.L_ArrDtTm   -- this is local
					     end
				end			as 'ArrTime',
-- 
-- 				case when @GMTFlg = 0
-- 					then CP_ArrDtTm	      -- this is GMT time
-- 					else case when CP_ArrDtTm is not null 
-- 							then CP_ArrDtTm   -- this is local
-- 					     end
-- 				end			as 'ArrTime',

				CP_ArrFlightNum  as 'ArrFlt',

				isnull(CP_ArrFromStation, 'N/A')	as 'From',
				isnull(CP_Station, 'N/A')	as 'Sta',
				isnull(CP_DepToStation, 'N/A')	as 'To',

					case when @GMTFlg = 0
					then CP_DepDtTm							      -- this is local time
					else case when CP_DepDtTm is not null
							then DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_DepDtTm) * -1, CP_DepDtTm)   -- this is GMT
							else L.L_DepDtTm   -- this is local
					     end
				end			as 'DepTime',

				CP_DepFlightNum	as 'DepFlt',

				case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
				end +  

				case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) = 0
							then ''
							else right(rtrim(convert(char(5), isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440)), 2) + 'D ' 
						  end = ''
						then '   '
						else ''
				end +

				right(rtrim(case when case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60
									  else '0' 
						  end		  < 10
							then '0' + case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
										then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
										else '0' 
									   end
							else case when (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) >= 60 
									  then convert(char(2), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) / 60)
									  else '0' 
								 end
				end), 2)
				+ ':' +

				case when ((isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60) < 10
						then '0' + convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
						else convert(char(5), (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) - (isnull(L.L_GroundTmi, isnull(CP_GroundTmi, 0)) / 1440) * 1440) % 60)
				end
				
				as 'GrndTime',

				'Yes'as 'Layover',

--				case when isnull(CP_LayoverInd, 1) = 1
--					then 'Yes'
--					else ''
--				end			as 'Layover',
	
				CP_ArrTailNumber	as 'ArrTail',
				CP_DepTailNumber	as 'DepTail',
				CP_ArrEquipmentCd	as 'ArrEquip',
				CP_DepEquipmentCd	as 'DepEquip',
	
				CP_HotCrew		as 'HotCrew',
				case when CP_ArrDeadhead = 'C' then 'COM'
				     when CP_ArrDeadhead = 'G' then 'GRD'
				     when CP_ArrDeadhead = 'A' then CP_AirCustomer

							       else NULL
				end			as 'ArrDead',
	
				case when CP_DepDeadhead = 'C' then 'COM'

				     when CP_DepDeadhead = 'G' then 'GRD'
				     when CP_DepDeadhead = 'A' then CP_AirCustomer
							       else NULL
				end			as 'DepDead',
	
				isnull(CP_CrewPos, 'N/A')	as 'Pos',
	
				CP_BidPeriod 		as 'BidPeriod',
				CP_CostCenter		as 'CostCenter',

				isnull(CP.CP_PostedDtTm, getdate()) as Posted, 
				CP_UpdateDtTm		as 'Updated',
	
				C.CP_NameLast		as 'LastName',
				C.CP_NameFirst		as 'FirstName',
				isnull(I.H_HotelKey, (Select distinct I2.H_HotelKey from dbo.tblInv I2 (nolock)  
								Join dbo.tblInvHistory IH (nolock) On I2.I_UID = IH.I_UID
								Where IH.IH_Old_LUID = X.L_UID)) as 'HotelKey',

				isnull(X.L_UID, L.L_UID) as L_UID,	-- L.L_UID,
							
				CP_ArrDtTm,
				isnull(X.L_UID, 0)	as X_LUID,
				case when CP.CP_Domicile = CP.CP_ArrFromStation
				      and CP.CP_Domicile <> CP.CP_DepToStation
					then '*'
					else ''
				end as 'TripStart',
			CP_Op,
			CP_AssignCd as Assign,
			CP.CP_Domicile

			-- Note this in the the dbLMS3 db!!
			From dbo.tblCityPair CP (nolock)
			---
			---
	 		Left Join dbo.tblLayover   L 	(nolock) 
							 ON 	(L.DF_AISUID 	= CP.CP_UID
							 --AND 	L.L_CancelCd 	is null			--Commented on 4/22/2021 Subhrajit
							 AND 	L.A_Symbol 	= @Airline
							 AND 	L.L_EmpId	= @EmpId
							 AND	(L.L_UID	In (Select L_UID from dbo.tblInv (nolock) where L_UID = L.L_UID and I_CancelResultCd not in (1,3))	--Added on 1/28/2022 CREWREZ-1808
							 OR	L.L_UID		In (Select L_UID from dbo.tblOrder (nolock) where L_UID = L.L_UID and O_StateCd <> 'X'))
							 )




			Left Join dbo.tblCrewProfile C	(nolock) ON C.CP_EmpId = CP.CP_CrewId
							        and C.A_Symbol = CP.CP_AirCustomer

			---
			--- If the (-10/10) values change here...  also change in OpCode_Add() and OpCode_DropInv() too.
			---
			Left Join dbo.tblCrewXL	     X  (nolock) ON X.L_UID     in (Select distinct L_UID From dbo.tblCrewXL 
											Where CX_EmpId 	= @EmpId 
											  And A_Symbol 	= @Airline
											  And CX_ArrStaCd 	= CP.CP_Station
											  And CX_ArrDtTm	between 
														DateAdd(hh, -@Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)) 
														and DateAdd(hh, @Hrs, 
														dbo.uFN_GetLocalStaTime(CP.CP_Station, CP_ArrDtTm)))

			Left Join dbo.tblInv	     I  (nolock) ON (I.L_UID     = L.L_UID
													OR  I.L_UID	 = X.L_UID)	


			Where	CP_AirCustomer 	= @Airline
			And	CP_ArrDtTm			between @StartDt and @EndDt
			And	CP_CrewId			= @EmpId	
			And	CP_Op				not in (20, 40)	-- Not dropped or UnAssigned.

			--Order by DateAdd(mi, dbo.uFN_GetGMTOffset(CP.CP_Station, CP_ArrDtTm) * -1, CP_ArrDtTm)  -- CP_ArrDtTm  -- Needed to use GMT sort, not Local Arr !!
			order by 'ArrTime'
	End  -- end '****IE**** '



Completion time: 2025-06-06T00:47:11.6511685-04:00
