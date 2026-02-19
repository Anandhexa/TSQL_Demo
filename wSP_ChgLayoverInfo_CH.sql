Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




--********************************************************************************************************
-- Procedure To Change Layover Flight Info
-- Written By: JB
-- Last Modified: 8/11/2009
--
-- Description:	This updates records in the CityPair for each airline and marks the records to be sent to the LMS again.
--              This is intended to be used for MANUAL Layover records only!!  If data-feed, feed should change the data!
--

/**
select * from dbNA.dbo.tblCityPair where CP_UID = 508446

'6/8/2009 03:00', '6/8/09 20:31', '8C', 'bos', '1514', '1'
Declare @R int
exec @R = wSP_ChgLayoverInfo '5x', 14823219, '1234', '4537', '8/4/2009 03:00', '8/5/09 20:03', NULL, NULL, NULL, 'dep later', 0, 'jb'
select @R
select * from db8c.dbo.tblCityPair where CP_crewid = '1514'
select * update CP set CP_SentToLMS = '9/1/09'  from db8c.dbo.tblCityPair CP where CP_SentToLMS is null and CP_UID = 8321 where CP_UID = 8321
select * from dbLMS3.dbo.tblais_datafeed_arch where DF_AISUID = 8321

EXEC dbo.P_GetDataAIS 'NA'
select * from tblais_datafeed
exec dbo.P_LMSMain
Select top 401 * from tblMesg order by M_UID desc 
exec dbo.P_QueueMgt
**/
-- select * from LMS_FEED.dbo.tblLMSFeed LF where LF_ArrFlightDateTime > '8/1/09'
-- select * from LMS_FEED.dbo.tblLMSFeed LF where L_UID = 68330
-- select * from LMS_FEED.dbo.tblLMSFeed where L_UID = 7894958
-- select * from dbLMS3.dbo.tblais_datafeed_arch where DF_AISUID = 68330

--********************************************************************************************************
-- DROP PROC wSP_ChgLayoverInfo


CREATE     PROCEDURE [dbo].[wSP_ChgLayoverInfo_CH] (	 @Airline char(2),
										 @Old_LUID Int,
										 @New_ArrFltNum FlightNumb	= null,
										 @New_DepFltNum FlightNumb	= null,
										 @New_ArrDtTm datetime		= null,
										 @New_DepDtTm datetime		= null,
										 @New_EmpId char(12)		= null,
										 @New_CrewType char(3)		= null,
										 @New_CostCenter varchar(10)= null,
										 @Notes varchar(255)		= null,
										 @ForceFlg int				= 0,	-- 0 false, 1 true
										 @ByWho varchar(20)					-- Who entered the change?
) as
							 
Declare			@Now datetime,
				@NowDrop datetime,
				@RCnt	int
				
Declare			@RetVal int

				
Set @RCnt = -1
Set @NowDrop = dateadd(mi, -1, GETDATE())
Set	@Now = getdate()

