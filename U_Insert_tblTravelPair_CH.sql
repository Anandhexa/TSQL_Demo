Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE    proc [dbo].[U_Insert_tblTravelPair_CH]
    (
    @PA_Key [int] NULL,
    --@TPL_VendorID [int] NULL,
    --@TPL_ContractNumber [varchar](100),
    @P_ProvKey [int] NULL,
    @A_Symbol [char](2) NULL,
    @TP_OrderBy [int] NULL,
    @TP_StartDtTm [datetime] NULL,
    @TP_EndDtTm [datetime] NULL,
    @TP_HotelStationCd [varchar](5) NULL,
    @TP_TravelPairType [varchar](255) NULL,
    @TP_PickUpKey [varchar](8) NULL,
    @TP_DropOffKey [varchar](8) NULL,
    @TP_PickUpAdjTmi [int] NULL,
    @TP_DropOffAdjTmi [int] NULL,
    @TP_HotelLimoInd [char](1) NULL,
    @TP_CancelCd [int] NULL,
    @TP_CancelDeadlineTmi [int] NULL,
    @TP_CancelHrs [int] NULL,
    @TP_UseTierRateInd [char](1) NULL,
    @CC_CurrencyCd [char](3) NULL,
    @TP_RateFlat [money] NULL,
    @TP_RateHead [money] NULL,
    @TP_TollAmtToDropOff [money] NULL,
    @TP_TollAmtFromDropOff [money] NULL,
    @TP_NoShowCharge [money] NULL,
    @TP_MiscTaxToDropOff [money] NULL,
    @TP_MiscTaxFromDropOff [money] NULL,
    @TP_Gratuity [money] NULL,
    @TP_Notes [varchar](100) NULL,
    @TP_TripTmi [int] NULL,
    @TP_TimeRatePerMin [money] NULL,
    @TP_WaitTimeRate [money] NULL,
    @TP_PickUpNotes [varchar](255) NULL,
    @TP_AcctNumb [nchar](15) NULL,
    @TP_FOP [nchar](30) NULL,
    @TP_HasTiered [char](1) NULL,
    @TP_ByTierStart1 [int] NULL,
    @TP_ByTierEnd1 [int] NULL,
    @TP_ByTierRate1 [money] NULL,
    @TP_ByTierStart2 [int] NULL,
    @TP_ByTierEnd2 [int] NULL,
    @TP_ByTierRate2 [money] NULL,
    @TP_ByTierStart3 [int] NULL,
    @TP_ByTierEnd3 [int] NULL,
    @TP_ByTierRate3 [money] NULL,
    @TP_ByTierStart4 [int] NULL,
    @TP_ByTierEnd4 [int] NULL,
    @TP_ByTierRate4 [money] NULL,
    @TP_ByTierStart5 [int] NULL,
    @TP_ByTierEnd5 [int] NULL,
    @TP_ByTierRate5 [money] NULL,
    @TP_ByTierStart6 [int] NULL,
    @TP_ByTierEnd6 [int] NULL,
    @TP_ByTierRate6 [money] NULL,
    @TP_CommissionRate [decimal](12, 4) NULL,
    @TP_CommissionFlat [money] NULL,
    @TP_AddedByWho [char](20) NULL,
    @TP_PostedDtTm [datetime] NULL,
    @Insert_Status [char](100) = 'Success' output
)
as  
  
      declare  @TP_PickUpCd [char](1)   
      declare  @TP_DropOffCd [char](1) 

                  if (@TP_TravelPairType='TwoWayTravel')           BEGIN
    SELECT @TP_PickUpCd='A', @TP_DropOffCd='A'
END
                  if (@TP_TravelPairType='Station-Hotel')            BEGIN
    SELECT @TP_PickUpCd='O', @TP_DropOffCd='H'
END
                  if (@TP_TravelPairType='Hotel-Station')            BEGIN
    SELECT @TP_PickUpCd='H', @TP_DropOffCd='O'
END
                  if (@TP_TravelPairType='Station-Station')         BEGIN
    SELECT @TP_PickUpCd='S', @TP_DropOffCd='S'
END
                  if (@TP_TravelPairType='Hotel-Hotel')                BEGIN
    SELECT @TP_PickUpCd='H', @TP_DropOffCd='H'
END
                  if (@TP_TravelPairType='Other-Airport')             BEGIN
    SELECT @TP_PickUpCd='X', @TP_DropOffCd='A'
END
                  if (@TP_TravelPairType='Airport-Other')             BEGIN
    SELECT @TP_PickUpCd='A', @TP_DropOffCd='X'
END
                  if (@TP_TravelPairType='Other-Hotel')                BEGIN
    SELECT @TP_PickUpCd='X', @TP_DropOffCd='H'
END
                  if (@TP_TravelPairType='Hotel-Other')                BEGIN
    SELECT @TP_PickUpCd='H', @TP_DropOffCd='X'
END
                  if (@TP_TravelPairType='Other-Other')                               BEGIN
    SELECT @TP_PickUpCd='X', @TP_DropOffCd='X'
