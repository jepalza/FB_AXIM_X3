'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub pxaRtcPrvUpdate( rtc As PxaRtc Ptr)

	if (rtc->lastSeenTime <> rtc->RCNR) Then 
		'do not triger alarm more than once per second please
		if rtc->RTSR And &h4 Then 'check alarm
			rtc->RTSR Or= 1
		EndIf

		if rtc->RTSR And &h8 Then 'send HZ interrupt
			rtc->RTSR Or= 2
		EndIf
  
		rtc->lastSeenTime = rtc->RCNR 
	EndIf
  
	socIcInt(rtc->ic, PXA_I_RTC_ALM, NOT_NOT(rtc->RTSR And 1)) 
	socIcInt(rtc->ic, PXA_I_RTC_HZ , NOT_NOT(rtc->RTSR And 2)) 
End Sub

Function pxaRtcPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	dim as PxaRtc ptr rtc = cast(PxaRtc ptr,userData) 
	dim as uLong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write_" , "read_"), size, pa) 
		return false 
	EndIf
  
	pa = (pa - PXA_RTC_BASE) Shr 2 
	
	if(write_) Then 
		valor = *cast(ULong ptr,buf) 
		
		Select Case As Const (pa) 
			case 0 
				rtc->RCNR =  valor 

			case 1 
				rtc->RTAR = valor 
				pxaRtcPrvUpdate(rtc) 

			case 2 
				rtc->RTSR = (valor And INV(3UL)) Or ((rtc->RTSR And INV(valor)) And 3UL) 
				pxaRtcPrvUpdate(rtc) 

			case 3 
				if (rtc->RTTR And &h80000000UL)=0 Then rtc->RTTR = valor 
      End Select

	else
        
		Select Case As Const (pa) 
			case 0 
				valor = rtc->RCNR 

			case 1 
				valor = rtc->RTAR 

			case 2 
				valor = rtc->RTSR 

			case 3 
				valor = rtc->RTTR 
      End Select
		*cast(ULong ptr,buf) = valor 
	EndIf
  
	return true 
End Function


Function pxaRtcInit( physMem As ArmMem Ptr , ic As SocIc Ptr) As PxaRtc ptr

	dim as PxaRtc ptr rtc = cast(PxaRtc ptr,Callocate(sizeof(PxaRtc)) )
	
	if rtc=0 Then PERR("cannot alloc RTC")
	
	memset(rtc, 0, sizeof(PxaRtc)) 
	
	rtc->ic   = ic 
	rtc->RTTR = &h7FFF 	'nice default value
	
	if memRegionAdd(physMem, PXA_RTC_BASE, PXA_RTC_SIZE, cast(ArmMemAccessF ,@pxaRtcPrvMemAccessF), rtc)=0 Then 
		PERR("cannot add RTC to MEM")
	EndIf
  
	return rtc 
End Function

Sub pxaRtcUpdate(rtc As PxaRtc Ptr)
	rtc->RCNR+=1  
	pxaRtcPrvUpdate(rtc) 
End Sub