declare			@F_ArrStat		VarChar(4),
				@F_DepStat		VarChar(4),
				@S_ArrCountryCd	char(3),
				@S_DepCountryCd	char(3),
				@L_ArrFltNum FlightNumb,
				@L_DepFltNum FlightNumb,
				@L_ArrDtTm FlightDtTm,
				@L_DepDtTm FlightDtTm,
				@A_Symbol char(2),
				@L_CostCenter char(10),
				@CP_Notes varchar(255),
				@CP_TripCd char(15),
				@CP_BidPeriod char(10),
				@CP_EmpId char(12),
				@CP_CrewPos char(4),
				@CP_NameFirst char(20),
				@CP_NameLast char(25),
				@CP_ArrDeadhead varchar(2),	-- 'D' deadhead, null not true
				@CP_DepDeadhead varchar(2), -- 'D' deadhead, null not true
				@CP_HotCrew varchar(2),		-- 'Y' true, 'N' not false
				@CP_Domicile char(4),
				@EnterByWho ByWho,
				@GMTFlag char(1),	-- 1 = GMT, 0 = Local
				@New_ArrDtTmArg datetime,
				@New_DepDtTmArg datetime,
				@CP_UID int
				


	Select 			@F_ArrStat				= L.L_ArrStaCd,
					@F_DepStat				= L.L_DepStaCd,
					@S_ArrCountryCd			= L.L_ArrFromCountry,
					@S_DepCountryCd			= L.L_DepToCountry,
					@L_ArrFltNum			= L.L_ArrFltNum,
					@L_DepFltNum			= L.L_DepFltNum,
					@L_ArrDtTm				= L.L_ArrDtTm,
					@L_DepDtTm				= L.L_DepDtTm,
					@A_Symbol				= L.A_Symbol,
					@L_CostCenter			= L.L_CostCenter,
					@CP_Notes				= @Notes,
					@CP_TripCd				= L.L_TripCd,
					@CP_BidPeriod			= convert(char(4), L.L_ArrDtTm, 112) + convert(char(2), L.L_ArrDtTm, 101),
					@CP_EmpId				= L.L_EmpId,
					@CP_CrewPos				= L.L_CrewType,
					@CP_NameFirst			= null,
					@CP_NameLast			= null,
					@CP_ArrDeadhead			= L.L_ArrDeadHeadInd,
					@CP_DepDeadhead			= L.L_DepDeadHeadInd,
					@CP_HotCrew				= L.L_HotCrewCd,
					@CP_Domicile			= L.L_DomicileSta,
					@EnterByWho				= @ByWho,
					@GMTFlag				= null,					-- This should always be local
					@CP_UID					= L.DF_AISUID
					
	From dbo.tblLayover L	(nolock)
	-- Modified JOIN 6/1/2023 - Include Orders
	Join (SELECT I.A_Symbol, I.L_UID
			FROM dbo.tblInv		I	(NOLOCK)
			WHERE I.I_CancelResultCd	<= 0	-- Don't want to update something already canceled (I think)
			GROUP BY I.A_Symbol, I.L_UID
			UNION
		  SELECT O.A_Symbol, O.L_UID
			FROM dbo.tblOrder		O	(NOLOCK)
			WHERE O.O_StatusCd	<> 'X'			-- If order already X'd our don't allow to be modified (I think)
			GROUP BY O.A_Symbol, O.L_UID
			) AS I		ON  L.A_Symbol	= I.A_Symbol
						AND L.L_UID		= I.L_UID

	Where	L.L_UID		= @OLD_LUID
	And		L.A_Symbol	= @Airline
	--Join dbo.tblInv		I	(nolock)	ON L.L_UID	= I.L_UID

	--Where	I.L_UID		= @OLD_LUID
	--And		I.A_Symbol	= @Airline



	If @ForceFlg = 0	-- IF = 1, then don't check overlap, just do it
	Begin
	
		Select @New_ArrDtTmArg = ISNULL(@New_ArrDtTm, @L_ArrDtTm)
		Select @New_DepDtTmArg = ISNULL(@New_DepDtTm, @L_DepDtTm)
		Select @New_EmpId = ISNULL(@New_EmpId, @CP_EmpId)
				---
		--- Find out if anything overlaps with this change
		---
		--exec @RetVal = wSP_CheckLayoverExists_DN @New_ArrDtTmArg, @New_DepDtTmArg, @Airline, @F_ArrStat, @New_EmpId, '0', @Old_LUID   --@GMTFlag=0 is local
		exec @RetVal = wSP_CheckLayoverExists_CH @New_ArrDtTmArg, @New_DepDtTmArg, @Airline, @F_ArrStat, @New_EmpId, '1', @Old_LUID   --@GMTFlag=1 is local  --Changed @GMTFlag To 1 - 1/27/2022 CREWREZ-1783


		If @RetVal = 1	-- Found overlap, so quit.
		Begin
			Set @RCnt = -2
			GoTo ExitProc
		End
	End


	If @CP_UID is null
		GoTo ExitProc
		

	-- Debug
