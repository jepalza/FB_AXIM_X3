'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxa255UdcPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	Dim As Pxa255Udc ptr udc = cast(Pxa255Udc ptr,userData) 
	Dim as uLong valor 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write_" , "read_"), size, pa) 
		return false 
	EndIf
	
	pa = (pa - PXA_UDC_BASE) Shr 2 
	
	if (write_) Then valor = *cast(ULong ptr,buf)

	Select Case As Const  (pa)  
		case 0 		'UDCCR
			if(write_) Then 
				udc->ccr = valor 
			else
				valor = udc->ccr
			EndIf
		
		case &h01 	'undocumented reg
			if (write_) Then 
				udc->reg4 = valor 
			else
				valor = udc->reg4
			EndIf
		
		case &h14 	'UICR0
			if(write_) Then 
				udc->uicr0 = valor 
			else
				valor = udc->uicr0
			EndIf
		
		case &h15 	'UICR1
			if(write_) Then 
				udc->uicr1 = valor 
			else
				valor = udc->uicr1
			EndIf
		
		'other regs, TODO
		case else 
			return false 
   End Select

	if (write_=0) Then *cast(ULong ptr,buf) = valor

	return true 
End Function

Function pxa255UdcInit( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr) As Pxa255Udc ptr
	dim as Pxa255Udc ptr udc = cast(Pxa255Udc ptr,Callocate(sizeof(Pxa255Udc)) )
	
	if udc=0 Then PERR("cannot alloc UDC")

	memset(udc, 0, sizeof(Pxa255Udc)) 
	
	udc->ic    = ic 
	udc->dma   = dma 
	udc->ccr   = &ha0 
	udc->uicr0 = &hff 
	udc->uicr1 = &hff 
	
	if memRegionAdd(physMem, PXA_UDC_BASE, PXA_UDC_SIZE, cast(ArmMemAccessF ,@pxa255UdcPrvMemAccessF), udc)=0 Then 
		PERR("cannot add UDC to MEM")
	EndIf
  
	return udc 
End Function

