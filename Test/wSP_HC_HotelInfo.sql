Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



/*
	exec wSP_HC_HotelInfo @CrewId=N'13323',@Airline=N'HA',@StationCd=N'LAX', @L_UID= 63733164, @HotelKey= 1937, @CP_UID= 1392456

	exec wSP_Hotel_DN @CrewId=N'762949',@Airline=N'JL',@StationCd=N'SFO',@L_UID=37635530,@HotelKey=0,@CP_UID=241608

		exec wSP_Hotel_DN_ANI @CrewId=N'22222',@Airline=N'JL',@StationCd=N'ITM',@L_UID=37610044,@HotelKey=4696,@CP_UID=240528

		exec wSP_Hotel_DN_ANI @CrewId=N'57899',@Airline=N'JL',@StationCd=N'KIX',@L_UID=37626607,@HotelKey=4696,@CP_UID=294380


	*/

CREATE      PROC	[dbo].[wSP_HC_HotelInfo] 	
	@StationCd 	VARCHAR(4), 
	@Airline 	VARCHAR(2), 
	@CrewID 	VARCHAR(12), 
	@L_UID		INT,
	@HotelKey	INT = NULL,
	@CP_UID		INT = NULL
AS
BEGIN

--***************************************************************************************************
-- Procedure To Return Layover Details To Crew Schedule Web Page
-- WRITTEN BY: Steve
-- Last Update: 10/22/2003
-- Updated Again by Steve R 8/26/2008
-- SELECT  *
-- FROM	dbo.tblLayover 
-- WHERE	L_EmpID 	= '262'
-- AND	A_Symbol 	= '5X'
/*
EXEC dbo.wSP_HotelInfo @CrewId = '1996', @Airline = '8C', @StationCd = 'PHX', @L_UID = null, @HotelKey=0, @CP_UID=129401
EXEC dbo.wSP_Hotel_SR_TEST @CrewId = '9156', @Airline = 'NA', @StationCd = 'LGA', @L_UID = 30170
EXEC dbo.wSP_HC_HotelInfo @CrewId = '900032940', @Airline = 'fx', @StationCd = 'icn', @L_UID = 1477, @HotelKey=10427, @CP_UID=861

exec wSP_HC_HotelInfo @CrewId=N'13323',@Airline=N'HA',@StationCd=N'LAX', @L_UID= 63733164, @HotelKey= 1937, @CP_UID= 1392456

select * from dbLMS3.dbo.tblLayover where DF_AISUID = 29758 and a_symbol = 'na'
select * from dbLMS3.dbo.tblAis_datafeed_archnoop (nolock) where DF_AISUID = 29758 and df_a_symbol = 'na' and df_posteddttm > '3/1/08'
select * from dbLMS3.dbo.tblAis_datafeed_arch where DF_crewid = '9156' and df_a_symbol = 'na' and df_posteddttm > '2/1/08' and df_stationCd = 'lga'
select * from tblInv where L_UID = 15003544
select * from tblLayover where L_UID = 15003544
select count(*) from tblAis_datafeed (nolock)
*/
--***************************************************************************************************
-- Declare And Initialize Variables

	DECLARE	@LUID				Int,
			@RezId				Int, --Added on 08/05/2024 LOD-23619
			@RoomTypeCd			char(1), --Added on 10/18/2024 LOD-27826
			@H_HotelKey			Int,
			@HC_Key				Int,
			@L_ArrDtTm			DateTime,
			@StatFlg			VarChar(55),
			@H_Namefull			VarChar(60),
			@H_MainPhoneNumb	VarChar(20),
			@H_Faxnumb1			VarChar(20),
			@H_Contact1			VarChar(255),
			@H_StreetAddr1		VarChar(40),
			@H_StateProvince	VarChar(5),             
			@H_City				VarChar(30),
			@HC_VanServiceCd_Arrival	VarChar(80), --Added on 07/20/2020 Ani
			@HC_VanServiceCd_Departure	VarChar(80), --Added on 07/20/2020 Ani
			@S_ForeignInd		VarChar(1),
			@MMsg 				VarChar(200),
			@ReleaseDtTm		DAteTime,
			@ArrDtTm			datetime,
			@ReportDtTm			DAteTime,
			@DepDtTm			DateTime,
			@ArrDtTm_NoOp		datetime,
			@NiteCnt			int,
			@CancelBy			VarChar(60),
			@PickUp_Arrival		DateTime,--Added on 07/20/2020 Ani
			@Dropoff_Arrival	DateTime,--Added on 07/20/2020 Ani
			@PickUp_Departure	DateTime,--Added on 07/20/2020 Ani
			@Dropoff_Departure	DateTime,--Added on 07/20/2020 Ani	
			@CheckIN			DateTime,
			@CheckOut			DateTime,
			@EnteredByWho		varchar(30),
			@SourceCd			char(2),
			@CFNumb				varchar(20),
			@ExtKey				int,
			@Posted				datetime,
			@RCount				int,
			@Comment			varchar(300),
			@FoundBy			VarChar(20),
			@GroundVendor_Arrival		varchar(60), --Added on 07/20/2020 Ani
			@GroundVendor_Departure		varchar(60), --Added on 07/20/2020 Ani
			@HotelVan_Start		DateTime,
			@HotelVan_End		DateTime,
			@HotelVan_Start_D	DateTime,
			@HotelVan_End_D		DateTime,
			@ClearCustArrInd    char(1),
			@ClearCustDepInd    char(1),
			@UpdatedLastDtTm_Departure    DateTime,	-- Added 2/8/2023 LOD-936
			@UpdatedLastDtTm__Arrival     DateTime,	-- Added 2/8/2023 LOD-936
  @HotelUpdatedLastDtTm		DateTime,	-- Added 2/8/2023 LOD-936
			@PickUp_Arrival_Location	VarChar(20), -- Added 8/6/2024 LOD-21734
			@Dropoff_Departure_Location	VarChar(20)  -- Added 8/6/2024 LOD-21734

	SET	@H_NameFull 		= NULL
	SET	@H_City 			= NULL
	SET	@H_MainPhoneNumb 	= NULL
	SET	@H_Contact1 		= NULL
	SET	@H_FaxNumb1 		= NULL
	SET	@H_StreetAddr1		= NULL
	SET	@H_StateProvince	= NULL
	SET	@HC_VanServiceCd_Arrival	= NULL --Added on 07/20/2020 Ani
	SET	@HC_VanServiceCd_Departure	= NULL --Added on 07/20/2020 Ani
	SET	@LUID				= NULL
	SET @GroundVendor_Arrival		= NULL --Added on 07/20/2020 Ani
	SET @GroundVendor_Departure		= NULL --Added on 07/20/2020 Ani
	SET @FoundBy			= NULL
	SET @NiteCnt			= 0
	SET @HC_Key				= 0
	SET @ClearCustArrInd	= 'N'
	SET @ClearCustDepInd	= 'N'
	SET @RezId				=NULL  --Added on 08/05/2024 LOD-23619
	SET @RoomTypeCd			=NULL  --Added on 10/18/2024 LOD-27826