/****
	Select 	@CP_UID,			@F_ArrStat,			@F_DepStat,			@S_ArrCountryCd,			@S_DepCountryCd	,			@L_ArrFltNum,
			@L_DepFltNum,			@L_ArrDtTm	,			@L_DepDtTm	,			@A_Symbol	,			@L_CostCenter,			@CP_Notes	,
			@CP_TripCd	,			@CP_BidPeriod,			@CP_EmpId	,			@CP_CrewPos	,			@CP_NameFirst,			@CP_NameLast,
			@CP_ArrDeadhead,			@CP_DepDeadhead	,			@CP_HotCrew	,			@CP_Domicile,			@EnterByWho	,			@GMTFlag	,
			@CP_UID	,						@New_ArrFltNum,			@New_DepFltNum,			@New_ArrDtTm,			@New_DepDtTm,
			@New_EmpId,			@New_CostCenter,			@New_CrewType
****/	 
		  
	-- 
	-- For records in the LMSFEED db, we need to create drop record (since a change does not exist).  Then Update old after the 'Drop'.
	--
	If @A_Symbol in ('5X', '6X') 
	Begin
	 		
	 			Insert into LMS_FEED.dbo.tblLMSFeed (
		 		
						--	[SLF_UID] [int] IDENTITY(1645607,1) NOT NULL,
							[LF_UID],			[B_UID],			[L_UID],			[H_HotelKey],			[A_Symbol],
							[L_CrewID],			[LF_ActionCode],	[LF_ArrFlightNum],	[LF_ArrFlightStation],	[LF_TZOffset],
							[LF_ArrFlightDateTime],					[LF_ArrEquipCode],	[LF_DepFlightNum],		[LF_DepFlightStation],
							[LF_DepFlightDateTime],					[LF_DepEquipCode],	[LF_HotelStation],		[LF_Quantity],
							[LF_GroundTime],	[LF_CostCenter],	[LF_CrewType],		[LF_DeadHead],			[LF_HotCrew],
							[LF_DayRoom],		[LF_Unassigned],	[LF_ExportToLMS],	[LF_ManualEntry],		[LF_ManualRead],
							[LF_CreateDate],	[LF_AddDate],		[LF_UpdateDate],	[LF_AddID],				[LF_UpdateID],
							[LF_Comments]					
					)
				Select
							[LF_UID],			[B_UID],			[L_UID],			[H_HotelKey],			[A_Symbol],
							[L_CrewID],			
							'DR',				--[LF_ActionCode],
							[LF_ArrFlightNum],	[LF_ArrFlightStation],					[LF_TZOffset],			[LF_ArrFlightDateTime],	
							[LF_ArrEquipCode],	[LF_DepFlightNum],						[LF_DepFlightStation],	[LF_DepFlightDateTime],	
							[LF_DepEquipCode],	[LF_HotelStation],	[LF_Quantity],		[LF_GroundTime],		[LF_CostCenter],
							[LF_CrewType],		[LF_DeadHead],		[LF_HotCrew],		[LF_DayRoom],			[LF_Unassigned],
							null,				--[LF_ExportToLMS],
							[LF_ManualEntry],	[LF_ManualRead],	[LF_CreateDate],
							@NowDrop,				--[LF_AddDate],
							[LF_UpdateDate],
							@ByWho,				--[LF_AddID],
							[LF_UpdateID],
							'WebUpdD' + ISNULL(@Notes, '')	--[LF_Comments]
							
				From LMS_FEED.dbo.tblLMSFeed
				Where L_UID			= @CP_UID
				And LF_ActionCode	= 'AD'

				-- 
				-- Now update the old record with new INFO.
				--
				Update	LF
				Set  LF_ArrFlightNum		= isnull(@New_ArrFltNum, LF_ArrFlightNum), 
											-- Need to convert to GMT time!
					 LF_ArrFlightDateTime	= case when @New_ArrDtTm is not null
														then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (LF_ArrFlightStation, @New_ArrDtTm)), @New_ArrDtTm)
														else LF_ArrFlightDateTime
											  end,
					 LF_DepFlightNum		= isnull(@New_DepFltNum, LF_DepFlightNum),
					 LF_DepFlightDateTime	= case when @New_DepDtTm is not null
														then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (LF_DepFlightStation, @New_DepDtTm)), @New_DepDtTm)
														else LF_DepFlightDateTime
											  end,

	 				 LF_GroundTime			= DateDiff(mi, 
 				 							  (case when @New_ArrDtTm is not null
														then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (LF_ArrFlightStation, @New_ArrDtTm)), @New_ArrDtTm)
														else LF_ArrFlightDateTime
											   end),
											  (case when @New_DepDtTm is not null
														then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (LF_DepFlightStation, @New_DepDtTm)), @New_DepDtTm)
														else LF_DepFlightDateTime
											   end)),


					 L_CrewId				= isnull(@New_EmpId,	 L_CrewId), 	
					 LF_CrewType			= isnull(@New_CrewType,	 LF_CrewType),	
					 LF_Comments			= case when substring(LF_Comments, 1,7) = 'WebUpdA:'
													then case when @Notes is null
																then LF_Comments		-- Don't chg anything
																else 'WebUpdA:' + @Notes
														 end
													else 'WebUpdA:' + isnull(@Notes, LF_Comments) 		
											  end,
					 LF_AddDate				= @Now,		-- This will allow the same CP_UID twice (Key is CP_UID + CP_AddDate)
					 LF_UpdateDate			= @Now, 
					 LF_UpdateID			= @ByWho, 	
					 LF_CostCenter			= isnull(@New_CostCenter, LF_CostCenter),
					 LF_ExportToLMS			= null	-- So it is transmitted again
											 
				From LMS_FEED.dbo.tblLMSFeed LF
				Where L_UID			= @CP_UID
				And LF_ActionCode	= 'AD'	-- Should only be one (1) 'AD' record

				Set @RCnt = @@ROWCOUNT
					
		
		
				
		-- ------------------------------------------------------------------------------------------------------------------------
		-- ------------------------------------------------------------------------------------------------------------------------
		-- ------------------------------------------------------------------------------------------------------------------------
		-- Debug