END
                               
                                                                                

INSERT INTO [dbo].[tblTravelPair]
    ([PA_Key]
    ,[P_ProvKey]
    ,[A_Symbol]
    ,[TP_OrderBy]
    ,[TP_StartDtTm]
    ,[TP_EndDtTm]
    ,[TP_HotelStationCd]
    ,[TP_PickUpCd]
    ,[TP_PickUpKey]
    ,[TP_DropOffCd]
    ,[TP_DropOffKey]
    ,[TP_PickUpAdjTmi]
    ,[TP_DropOffAdjTmi]
    ,[TP_HotelLimoInd]
    ,[TP_CancelCd]
    ,[TP_CancelDeadlineTmi]
    ,[TP_CancelHrs]
    ,[TP_UseTierRateInd]
    ,[CC_CurrencyCd]
    ,[TP_RateFlat]
    ,[TP_RateHead]
    ,[TP_TollAmtToDropOff]
    ,[TP_TollAmtFromDropOff]
    ,[TP_NoShowCharge]
    ,[TP_MiscTaxToDropOff]
    ,[TP_MiscTaxFromDropOff]
    ,[TP_Gratuity]
    ,[TP_Notes]
    ,[TP_TripTmi]
    ,[TP_TimeRatePerMin]
    ,[TP_WaitTimeRate]
    ,[TP_PickUpNotes]
    ,[TP_AcctNumb]
    ,[TP_FOP]
    ,[TP_HasTiered]
    ,[TP_ByTierStart1]
    ,[TP_ByTierEnd1]
    ,[TP_ByTierRate1]
    ,[TP_ByTierStart2]
    ,[TP_ByTierEnd2]
    ,[TP_ByTierRate2]
    ,[TP_ByTierStart3]
    ,[TP_ByTierEnd3]
    ,[TP_ByTierRate3]
    ,[TP_ByTierStart4]
    ,[TP_ByTierEnd4]
    ,[TP_ByTierRate4]
    ,[TP_ByTierStart5]
    ,[TP_ByTierEnd5]
    ,[TP_ByTierRate5]
    ,[TP_ByTierStart6]
    ,[TP_ByTierEnd6]
    ,[TP_ByTierRate6]
    ,[TP_CommissionRate]
    ,[TP_CommissionFlat]
    ,[TP_AddedByWho]
    ,[TP_PostedDtTm])
select
            @PA_Key  
           , @P_ProvKey  
           , @A_Symbol  
           , @TP_OrderBy  
           , @TP_StartDtTm  
           , @TP_EndDtTm  
           , @TP_HotelStationCd  
           , @TP_PickUpCd  
           , @TP_PickUpKey  
           , @TP_DropOffCd  
           , @TP_DropOffKey  
           , @TP_PickUpAdjTmi  
           , @TP_DropOffAdjTmi  
           , @TP_HotelLimoInd  
           , @TP_CancelCd  
           , @TP_CancelDeadlineTmi  
           , @TP_CancelHrs  
           , @TP_UseTierRateInd  
           , @CC_CurrencyCd  
           , @TP_RateFlat  
           , @TP_RateHead  
           , @TP_TollAmtToDropOff  
           , @TP_TollAmtFromDropOff  
           , @TP_NoShowCharge  
           , @TP_MiscTaxToDropOff  
           , @TP_MiscTaxFromDropOff  
           , @TP_Gratuity  
           , @TP_Notes  
           , @TP_TripTmi  
           , @TP_TimeRatePerMin  
           , @TP_WaitTimeRate  
           , @TP_PickUpNotes  
           , @TP_AcctNumb  
           , @TP_FOP  
           , @TP_HasTiered  
           , @TP_ByTierStart1  
           , @TP_ByTierEnd1  
           , @TP_ByTierRate1  
           , @TP_ByTierStart2  
           , @TP_ByTierEnd2  
           , @TP_ByTierRate2  
           , @TP_ByTierStart3  
           , @TP_ByTierEnd3  
           , @TP_ByTierRate3  
           , @TP_ByTierStart4  
           , @TP_ByTierEnd4  
           , @TP_ByTierRate4  
           , @TP_ByTierStart5  
           , @TP_ByTierEnd5  
           , @TP_ByTierRate5  
           , @TP_ByTierStart6  
           , @TP_ByTierEnd6  
           , @TP_ByTierRate6  
           , @TP_CommissionRate  
           , @TP_CommissionFlat  
           , @TP_AddedByWho  
           , @TP_PostedDtTm  
--LOD-37630
--DECLARE @NewTravelPairId int;

--set @NewTravelPairId = SCOPE_IDENTITY()

--INSERT INTO [dbo].[tblTravelPair_Lookup]
--([TP_Key], [TPL_VendorID], [TPL_ContractNumber])
--SELECT @NewTravelPairId, @TPL_VendorID, @TPL_ContractNumber


SET @Insert_Status = 'Success' 



Completion time: 2025-06-06T00:49:01.4004034-04:00