-- problems if sent using wrong hotel? JB 10/5/2009	
--Set @HotelKey = null


--Declare @Text varchar(100)
--Select @Text = @StationCd + ' ' + @Airline + ' ' + @CrewID + ' ' + CONVERT(CHAR(12), @L_UID) + ' ' + CONVERT(char(6), @HotelKey) + ' ' + CONVERT(char(12), @CP_UID)	
--exec U_Debug 'xx', @Text, 1, 'test', null, NULL, NULL, NULL, NULL


--***************************************************************************************************
-- Check For Valid Station, Get Foreign Code
    
	IF	(IsNull(@StationCd,'') = '')
	BEGIN
		SELECT	@StatFlg = 'No Station Specified' 
		GOTO	ReturnInfo
	END 
       
    If @HotelKey = 0
		Set @HotelKey = null   
       
    SELECT	@ArrDtTm			= L.L_ArrDtTm,
			@ClearCustArrInd	= IsNull(L.L_ClearCustArrInd, 'N'),	-- Added Steve 6/6/2018
			@ClearCustDepInd	= IsNull(L.L_ClearCustDepInd, 'N')	-- Added Steve 6/6/2018

    FROM	dbo.tblLayover as	L	(NOLOCK)
	Join	dbo.tblInv	   as   I   (NOLOCK) ON L.L_UID = I.L_UID

    WHERE	(L.L_UID		= @L_UID or L.DF_AISUID = @CP_UID)
    