--/***
					Select 
						 @CP_UID as CP_UID, 
						 isnull(@New_ArrFltNum, LF_ArrFlightNum) as ArrFltNum, 
						 -- Need to convert to GMT time!
						 case when @New_ArrDtTm is not null
								then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (LF_ArrFlightStation, @New_ArrDtTm)), @New_ArrDtTm)
								else LF_ArrFlightDateTime
						 end as ArrDtTm,
						 LF_ArrFlightDateTime,
						 isnull(@New_DepFltNum, LF_DepFlightNum) as DepFltNum,
						 -- Need to convert to GMT time!
						 case when @New_DepDtTm is not null
								then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (LF_DepFlightStation, @New_DepDtTm)), @New_DepDtTm)
								else LF_DepFlightDateTime
						 end as DepDtTm,
						 LF_DepFlightDateTime,
						 isnull(@New_EmpId,	 L_CrewId) as CrewId, 
						 @CP_EmpId,	
						 isnull(@New_CrewType,	 LF_CrewType) as CrewType,	
						 LF_CrewType,
						 isnull(@Notes, LF_Comments) as Comments, 		
						 @Now,		-- This will allow the same CP_UID twice (Key is CP_UID + CP_AddDate)
						 @Now, 
						 @ByWho, 	
						 isnull(@New_CostCenter, LF_CostCenter) as CostCenter
																	 
					From LMS_FEED.dbo.tblLMSFeed LF
					Where L_UID	= @CP_UID
--***/				
	End


	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	If @A_Symbol in ('NA') Begin


					Select 
						 @CP_UID as CP_UID, 
						 isnull(@New_ArrFltNum, CP_ArrFlightNum) as ArrFltNum, 
						 -- Need to convert to GMT time!
						 case when @New_ArrDtTm is not null
								then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
								else CP_ArrDtTm
						 end as ArrDtTm,
						 CP_ArrDtTm,
						 isnull(@New_DepFltNum, CP_DepFlightNum) as DepFltNum,
						 -- Need to convert to GMT time!
						 case when @New_DepDtTm is not null
								then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
								else CP_DepDtTm
						 end as DepDtTm,
						 CP_DepDtTm,
						 
 						 DateDiff(mi, 
 							 (case when @New_ArrDtTm is not null
									then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
									else CP_ArrDtTm
							 end),
							 (case when @New_DepDtTm is not null
									then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
									else CP_DepDtTm
							 end)),
						 isnull(@New_EmpId,	 CP_CrewId) as CrewId, 	
						 CP_CrewId,
						 isnull(@New_CrewType,	 CP_CrewPos) as CrewType,	
						 CP_CrewPos,
						 CP_Notes	= case when substring(CP_Notes, 1,7) = 'WebUpd:'
											then isnull(@Notes, CP_Notes)
											else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
									  end,
						 @Now,		-- This will allow the same CP_UID twice (Key is CP_UID + CP_AddDate)
						 @Now, 
						 @ByWho, 	
						 isnull(@New_CostCenter, CP_CostCenter) as CostCenter
																	 
					From dbNA.dbo.tblCityPair CP
					Where CP_UID	= @CP_UID



			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
										   						 
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,

				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit		
			*/		
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783	 
			From dbNA.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID

			Set @RCnt = @@ROWCOUNT

	End


	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------


	--If @A_Symbol in ('RD') Begin
	--		-- 
	--		-- Now update the old record with new INFO.
	--		--
	--		Update	CP
	--		Set  CP_Op					= case when CP_CrewID <> @New_EmpId
	--												then 51
	--												else 30
	--									  end,
	--			 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
	--									-- Need to convert to GMT time!
	--			 CP_ArrDtTm				= case when @New_ArrDtTm is not null
	--												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
	--												else CP_ArrDtTm
	--									  end,
	--			 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
	--			 CP_DepDtTm				= case when @New_DepDtTm is not null
	--												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
	--												else CP_DepDtTm
	--									  end,
 --				 CP_GroundTmi			= DateDiff(mi, 
 --				 						  (case when @New_ArrDtTm is not null
	--												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
	--												else CP_ArrDtTm
	--									   end),
	--									  (case when @New_DepDtTm is not null
	--												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
	--												else CP_DepDtTm
	--									   end)),

	--			 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
	--									-- this is normally empty for Manual Layover records - so put something in there!
	--			 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
	--												then CP_CrewId
	--												else CP_PrevCrewId
	--									  end,

	--			 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
	--			 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
	--												then case when @Notes is null
	--															then CP_Notes		-- Don't chg anything
	--															else 'WebUpd:' + @Notes
	--													 end
	--												else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
	--									  end,
	--			 CP_UpdateDtTm			= @Now, 
	--			 CP_UpdateID			= @ByWho, 	
	--			 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
	--			 CP_SentToLMS			= null	-- So it is transmitted again
										 
	--		From dbRD.dbo.tblCityPair CP
	--		Where CP_UID			= @CP_UID

	--End


	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------


	If @A_Symbol in ('8C') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 

				 --************ Jira 1516 - Update For Local Times In tblCityPair ************
										-- Need to convert to GMT time!
				 --CP_ArrDtTm				= case when @New_ArrDtTm is not null
					--								then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
					--								else CP_ArrDtTm
					--					  end,
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,

				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),

				 --CP_DepDtTm				= case when @New_DepDtTm is not null
					--								then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
					--								else CP_DepDtTm
					--					  end,
				CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,

 				 --CP_GroundTmi			= DateDiff(mi, 
 				 --						  (case when @New_ArrDtTm is not null
						--							then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
						--							else CP_ArrDtTm
						--				   end),
											--(case when @New_DepDtTm is not null
											--		then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
											--		else CP_DepDtTm
										 --  end)),

 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
										 
			From db8C.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End


	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------


	If @A_Symbol in ('ZW') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
										 
			From dbZW.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End


	If @A_Symbol in ('PT') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				CP_ArrDutyDtTm			= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDutyDtTm
										  end,	
				CP_DepDutyDtTm			= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDutyDtTm
										  end
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbPT.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End
	
	

	--- GMT
	If @A_Symbol in ('OH') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)) 
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbOH.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End
	
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------


	If @A_Symbol in ('XJ') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbXJ.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End

