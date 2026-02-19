Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/*
EXEC wSP_SelectHotelAirlines_CH 10030
*/

CREATE   PROCEDURE [dbo].[wSP_SelectHotelAirlines_CH] ( 
	@Hotel int = NULL 
)
AS
BEGIN
	set transaction isolation level read uncommitted;
	set nocount on;

	declare @BD datetime,
			@ED datetime

	--SET @BD = DateAdd(dd, -180, getdate()) 
	--SET @ED = DateAdd(dd, 365, getdate())
	--IF @Hotel = '%%' 
	--BEGIN
	--	SET @Hotel = NULL
	--END

	If @Hotel is null
	BEGIN
		select A.A_Symbol as CompanyId, A.A_Symbol + ' - ' + A.A_NameFull as CompanyName
		from dbo.tblAirline A
		where A.A_Symbol <> '**'
		order by 1
	END
	ELSE
	BEGIN
		select A.A_Symbol as CompanyId, A.A_Symbol + ' - ' + A.A_NameFull as CompanyName
		from tblInv i
		join tblAirline a on i.A_Symbol = a.A_Symbol 
		where i.H_HotelKey = @Hotel
		--and i.I_ResvDt between @BD AND @ED

		union

		select A.A_Symbol as CompanyId, A.A_Symbol + ' - ' + A.A_NameFull as CompanyName
		from tblOrder o
		join tblAirline a on o.A_Symbol = a.A_Symbol 
		where o.H_HotelKey = @Hotel
		--and o.I_ResvDt between @BD AND @ED

		order by 1
	END
	
	--IF @@ROWCOUNT = 0
	--BEGIN
	--	SELECT 'No' AS A_Symbol, 'Data' AS Airline
	--END
END






Completion time: 2025-06-06T00:51:19.3880558-04:00