--***************************************************************************************************
-- 
	IF NOT EXISTS (SELECT * FROM dbo.tblInactiveStations where S_StationCd = @StationCd 
														and A_Symbol = @Airline
														and isnull(IS_StartUPDt, '1/1/2050') > isnull(@ArrDtTm, '1/1/2010'))
	BEGIN

		SELECT  @LUID 			= L.L_UID,	
					@ReleaseDtTm	= IsNull(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
					@ArrDtTm		= L.L_ArrDtTm,
					@ReportDtTm		=IsNull(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
					@DepDtTm		= L.L_DepDtTm,
					@FoundBy		= 'tblOrder'

	        FROM	dbo.tblLayover as	L	(NOLOCK)
			Join	dbo.tblOrder   as   O  (NOLOCK) ON L.L_UID = O.L_UID
		
	        WHERE	(L.L_UID			= @L_UID  or L.DF_AISUID = @CP_UID)
	        --AND		L.L_EmpID 	= @CrewID	-- Removed 6/6/2018 Steve
	        AND		L.A_Symbol 		= @Airline
			AND		L.L_ArrStaCd	= @StationCd   -- New JB 6/25/08
			AND		O.H_HotelKey	 = CASE WHEN ISNULL(@HotelKey, 0) = 0 THEN O.H_HotelKey
									   ELSE @HotelKey
									    END	-- NEW JB 9/2/09
            AND		O.O_OrderType	IN (100, 110)	-- 01/11/2023 Only Adds/Increase - CREWREZ-2010
		Set @RCount = @@ROWCOUNT
		

		--Then check the inventory table		-- JLB 6/19/2019
		If @RCount = 0
		Begin
			SELECT  @LUID 			= L.L_UID,
					@ReleaseDtTm	= IsNull(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
					@ArrDtTm		= L.L_ArrDtTm,
					@ReportDtTm		= IsNull(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
					@DepDtTm		= L.L_DepDtTm,
					@FoundBy		= 'tblInv'

	        FROM	dbo.tblLayover as	L	(NOLOCK)
			Join	dbo.tblInv	   as   I   (NOLOCK) ON L.L_UID = I.L_UID
		
	        WHERE	(L.L_UID		= @L_UID or L.DF_AISUID = @CP_UID)
	        --AND		L.L_EmpID 	= @CrewID	-- Removed 6/6/2018 Steve
	        AND		L.A_Symbol 	= @Airline
	        AND		I.L_UID_Prior <> -1
	        AND		I_CancelResultCd <> 1		-- Don't show Killed records JB 11/19/09
			AND		L.L_ArrStaCd = @StationCd   -- New JB 6/25/08
			AND		I.H_HotelKey = case when isnull(@HotelKey, 0) = 0
											then	I.H_HotelKey
											else  @HotelKey
									end	-- New JB 9/2/09


			IF @@ROWCOUNT = 0
			BEGIN
				-- Search without using the HotelKey
		        SELECT  @LUID 			= L.L_UID,	
						@ReleaseDtTm	= ISNULL(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
						@ArrDtTm		= L.L_ArrDtTm,
						@ReportDtTm		= ISNULL(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
						@DepDtTm		= L.L_DepDtTm,
						@FoundBy		= 'tblOrder'

						FROM	dbo.tblLayover AS	L	(NOLOCK)
						JOIN	dbo.tblOrder   AS   O  (NOLOCK) ON L.L_UID = O.L_UID
						
						WHERE	(L.L_UID		= @L_UID or L.DF_AISUID = @CP_UID)
						--AND		L.L_EmpID 	= @CrewID	-- Removed 6/6/2018 Steve
						AND		L.A_Symbol 	= @Airline
						AND		L.L_ArrStaCd = @StationCd   -- New JB 6/25/08
						AND		O.O_OrderType	IN (100, 110)	-- 01/11/2023 Only Adds/Increase - CREWREZ-2010

			END
		END
--select @ArrDtTm
		-- ------------------------------------------------------------------------------------------------------------------------

		-- Found Layover
		IF	@LUID IS NOT NULL
		BEGIN
		
			If @FoundBy = 'tblInv'		-- Added 6/6/2018 Steve
			Begin
				SELECT	DISTINCT @H_HotelKey	= I.H_HotelKey,
								 @ReleaseDtTm	= IsNull(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
								 @L_ArrDtTm		= I.L_ArrDtTm,
								 @ReportDtTm	= IsNull(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
								 @DepDtTm		= I.L_DepDtTm,				-- Added 7/10/08 SR
								 @EnteredByWho	= L.L_CreatedByWho,
								 @SourceCd		= L.L_Source,
								 @NiteCnt		= count(distinct I.I_ResvDt),	-- Added 7/1/08 JB
								 @CFNumb		= (select top 1 isnull(I_ConfNumb, '') from dbo.tblInv with (nolock) where H_HotelKey = I.H_HotelKey and L_UID_Prior <> -1 and L_UID = L.L_UID and I_StayCd = 1), --is this even selecting the correct one?
								 @RoomTypeCd		= (select top 1 isnull(I_RoomTypeCd, '') from dbo.tblInv with (nolock) where H_HotelKey = I.H_HotelKey and L_UID_Prior <> -1 and L_UID = L.L_UID and I_StayCd = 1),
								 @GroundVendor_Arrival    = (select top 1 substring (rtrim(P.P_NameFull) ,1,30)
															+ case when T.T_statuscd = 'P' then ' - *Pending' else ' (Ph: ' + rtrim(P.P_MainPhoneNumb) + ')' end --Added on 01/26/2021 to return only 1 records when the process is run
															 --Added on 01/11/2023 to return pending when 3rd party is not confirmed
															 FROM		dbo.tblInv			I (nolock)
															JOIN		dbo.tblLayover		L (nolock)	ON  I.L_UID	= L.L_UID
															LEFT JOIN	dbo.tblTravelTrips	T (nolock)	ON  T.I_UID = I.I_UID
																										AND I.I_StayCd = 1
																										AND T.T_CancelResultCd <= 0
																										AND T.T_StatusCd in ('R', 'N', 'C', 'P')
															LEFT JOIN	dbo.tblProv			P (nolock)	ON P.P_ProvKey = T.P_ProvKey

															WHERE	I.L_UID			= @LUID
															AND		I.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
																							THEN I.H_HotelKey
																							ELSE @HotelKey
																					  END	-- NEW JB 9/2/09
															AND		I.L_UID_Prior	<> -1			-- New 7/1/08 JB
															AND		t.T_TripCd IN ('TH','oH','SS')

								 ), --Added on 07/20/2020 Ani
								 @GroundVendor_Departure  =(select top 1 substring (rtrim(P.P_NameFull) ,1,30)
															+ case when T.T_statuscd = 'P' then ' - *Pending' else ' (Ph: ' + rtrim(P.P_MainPhoneNumb) + ')' end --Added on 01/26/2021 to return only 1 records when the process is run
															 --Added on 01/11/2023 to return pending when 3rd party is not confirmed
															 FROM		dbo.tblInv			I (nolock)
															JOIN		dbo.tblLayover		L (nolock)	ON  I.L_UID	= L.L_UID
															LEFT JOIN	dbo.tblTravelTrips	T (nolock)	ON  T.I_UID = I.I_UID
																										AND I.I_StayCd = 1
																										AND T.T_CancelResultCd <= 0
																										AND T.T_StatusCd in ('R', 'N', 'C', 'P')
															LEFT JOIN	dbo.tblProv			P (nolock)	ON P.P_ProvKey = T.P_ProvKey

															WHERE	I.L_UID			= @LUID
															AND		I.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
																							THEN I.H_HotelKey
																							ELSE @HotelKey
																					  END	-- NEW JB 9/2/09
															AND		I.L_UID_Prior	<> -1			-- New 7/1/08 JB
															AND		t.T_TripCd IN ('TA','OA')

								 ), --Added on 07/20/2020 Ani
							 	 @HC_Key	    = I.HC_Key, --Added on 07/20/2020 Ani
								 @UpdatedLastDtTm_Departure  = (select top 1 ISNULL(T.T_UpdatedLastDtTm, T.T_PostedDtTm)
															 FROM		dbo.tblInv			I (nolock)
															JOIN		dbo.tblLayover		L (nolock)	ON  I.L_UID	= L.L_UID
															LEFT JOIN	dbo.tblTravelTrips	T (nolock)	ON  T.I_UID = I.I_UID
															                                            AND I.A_Symbol = T.A_Symbol
																										AND I.I_StayCd = 1
																										AND T.T_CancelResultCd <= 0
																										AND T.T_StatusCd in ('R', 'N', 'C','P')
															LEFT JOIN	dbo.tblProv			P (nolock)	ON P.P_ProvKey = T.P_ProvKey

															WHERE	I.L_UID			= @LUID
															AND		I.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
																							THEN I.H_HotelKey
																							ELSE @HotelKey
																					  END	
															AND		I.L_UID_Prior	<> -1			
															AND		t.T_TripCd IN ('TA','OA')
															),  	-- Added 2/8/2023 LOD-936
								@UpdatedLastDtTm__Arrival    = (select top 1 ISNULL(T.T_UpdatedLastDtTm, T.T_PostedDtTm)
															 FROM		dbo.tblInv			I (nolock)
															JOIN		dbo.tblLayover		L (nolock)	ON  I.L_UID	= L.L_UID
															LEFT JOIN	dbo.tblTravelTrips	T (nolock)	ON  T.I_UID = I.I_UID
															                                            AND I.A_Symbol = T.A_Symbol
																										AND I.I_StayCd = 1
																										AND T.T_CancelResultCd <= 0
																										AND T.T_StatusCd in ('R', 'N', 'C','P')
															LEFT JOIN	dbo.tblProv			P (nolock)	ON P.P_ProvKey = T.P_ProvKey
															WHERE	I.L_UID			= @LUID
															AND		I.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
																							THEN I.H_HotelKey
																							ELSE @HotelKey
																					  END	-- NEW JB 9/2/09
															AND		I.L_UID_Prior	<> -1			-- New 7/1/08 JB
															AND		t.T_TripCd IN ('TH','oH','SS')
															),  	-- Added 2/8/2023 LOD-936
															@HotelUpdatedLastDtTm = L.L_PostedDtTm	-- Added 2/8/2023 LOD-936


				FROM		dbo.tblInv			I (nolock)
				JOIN		dbo.tblLayover		L (nolock)	ON  I.L_UID	= L.L_UID
				LEFT JOIN	dbo.tblTravelTrips	T (nolock)	ON  T.I_UID = I.I_UID
															AND I.I_StayCd = 1
															AND T.T_CancelResultCd <= 0
															AND T.T_StatusCd in ('R', 'N', 'C')
				LEFT JOIN	dbo.tblProv			P (nolock)	ON P.P_ProvKey = T.P_ProvKey

				WHERE	I.L_UID			= @LUID
				AND		I.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
												THEN I.H_HotelKey
												ELSE @HotelKey
										  END	-- NEW JB 9/2/09
				AND		I.L_UID_Prior	<> -1			-- New 7/1/08 JB

				GROUP BY I.H_HotelKey, L.L_ReleaseDtTm, I.L_ArrDtTm, L.L_ReportDtTm, I.L_DepDtTm, L.L_CreatedByWho, L.L_Source, 
					--rtrim(P.P_NameFull) + ' (Ph: ' + rtrim(P.P_MainPhoneNumb) + ')',
					 L.L_UID, I.HC_Key, L.L_ArrDtTm, L.L_DepDtTm, L.L_PostedDtTm  --added L.L_ArrDtTm , L.L_DepDtTm (YV) 
			End

			If @FoundBy = 'tblOrder'		-- Added 6/6/2018 Steve
			Begin

				SELECT	DISTINCT @H_HotelKey	= O.H_HotelKey,
								 @ReleaseDtTm	= IsNull(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
								 @L_ArrDtTm		= O.L_ArrDtTm,
								 @ReportDtTm	= IsNull(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
								 @DepDtTm		= O.L_DepDtTm,				-- Added 7/10/08 SR
								 @EnteredByWho	= L.L_CreatedByWho,
								 @SourceCd		= L.L_Source,
								 @NiteCnt		= count(distinct O.I_ResvDt),	-- Added 7/1/08 JB
								 @CFNumb		= (select top 1 isnull(I_ConfNumb, '') from dbo.tblInv with (nolock) where H_HotelKey = O.H_HotelKey and L_UID_Prior <> -1 and L_UID = L.L_UID and I_StayCd = 1),
								 @RoomTypeCd	= (select top 1 isnull(I_RoomTypeCd, '') from dbo.tblInv with (nolock) where H_HotelKey = O.H_HotelKey and L_UID_Prior <> -1 and L_UID = L.L_UID and I_StayCd = 1),
								 @Posted		= O.O_PostedDttm,
								 @HC_Key	    = O.HC_Key,
								 @HotelUpdatedLastDtTm = L.L_PostedDtTm	-- Added 2/8/2023 LOD-936

	        FROM	dbo.tblLayover as	L	(NOLOCK)
			Join	dbo.tblOrder   as   O  (NOLOCK) ON L.L_UID = O.L_UID
		
	        WHERE	(L.L_UID			= @L_UID or L.DF_AISUID = @CP_UID)
	        --AND		L.L_EmpID 		= @CrewID	-- Removed 6/6/2018 Steve
	        AND		L.A_Symbol 		= @Airline
			AND		L.L_ArrStaCd	= @StationCd   -- New JB 6/25/08
			AND		O.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
												THEN	O.H_HotelKey
												ELSE  @HotelKey
									  END	-- NEW JB 9/2/09
		    AND		O.O_OrderType	IN (100, 110)	-- 01/11/2023 Only Adds/Increase - CREWREZ-2010		
				
				GROUP BY O.H_HotelKey, L.L_ReleaseDtTm, O.L_ArrDtTm, L.L_ReportDtTm, O.L_DepDtTm, L.L_CreatedByWho, L.L_Source, O.O_PostedDtTm, 
						L.L_UID, O.HC_Key, L.L_ArrDtTm, L.L_DepDtTm, L.L_PostedDtTm	-- Added 2/8/2023 LOD-936  --added L.L_ArrDtTm , L.L_DepDtTm (YV) 
				ORDER BY O.O_PostedDtTm --desc
			End
			---
			--- If using the ExtKey does not work, try a little harder.
			---
			If @H_HotelKey is null
			Begin
				SELECT	DISTINCT @H_HotelKey 		= I.H_HotelKey,
								 @ReleaseDtTm		= IsNull(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
								 @L_ArrDtTm			= I.L_ArrDtTm,
								 @ReportDtTm		= IsNull(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
								 @DepDtTm			= I.L_DepDtTm,
								 @ClearCustArrInd	= IsNull(L.L_ClearCustArrInd, 'N'),	-- Added Steve 6/6/2018 - Needed Here Since We're Using Another L_UID Value Than Above
								 @ClearCustDepInd	= IsNull(L.L_ClearCustDepInd, 'N'),	-- Added Steve 6/6/2018 - Needed Here Since We're Using Another L_UID Value Than Above
								 @EnteredByWho		= L.L_CreatedByWho,
								 @NiteCnt			= count(distinct I_ResvDt),	-- Added 7/1/08 JB
								 @CFNumb			= (select top 1 isnull(I_ConfNumb, '') from dbo.tblInv with (nolock) where H_HotelKey = I.H_HotelKey and L_UID_Prior <> -1 and L_UID = L.L_UID and I_StayCd = 1),
								 @RoomTypeCd		= (select top 1 isnull(I_RoomTypeCd, '') from dbo.tblInv with (nolock) where H_HotelKey = I.H_HotelKey and L_UID_Prior <> -1 and L_UID = L.L_UID and I_StayCd = 1),
								 @LUID				= I.L_UID,
								 @HC_Key			= I.HC_Key,
								 @HotelUpdatedLastDtTm = L.L_PostedDtTm	-- Added 2/8/2023 LOD-936

				FROM	dbo.tblInv		I (nolock)
				JOIN	dbo.tblLayover	L (nolock) ON I.L_UID	= L.L_UID
				WHERE	(I.L_ArrDtTm 	>= DateAdd(hh, -1, @ArrDtTm) And I.L_ArrDtTm <= DateAdd(hh, 1, @ArrDtTm))	-- Changed Steve 6/6/2018 - Need To Use HH Instead Of DD In BETWEEN
--				WHERE	I.L_ArrDtTm 	between DateAdd(hh, -1, @ArrDtTm) and DateAdd(dd, 1, @ArrDtTm)
				AND		I.H_HotelKey = CASE WHEN ISNULL(@HotelKey, 0) = 0
											THEN I.H_HotelKey
											ELSE @HotelKey
										END	-- New JB 9/2/09
				And	L.L_EmpId		= @CrewID
				And	L.L_ArrStaCd	= @StationCd
				AND	I.L_UID_Prior	<> -1
				--ADDED SR 8/26
				Group by I.L_UID, I.H_HotelKey, L.L_ReleaseDtTm, I.L_ArrDtTm, L.L_ReportDtTm, I.L_DepDtTm, L.L_ClearCustArrInd, L.L_ClearCustDepInd, L.L_CreatedByWho , L.L_UID, I.HC_Key, L.L_ArrDtTm, L.L_DepDtTm, L.L_PostedDtTm	-- Added 2/8/2023 LOD-936  --added L.L_ArrDtTm , L.L_DepDtTm (YV) 
				--END ADDED
			End

			IF (@H_HotelKey IS NULL)	-- Changed 6/6/2018 Steve - I Really Don't Think This Is Even Needed?
			BEGIN
				-- Check For Pending Order
				SELECT  DISTINCT @H_HotelKey	= O.H_HotelKey,
								 @ReleaseDtTm	= IsNull(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
							 	@L_ArrDtTm		= O.L_ArrDtTm,
								 @ReportDtTm	= IsNull(L.L_ReportDtTm, L.L_DepDtTm),	-- Added 4/11/2019 Steve
							 	@DepDtTm		= O.L_DepDtTm,
								@HC_Key			= O.HC_Key,
								@FoundBy		= 'tblOrder'

				FROM	dbo.tblOrder	AS O	(nolock)
				JOIN	dbo.tblLayover	AS L	(nolock)	ON O.L_UID		= L.L_UID

				WHERE	O.L_UID		= @LUID
				AND		O.H_HotelKey	= CASE WHEN ISNULL(@HotelKey, 0) = 0
												THEN  H_HotelKey
												ELSE  @HotelKey
										END	-- NEW JB 9/2/09
				AND		O.O_OrderType	IN (100, 110)	-- 01/11/2023 Only Adds/Increase - CREWREZ-2010

				-- Search not using HotelKey.  This will be queued to another hotel
				IF @@ROWCOUNT = 0
				BEGIN
						SELECT  DISTINCT @H_HotelKey	= O.H_HotelKey,
										@ReleaseDtTm	= ISNULL(L.L_ReleaseDtTm, L.L_ArrDtTm),	-- Added 4/11/2019 Steve
							 			@L_ArrDtTm		= L.L_ArrDtTm,
							 			@DepDtTm		= L.L_DepDtTm,
										@HC_Key			= O.HC_Key,
										@FoundBy		= 'tblOrder'

						FROM	dbo.tblOrder	O WITH (NOLOCK)
						JOIN	dbo.tblLayover	L WITH (NOLOCK) ON O.L_UID = L.L_UID
						WHERE	O.L_UID			= @LUID
						AND		L.L_ArrStaCd	= @StationCd
						--And		L.L_EmpId		= @CrewID	-- Removed 6/6/2018 Steve
						AND		(L.L_ArrDtTm 	>= DATEADD(hh, -1, @ArrDtTm) AND L.L_ArrDtTm <= DATEADD(hh, 1, @ArrDtTm))
						AND		O.O_OrderType	IN (100, 110)	-- 01/11/2023 Only Adds/Increase - CREWREZ-2010
						
				END
			END

			-- Set @StatFlg Based On What Was Found
			IF (@H_HotelKey IS NULL)
			BEGIN
				-- Not Found In tblOrder
				SELECT	@StatFlg = 'Check For Manual Override Records LUID:' + convert(char(12), @LUID)
			END
			ELSE
			IF @FoundBy = 'tblOrder'		-- Added 6/6/2018 Steve - Replaced IF (@H_HotelKey IS NULL) in IF/ELSE
			BEGIN
				-- Found In tblOrder, So Pending
				-- This value is tested below.. so don't change it 4/22/11 JB
				SELECT	@Statflg = 'This Layover Is Pending Confirmation'   -- LUID:' + convert(char(12), @LUID)        
			END
			ELSE
			BEGIN
				-- Found In tblInv, So Confirmed
				Select	@Statflg	= 'Crew XL record exists, not XLed yet.',
						@H_HotelKey = I.H_HotelKey
				From	dbo.tblLayover	L with (nolock)
				Join	dbo.tblInv		I with (nolock)		ON  L.L_UID				= I.L_UID
				Join	dbo.tblCrewXL	XL with (nolock)	ON 	L.L_EmpId			= XL.CX_EmpId
															AND L.L_ArrStaCd		= XL.CX_ArrStaCd
															AND I.I_ResvDt			= XL.CX_ResvDt
															And I.A_Symbol			= XL.A_Symbol
															And XL.CX_ReInstateDtTm IS NULL
															and isnull (XL.CX_Note,'') like 'CMC%'
				Where	L.L_UID				= @LUID
				And		L.A_Symbol			= @Airline	
				And		I.I_CancelResultCd	<= 0
				And		I.L_UID_Prior		<> -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests
               	
				SELECT @Statflg = 'This Layover Is Confirmed ' +
					IIF((@CFNumb IS NULL or @CFNumb = ''), IIF(@RoomTypeCd='H','', '(Forecast).'), --LOD-27826 if room type is hadblock then no need to show forecast
					'(CF# ' + @CFNumb + ')'),

				@H_HotelKey = H_HotelKey
				From	dbo.tblInv	I with (nolock)
				Where	I.L_UID			= @LUID
				And	I.I_CancelResultCd	<= 0
				And	I.I_InvType		= 0
				And	I.L_UID_Prior		<> -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests

				Select	@Statflg = 'Room has been cancelled (LUID:' + rtrim(convert(char(12), I.L_UID)) + ')',
					@H_HotelKey = H_HotelKey
				From	dbo.tblInv	I with (nolock)
				Where	I.L_UID			= @LUID
				And	I.I_CancelResultCd	in (2, 4)
				And	I.L_UID_Prior		<> -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests

				Select	@Statflg = 'Crewmember no-showed - Room not CFed',
					@H_HotelKey = H_HotelKey				
				From	dbo.tblInv	I with (nolock)
				Where	I.L_UID			= @LUID
				And	I.I_CancelResultCd	in (10)
				And	I.L_UID_Prior		<> -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests

				Select	@Statflg = 'Room is currently un-assigned (inv).',
					@H_HotelKey = H_HotelKey
				From	dbo.tblInv	I with (nolock)
				Where	I.L_UID			= @LUID
				And	I.I_CancelResultCd	<= 0
				And	I.I_InvType			> 0
				And	I.L_UID_Prior		<> -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests

				Select	@Statflg = 'Room is part of a pending order.',
					@H_HotelKey = H_HotelKey
				From	dbo.tblInv	I with (nolock)
				Where	I.L_UID			= @LUID
				And	I.I_CancelResultCd	<= 0
				And	I.I_InvType			< 0
				And	I.L_UID_Prior		<> -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests

	            SELECT	@Statflg	= 'Crewmember was moved from this hotel',
						@H_HotelKey = H_HotelKey
				From	dbo.tblInv	I with (nolock)
				Where	I.L_UID			= @LUID
				And	I.L_UID_Prior		= -1
				--AND	I.H_HotelKey		= isnull(@HotelKey, I.H_HotelKey)	-- New JB 9/2/09

				IF @@ROWCOUNT > 0
					GoTo SkipOtherTests

               	SELECT	@Statflg = 'Unknown Status?'	

			END
SkipOtherTests:

			-- Populate Hotel Variables If A Hotel Was Found
			IF (@H_HotelKey IS NOT NULL)
			BEGIN  

				SELECT	@H_NameFull			= H.H_NameFull,
						@H_City				= H.H_City, 
						@H_MainPhoneNumb	= H.H_MainPhoneNumb, 
						@H_FaxNumb1			= H.H_FaxNumb1,
						@H_Contact1			= H.H_Contact1, 
						@H_StreetAddr1 		= H.H_StreetAddr1,
						@H_StateProvince	= H.H_StateProvince,
						@HC_VanServiceCd_Arrival	= CASE  when L.L_ArrFltNum in ('NOGT')		  THEN 'N/A' --Added on 07/20/2020 Ani
													WHEN HV.V_HotelCourtesyVanInd IS NULL THEN 'Pending'
											--		WHEN HV.V_HotelCourtesyVanInd = -1 	  THEN  HV.V_VanDesc
																						  ELSE ISNULL(@GroundVendor_Arrival, 'Public Van')
											  END,	
						@HC_VanServiceCd_Departure	= CASE  when L.L_DepFltNum in ('NOGT')		  THEN 'N/A' --Added on 07/20/2020 Ani
													WHEN HVL.[V_HotelCourtesyVanInd_Dep] IS NULL THEN 'Pending'
											--		WHEN HV.V_HotelCourtesyVanInd = -1 	  THEN  HV.V_VanDesc
																						  ELSE ISNULL(@GroundVendor_Departure, 'Public Van')
											  END,
						@CancelBy			= CASE 
													WHEN H.H_CancelCd = 0 THEN
														'Cancels Not Allowed'
													WHEN H.H_CancelCd = 1 THEN
														'Cancel By ' + dbCommon.dbo.uFN_CvtBlock(H.H_CancelDeadlineTmi) + ' (SAME DAY)'
													WHEN H.H_CancelCd = 2 THEN
														'Cancel By ' + dbCommon.dbo.uFN_CvtBlock(H.H_CancelDeadlineTmi) + ' (PRIOR DAY)'
													ELSE
														'Cancel ' + CAST(H.H_CancelHrs AS VARCHAR(3)) + ' Hours Prior'
											   END,
						@HotelVan_Start = HV.V_VanStartTime,
						@HotelVan_End   = HV.V_VanStopTime,
						@HotelVan_Start_D	= HVL.[V_VanStartTime_Dep],
						@HotelVan_End_D		= HVL.[V_VanStopTime_Dep]

				FROM		dbo.tblHotel 			AS H 	(NOLOCK)
				LEFT JOIN	dbo.tblHotelVan			AS HV	(NOLOCK)	ON H.H_HotelKey	= HV.H_HotelKey		
																		AND HV.A_Symbol	= @Airline
																		AND @StationCd= HV.S_StationCd
				LEFT JOIN	dbo.tblHotelVan_Lookup	AS HVL	(NOLOCK)	ON H.H_HotelKey		= HVL.H_HotelKey		
																		AND HVL.A_Symbol	= @Airline
																		AND @StationCd		= HVL.S_StationCd
				LEFT JOIN	dbo.tbllayover			AS L	(NOLOCK)	on (L.L_UID = @L_UID or L.DF_AISUID = @CP_UID)
				WHERE	H.H_HotelKey		= @H_HotelKey
			END
		END
		ELSE  -- @LUID Is Null
	    BEGIN
			--If @Airline in ('8C', 'RD', 'XJ')
			--	SELECT	@StatFlg = 'Leg Did Not Generate A Layover (or was merged w/ prior)'
			--else
			SELECT	@StatFlg = 'This Leg DID Not Generate A Layover'
			
		END

	END   
	ELSE	-- Found InActive Station record!
	BEGIN
			SELECT	@StatFlg = 'Station (' +  @StationCd + ') is not turned on'
	END 
-- ------------------------------------------------------------------------------
-- FOUND REZID OF LAYOVER
-- Rez ID info for the Layover details -- Addon on 08/05/2024 LOD-23619
-- Select the I_UID and value return in @RezId parameter from table value found in parameter @FoundBy where L_UID matches @LUID and
-- When the layover is for more than one night, then show only the first Rez ID i.e I_UID (for the first night) as the reference (due to each night has their own Rez ID)

-- Check if the parameter @LUID is not NULL 
IF	@LUID IS NOT NULL
		BEGIN
		 -- Check if the @FoundBy parameter indicates the table 'tblInv'
		 
			If @FoundBy = 'tblInv'	
				BEGIN 
						SELECT @RezId= I_UID  FROM tblInv WHERE L_UID=@LUID AND I_ResvDt=(SELECT MIN(I_ResvDt) FROM tblInv WHERE L_UID=@LUID)
				END
			 -- Check if the @FoundBy parameter indicates the table 'tblOrder'
			If @FoundBy = 'tblOrder'	
				BEGIN 
						SELECT @RezId= I_UID  FROM tblOrder WHERE L_UID=@LUID AND I_ResvDt=(SELECT MIN(I_ResvDt) FROM tblOrder WHERE L_UID=@LUID)
				END
		END
-- -------------------------------------------------------------------------------------------------------
ReturnInfo:    
	-- 01/05/2018 - Added By JB To Show Hotel Time Instead Of Arrive/Depart
	-- 5/16/2019 Steve - Changed To Using Report/Release When Available
	--IF (@HC_Key IS NOT NULL AND @HC_Key <> 0)
	--BEGIN

	--Select
	--	  	@PickUp_Arrival		= [dbo].[F_GetAirportPickUp]	(@Airline, @L_UID, @H_HotelKey), --Added on 07/20/2020 Ani

	--		@Dropoff_Arrival	= [dbo].[F_GetCheckInTime]		(@Airline, @L_UID, @H_HotelKey), --Added on 07/20/2020 Ani

	--		@PickUp_Departure	= [dbo].[F_GetCheckOutTime]		(@Airline, @L_UID, @H_HotelKey), --Added on 07/20/2020 Ani

	--		@Dropoff_Departure	= [dbo].[F_GetAirportDropOff]	(@Airline, @L_UID, @H_HotelKey), --Added on 07/20/2020 Ani

	--		@CheckIN			= [dbo].[F_GetCheckInTime]		(@Airline, @L_UID, @H_HotelKey),

	--		@CheckOut			= [dbo].[F_GetCheckOutTime]		(@Airline, @L_UID, @H_HotelKey)

				
	--From dbo.tblHotelContract HC
	--Join dbo.tblAirlineContract AC on HC.A_Symbol = AC.A_Symbol and HC.A_Symbol = @Airline
	--Join dbo.tblStation S on S.S_StationCd = @StationCd
	--where HC.HC_Key = @HC_Key
	
	--End
	--ELSE --IF (@HC_Key IS NULL)   -- This is an alternate hotel 
	--BEGIN

	-- Miles from Sta, is really minutes  
	--SELECT      @CheckIN =	[dbo].[F_GetCheckInTime]  (@Airline, @L_UID, @H_HotelKey),
	--			@CheckOut = [dbo].[F_GetCheckOutTime] (@Airline, @L_UID, @H_HotelKey)

	--FROM dbo.tblAirlineContract AC 
	--WHERE AC.A_Symbol = @Airline
	
	--END
	-- REMOVED IF/ELSE And Table Joins 4/15/2021
	SELECT
		@PickUp_Arrival = coalesce(GTA.Pickup, L.L_ReleaseDtTm, L.L_ArrDtTm), --Added on 07/20/2020 Ani
		@Dropoff_Arrival = coalesce(GTA.CheckIn, L.L_ReleaseDtTm, L.L_ArrDtTm), --Added on 07/20/2020 Ani
		@PickUp_Departure = coalesce(GTD.CheckOut, L.L_ReportDtTm, L.L_DepDtTm), --Added on 07/20/2020 Ani
		@Dropoff_Departure = coalesce(GTD.DropOff, L.L_ReportDtTm, L.L_DepDtTm), --Added on 07/20/2020 Ani
		@CheckIN = coalesce(GTA.CheckIn, L.L_ReleaseDtTm, L.L_ArrDtTm),
		@CheckOut = coalesce(GTD.CheckOut, L.L_ReportDtTm, L.L_DepDtTm),
		@PickUp_Arrival_Location	= CASE WHEN SUBSTRING( ISNULL(L_ArrFltNum,''),1,2) = '' THEN 'N/A' WHEN (SUBSTRING( ISNULL(L_ArrFltNum,''),1,2) = @Airline AND  AC.AC_TMS_Other	<> 0)  THEN CONCAT( 'FBO/Ramp (' ,rtrim(L_ArrStaCd), ')' ) ELSE CONCAT( 'Terminal ('
 , rtrim(L_ArrStaCd), ')' ) END,	
		@Dropoff_Departure_Location	= CASE WHEN SUBSTRING( ISNULL(L_DepFltNum,''),1,2) = '' THEN 'N/A' WHEN (SUBSTRING( ISNULL(L_DepFltNum,''),1,2) = @Airline AND  AC.AC_TMS_Other	<> 0) THEN CONCAT( 'FBO/Ramp (' ,rtrim(L_DepStaCd), ')' ) ELSE CONCAT( 'Terminal 
(' , rtrim(L_DepStaCd), ')' ) END

	FROM dbo.tblLayover L 
	JOIN dbo.tblAirlineConfigurations AC
	ON AC.A_Symbol = L.A_Symbol
	OUTER APPLY [dbo].[TVF_GetTravelTime_A](@Airline, L.L_UID, @H_HotelKey) GTA
	OUTER APPLY [dbo].[TVF_GetTravelTime_D](@Airline, L.L_UID, @H_HotelKey) GTD	
	WHERE (L.L_UID = @L_UID or L.DF_AISUID = @CP_UID)
	
	
	Select @Comment = case when @HC_Key is not null and @HC_Key <> 0
							then 'CheckIn/Out times include travel time'
							-- This is an alternate hotel, and the stations match
							when @HC_Key = 0 and H_NearestSta = @StationCd
							then 'CheckIn/Out times include ESTIMATED travel time'
							-- Same here, but when the station does not match, it could be very far away,
							-- and we don't capture the distance for other airports.
							else 'CheckIn/Out times do NOT include travel time'
						  end
	From dbo.tblHotel 
	where H_HotelKey = @HotelKey
	
/*	
    SET @CheckIN = @L_ArrDtTm
	SET @CheckOut = @DepDtTm
*/	
	
	-- Added 'ZW' to this 4/22/11 per Antone
	--
	SELECT	ISNULL(@Statflg, 'This Leg Did Not Generate A Layover') AS [Status], 
			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' 
				 AND @Airline IN ('RD', 'ZW')
						THEN 'Pending Hotel'
						ELSE @H_NameFull
			END AS [HotelName], 
			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' 
				 AND @Airline IN ('RD', 'ZW')
						THEN ''
						ELSE @H_City
			END AS City, 
			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' 
				 AND @Airline IN ('RD', 'ZW')
						THEN ''
						ELSE @H_MainPhoneNumb	
			END AS Phone,
			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' 
				 AND @Airline IN ('RD', 'ZW')
						THEN ''
						ELSE @H_FaxNumb1			
			END AS [FaxNumber], 
			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' 
				 AND @Airline IN ('RD', 'ZW')
						THEN ''
						ELSE @H_Contact1			
			END AS [ContactNumber],
   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' 
				 AND @Airline IN ('RD', 'ZW')
						THEN ''
						ELSE @H_StreetAddr1		
			END AS [Address], 
			@H_StateProvince	AS [StateProvince],

			isnull(CONVERT(char(10), @HotelVan_Start, 108),'N/A') as [HVStarttime],

			isnull(CONVERT(char(10), @HotelVan_End, 108),'N/A') as [HVEndtime],
			
			isnull(CONVERT(char(10), @HotelVan_Start_D, 108),'N/A') as [HV_Starttime_D],

			isnull(CONVERT(char(10), @HotelVan_End_D, 108),'N/A') as [HV_Endtime_D],

			@HC_VanServiceCd_Arrival	AS [VanServiceCodeArrival],   --Added on 07/20/2020 Ani

   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' then 'TBD'
			ELSE isnull(CONVERT(CHAR(20), @PickUp_Arrival,121),'TBD') END	AS [ArrPickUp]	,--Added on 07/20/2020 Ani

   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' then 'TBD'
			ELSE isnull(CONVERT(CHAR(20), @Dropoff_Arrival, 121),'TBD') END	AS [ArrDropOff],--Added on 07/20/2020 Ani

			@HC_VanServiceCd_Departure	AS [VanServiceCodeDeparture], --Added on 07/20/2020 Ani

   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' then 'TBD'
			ELSE isnull(CONVERT(CHAR(20), @PickUp_Departure, 121),'TBD') END	AS [DepPickUp]	,--Added on 07/20/2020 Ani

   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' then 'TBD'
			ELSE isnull(CONVERT(CHAR(20), @Dropoff_Departure, 121),'TBD') END  AS [DepDropOff]		,--Added on 07/20/2020 Ani	

			/* REMARKED OUT Steve Ruscitto 7/10/2008
			@HC_VanServiceCd + case when @Airline = 'RD'
									then ' (#Nights: ' + convert(char(3), @NiteCnt) + ')'  	
								    else ''
								end AS HC_VanServiceCd,
			*/
			@NiteCnt			AS NiteCnt,

   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' then 'TBD'
			ELSE isnull(CONVERT(CHAR(20), @CheckIn, 121),'TBD')	END		AS [CheckIn],
			
   			CASE WHEN @Statflg = 'This Layover Is Pending Confirmation' then 'TBD'
			ELSE isnull(CONVERT(CHAR(20), @CheckOut, 121),'TBD')END 	AS [CheckOut],
			@CancelBy			AS [CancelBy],
			@Comment			AS Comment,
			--@UpdatedLastDtTm_Departure        AS DepLastDtTm,	-- Added 2/8/2023 LOD-936
			--@UpdatedLastDtTm__Arrival     AS ArrLastDtTm,	-- Added 2/8/2023 LOD-936
			--@HotelUpdatedLastDtTm        AS HotelLastDtTm		-- Added 2/8/2023 LOD-936
			DateAdd(mi, ISNULL(-(dbo.uFN_GetGMTOffset (@StationCd, @UpdatedLastDtTm_Departure)),0), @UpdatedLastDtTm_Departure)  AS DepLastDtTm,    -- Change Time to GMT time -- Added 2/10/2023 RP
			DateAdd(mi, ISNULL(-(dbo.uFN_GetGMTOffset (@StationCd, @UpdatedLastDtTm__Arrival)),0), @UpdatedLastDtTm__Arrival)    AS ArrLastDtTm,    -- Change Time to GMT time -- Added 2/10/2023 RP
			DateAdd(mi, ISNULL(-(dbo.uFN_GetGMTOffset (@StationCd, @HotelUpdatedLastDtTm)),0), @HotelUpdatedLastDtTm)            AS HotelLastDtTm,	  -- Change Time to GMT time -- Added 2/10/2023 RP
			@RezId as RezId,  -- Rez ID info for the Layover details -- Addon on 08/05/2024 LOD-23619
			@PickUp_Arrival_Location 		AS [ArrPickUpLocation],		-- Added 8/6/2024 LOD-21734
			@Dropoff_Departure_Location		AS [DepDropOffLocation]		-- Added 8/6/2024 LOD-21734

END


Completion time: 2025-06-06T00:52:45.4820816-04:00