--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('JL') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
		/*		 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
		*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbJL.dbo.tblCityPair CP     -- 
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End
	
	


--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('Y4') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbY4.dbo.tblCityPair CP     -- Updated from 'PT' to 'Y4' on 6/26/18 JB
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End


--****************************************************************************************************************************************
-- GMT time 

	If @A_Symbol in ('HA') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbHA.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- HA


	

--****************************************************************************************************************************************
-- GMT time 

	If @A_Symbol in ('NK') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbNK.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- NK



--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('TR') Begin
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbTR.dbo.tblCityPair CP   
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End


--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('CP') Begin
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbCP.dbo.tblCityPair CP   
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End -- CP


--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('AX') Begin
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbAX.dbo.tblCityPair CP   
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End


--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('G7') Begin
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbG7.dbo.tblCityPair CP   
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End -- G7





--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('4O') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From db4O.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- 4O
	
--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('C5') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbC5.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID

			Set @RCnt = @@ROWCOUNT

	End	-- C5
	
--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('U2') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbU2.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- U2



--****************************************************************************************************************************************
-- Local time 

	If @A_Symbol in ('WQ') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbWQ.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- WQ


--****************************************************************************************************************************************
-- Local time 

	If @A_Symbol in ('EY') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbEY.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- EY


--****************************************************************************************************************************************
-- Local time 

	If @A_Symbol in ('OY') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbOY.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- OY






--****************************************************************************************************************************************
-- GMT time 

	If @A_Symbol in ('YX') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbYX.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- YX

	--****************************************************************************************************************************************
-- Local time 

	If @A_Symbol in ('LO') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbLO.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- LO

--****************************************************************************************************************************************
-- Western Global Airlines (KD)
-- Local time 

	If @A_Symbol in ('KD') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbKD.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- KD

	--****************************************************************************************************************************************
-- Eastern Airlines (2D)
-- Local time 

	If @A_Symbol in ('2D') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From db2D.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- 2D

	
--********************************************************************************************************************************************************
--START Air Arabia
--****************************************************************************************************************************************
-- Air Arabia (G9)
-- GMT time 

	If @A_Symbol in ('G9') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case	when CP_CrewID <> @New_EmpId
												then 51
												else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
/*				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
*/				 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null	--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
/*				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 */
				 CP_DepDtTm				= case when @New_DepDtTm is not null	--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 /*				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
*/
 				 --Added on 10/08/2021 Subhrajit
				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)		
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbG9.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- G9
	
