'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub pxaTimrPrvRaiseLowerInts( timr As PxaTimr Ptr)
	socIcInt(timr->ic, PXA_I_TIMR0, iif( (timr->OSSR And 1) <> 0,1,0) ) 
	socIcInt(timr->ic, PXA_I_TIMR1, iif( (timr->OSSR And 2) <> 0,1,0) ) 
	socIcInt(timr->ic, PXA_I_TIMR2, iif( (timr->OSSR And 4) <> 0,1,0) ) 
	socIcInt(timr->ic, PXA_I_TIMR3, iif( (timr->OSSR And 8) <> 0,1,0) ) 
end sub

Sub pxaTimrPrvCheckMatch( timr As PxaTimr Ptr , idx As UByte)
	Dim As UByte v = 1UL Shl idx 
	
	if (timr->OSCR = timr->OSMR(idx)) Then 
		if (idx = 3) AndAlso (timr->OWER<>0) Then PERR("WDT fires")
		if (timr->OIER And v) Then timr->OSSR Or= v
	EndIf
  
End Sub

Sub pxaTimrPrvUpdate( timr As PxaTimr Ptr)
	Dim As UByte i 
	
	for  i = 0 To 3      
		pxaTimrPrvCheckMatch(timr, i)
   Next
	
	pxaTimrPrvRaiseLowerInts(timr) 
End Sub

Function pxaTimrPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	dim as PxaTimr ptr timr = cast(PxaTimr ptr,userData) 
	dim as uLong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write_" , "read_"), size, pa) 
		return false 		'we do not support non-word accesses
	EndIf
	
	pa = (pa - PXA_TIMR_BASE) Shr 2 
	
	if(write_) Then 
		valor = *cast(ULong ptr,buf) 
		
		Select Case As Const (pa) 
			case 0,1,2,3
				timr->OSMR(pa) = valor 
				pxaTimrPrvUpdate(timr) 
			
			case 4 
				timr->OSCR = valor 

			case 5 
				timr->OSSR = timr->OSSR And INV( valor )
				pxaTimrPrvUpdate(timr) 
			
			case 6 
				timr->OWER = valor 

			case 7 
				timr->OIER = valor 
				pxaTimrPrvUpdate(timr) 
      End Select

	else
        
		Select Case As Const (pa) 
			case 0,1,2,3 
				valor = timr->OSMR(pa) 
			
			case 4 
				valor = timr->OSCR 
			
			case 5 
				valor = timr->OSSR 
			
			case 6 
				valor = timr->OWER 
			
			case 7 
				valor = timr->OIER 
      End Select

		*cast(ULong ptr,buf) = valor 
	EndIf
  
	return true 
End Function


Function pxaTimrInit( physMem As ArmMem Ptr , ic As SocIc Ptr) As PxaTimr ptr

	dim as PxaTimr ptr timr = cast(PxaTimr ptr,Callocate(sizeof(PxaTimr)) )
	
	if timr=0 Then PERR("cannot alloc OSTIMER")

	memset(timr, 0, sizeof(PxaTimr)) 
	timr->ic = ic 
	
	if memRegionAdd(physMem, PXA_TIMR_BASE, PXA_TIMR_SIZE, cast(ArmMemAccessF ,@pxaTimrPrvMemAccessF), timr)=0 Then 
		PERR("cannot add OSTIMER to MEM")
	EndIf

	return timr 
End Function

Sub pxaTimrTick( timr As PxaTimr Ptr)
	timr->OSCR+=1  
	pxaTimrPrvUpdate(timr) 
End Sub