--********************************************************************************************************************************************************
--****************************************************************************************************************************************
-- Air Arabia Egypt (E5)
-- GMT time 

	If @A_Symbol in ('E5') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case	when CP_CrewID <> @New_EmpId
												then 51
												else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
/*				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
*/
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null		--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
/*				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
*/
				 CP_DepDtTm				= case when @New_DepDtTm is not null		--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
/* 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
*/
 				 --Added on 10/08/2021 Subhrajit
				 CP_GroundTmi			= DateDiff(mi,	
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)		
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbE5.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- E5
	
--********************************************************************************************************************************************************
--****************************************************************************************************************************************
-- Air Arabia Maroc (3O)
-- GMT time 

	If @A_Symbol in ('3O') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case	when CP_CrewID <> @New_EmpId
												then 51
												else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
/*				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
*/
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null		--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
/*				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
*/
				 CP_DepDtTm				= case when @New_DepDtTm is not null		--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
/* 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
*/
 				 --Added on 10/08/2021 Subhrajit
				 CP_GroundTmi			= DateDiff(mi,		
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From db3O.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- 3O
	
--********************************************************************************************************************************************************
--****************************************************************************************************************************************
-- Air Arabia Abu Dhabi (3L)
-- GMT time 

	If @A_Symbol in ('3L') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case	when CP_CrewID <> @New_EmpId
												then 51
												else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
/*				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
*/
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null		--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
/*				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
*/
				 CP_DepDtTm				= case when @New_DepDtTm is not null		--Added on 10/08/2021 Subhrajit
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
/* 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
*/
 				 --Added on 10/08/2021 Subhrajit
				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))	--Changed to GMT
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))	--Changed to GMT
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From db3L.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- 3L
	
--********************************************************************************************************************************************************
-- END Air Arabia
--********************************************************************************************************************************************************


-- Vueling Airline --Added on 9/14/2021 Subhrajit --Local time 

	If @A_Symbol in ('VY') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
										 
			From dbVY.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End


	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

-- European cargo --Added on 9/30/2021 Subhrajit --Local time 

	If @A_Symbol in ('SE') Begin	--Replaced PS with on 4/7/2022 Subhrajit
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
										 
			From dbSE.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- Wizz Air --Added on 2/18/2022 Subhrajit --Local time 

	If @A_Symbol in ('W6') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
										 
			From dbW6.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END W6

	-- JetSuiteX 

	If @A_Symbol in ('XE') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
										 
			From dbXE.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END XE

		-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- ASL Airlines France --Added on 5/9/2022 Subhrajit --Local time 

	If @A_Symbol in ('5O') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
			From db5O.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END 5O

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- Frontier Airlines --Added on 9/15/2022 Subhrajit --GMT time 

	If @A_Symbol in ('F9') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit --Changed to GMT Subhrajit 10/08/2021
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)	--Changed to GMT
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
												then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)	--Changed to GMT
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm))),DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)) 
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))), DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm))
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbF9.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End --F9

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- LynxAir --Added on 1/31/2023 Subhrajit --Local time 

	If @A_Symbol in ('Y9') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
			From dbY9.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END Y9

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- Volotea Airlines --Added on 7/4/2023 Subhrajit --Local time 

	If @A_Symbol in ('V7') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
			From dbV7.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END V7

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- JetSmart --Added on 12/15/2023 Subhrajit --Local time 

	If @A_Symbol in ('JA') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
			From dbJA.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END JA

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- Sun Country --Added on 02/02/2024 Ram --Local time 

	If @A_Symbol in ('SY') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
			From dbSY.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END SY
	
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	-- NORSE --Added RAM

	If @A_Symbol in ('N0') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm
													else CP_DepDtTm
										   end)),
				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,
				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
			From dbN0.dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End	-- END N0
--****************************************************************************************************************************************
-- Local time !!
--
	If @A_Symbol in ('JQ') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- DO NOT Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then @New_ArrDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then @New_DepDtTm  --dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
		/*		 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
		*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			From dbJQ.dbo.tblCityPair CP     -- 
			Where CP_UID			= @CP_UID
			
			Set @RCnt = @@ROWCOUNT
			
	End

	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------------

	If @A_Symbol in ('IE', 'XP', 'IC', 'IS', 'IF', 'ST', 'EC', 'DC', 'MD', 'CS', 'MS', 'G4', 'SQ', 'CB', 'LC') Begin
	
			-- 
			-- Now update the old record with new INFO.
			--
			Update	CP
			Set  CP_Op					= case when CP_CrewID <> @New_EmpId
													then 51
													else 30
										  end,
				 CP_ArrFlightNum		= isnull(@New_ArrFltNum, CP_ArrFlightNum), 
										-- Need to convert to GMT time!
				 CP_ArrDtTm				= case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										  end,
				 CP_DepFlightNum		= isnull(@New_DepFltNum, CP_DepFlightNum),
				 CP_DepDtTm				= case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										  end,
 				 CP_GroundTmi			= DateDiff(mi, 
 				 						  (case when @New_ArrDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_ArrDtTm)), @New_ArrDtTm)
													else CP_ArrDtTm
										   end),
										  (case when @New_DepDtTm is not null
													then dateadd(mi, -(dbLMS3.dbo.uFN_GetGMTOffset (CP_Station, @New_DepDtTm)), @New_DepDtTm)
													else CP_DepDtTm
										   end)),

				 CP_CrewId				= isnull(@New_EmpId,	 CP_CrewId), 	
										-- this is normally empty for Manual Layover records - so put something in there!
				 CP_PrevCrewId			= case when CP_CrewID <> @New_EmpId
													then CP_CrewId
													else CP_PrevCrewId
										  end,

				 CP_CrewPos				= isnull(@New_CrewType,	 CP_CrewPos),	
				 CP_Notes				= case when substring(CP_Notes, 1,7) = 'WebUpd:'
													then case when @Notes is null
																then CP_Notes		-- Don't chg anything
																else 'WebUpd:' + @Notes
														 end
													else 'WebUpd:' + isnull(@Notes, CP_Notes) 		
										  end,
				 CP_UpdateDtTm			= @Now, 
				 CP_UpdateID			= @ByWho, 	
				 CP_CostCenter			= isnull(@New_CostCenter, CP_CostCenter),
				 CP_SentToLMS			= null,	-- So it is transmitted again
			/*	 --Added on 4/21/2021 Start Subhrajit
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL THEN @New_ArrDtTm	
												ELSE CP_ArrDutyDtTm
												END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL THEN @New_DepDtTm	
												ELSE CP_DepDutyDtTm END
				 --Added on 4/21/2021 End Subhrajit
			*/
				 --Added on 1/27/2022 Start CREWREZ-1783
				 CP_ArrDutyDtTm			= CASE	WHEN @New_ArrDtTm IS NOT NULL 
												THEN DateAdd(MI, DateDiff(MI, CP_ArrDtTm, CP_ArrDutyDtTm), @New_ArrDtTm)
	 											ELSE CP_ArrDutyDtTm
	 										END,
				 CP_DepDutyDtTm			= CASE	WHEN @New_DepDtTm IS NOT NULL 
	 						  					THEN DateAdd(MI, DateDiff(MI, CP_DepDtTm, CP_DepDutyDtTm), @New_DepDtTm)
							  					ELSE CP_DepDutyDtTm
							  				END
				 --Added on 1/27/2022 End  CREWREZ-1783
			-- dbLMS3							 
			From dbo.tblCityPair CP
			Where CP_UID			= @CP_UID
			And	CP_AirCustomer		= @Airline
			
			Set @RCnt = @@ROWCOUNT
			
	End


ExitProc:

--select @RCnt as RCnt, @CP_UID


	If @RCnt > 0 
		RETURN 0	-- Success
		
	If @RCnt = 0
		RETURN 1	-- Failed to create updated Layover
		
	If @RCnt = -1 
		RETURN 2	-- Didn't find CP_UID 
		
	If @RCnt = -2	
	Begin
		SELECT 'There is an overlapping layover for EmployeeID ' + TRIM(@New_EmpId) + '. Hence the name change is not applied.'	--Added on 6/24/2024 Subhrajit LOD-19637
		RETURN 3	-- Overlap was found
	End
	Else 
	Begin
		Return 100	-- Error return code unknown
	End


Completion time: 2025-06-06T00:54:09.0419775-04:00
